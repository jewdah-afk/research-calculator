# Luau Language Mastery and Performance Engineering on Roblox

*Chapter 22 of the Roblox mastery corpus. Written against primary sources: the
Luau VM C++ source (`luau-lang/luau`), the Luau RFC tree (`luau-lang/rfcs`),
and the Roblox engine reference YAML (`Roblox/creator-docs`). Every claim about
thread safety is taken from the `ThreadSafety` metadata in the engine YAML,
which is the authoritative machine-readable source for what may run in the
parallel phase.*

*Scope: the chapter assumes you are writing heavy numeric Luau — runtime mesh
generation, `EditableImage` pixel work, noise fields, physics-ish integrators —
and that dropping a frame is a bug, not a tradeoff.*

---

## TL;DR

- **`vector` is the single biggest free win in numeric Luau.** `LUA_VECTOR_TYPE`
  is `float` and `LUA_VECTOR_SIZE` is `3` (`VM/include/luaconf.h`), so a vector
  is three float32 lanes stored *inline in the `TValue`* — no heap object, no GC
  pressure, no pointer chase. Roblox exposes it as the `vector` library
  (`vector.create/magnitude/normalize/cross/dot/angle/floor/ceil/abs/sign/clamp/lerp/min/max`,
  plus `vector.zero`/`vector.one`). `Vector3` is a *different*, heap-allocated
  userdata. In a hot loop, prefer `vector`.
- **`buffer` is the right container for vertex and pixel data, not tables.** Each
  table array slot costs a full 16-byte `TValue`; a buffer byte costs one byte.
  Bounds checking is one 64-bit comparison
  (`(uint64_t)(unsigned)offset + accesssize > (uint64_t)len`, `VM/src/lbuflib.cpp`),
  all reads/writes are **little-endian on every platform**, and **unaligned
  offsets are explicitly legal**. Max buffer size is `1 << 30` bytes
  (`MAX_BUFFER_SIZE`, `VM/src/lbuffer.h`).
- **`buffer.copy` is `memmove` and `buffer.fill` is `memset`** — both single C
  calls. The doubling-copy idiom (`fill 1 pattern, then copy 1→1, 2→2, 4→4, …`)
  clears or tiles an N-byte buffer in `O(log N)` Luau-level calls at memcpy
  bandwidth.
- **The editable APIs are almost entirely `Unsafe` in the parallel phase.**
  From the `thread_safety` metadata in `creator-docs`: on `EditableImage` only
  `ReadPixelsBuffer` is `Safe` and `Size` is `ReadSafe`; **`WritePixelsBuffer`,
  and every `Draw*` method, are `Unsafe`**. On `EditableMesh` every `Get*`/
  `Batch*Get*`/query method (`RaycastLocal`, `FindClosestPointOnSurface`,
  `FindVerticesWithinSphere`) is `Safe`, and **every mutator, including
  `BatchSetValues` and `BatchAdd`, is `Unsafe`**. So: compute in parallel,
  commit in serial. Always.
- **The parallel-phase pattern that actually works** is therefore: do the math
  in `task.desynchronize()`/`BindToMessageParallel`, write the result into a
  `buffer` (buffers are plain Luau values and need no engine permission), then
  `task.synchronize()` and do exactly one `WritePixelsBuffer`/`BatchSetValues`
  call. The serial commit is a `memcpy`-shaped operation; the math was the
  expensive part and it ran on another core.
- **Each `Actor` is its own Luau VM.** `ModuleScript`s are re-executed per Actor
  and module-level state is *not* shared (`Actor.yaml`). `require()` is illegal
  in a desynchronized phase. Plan for that: require everything up front.
- **`SharedTable` is the only shared mutable state across Actors.** Keys are
  strings or non-negative integers `< 2^32`; values are boolean/number/vector/
  string/SharedTable/serializable. `SharedTable.increment` and
  `SharedTable.update` are atomic, `clone` is atomic and uses structural
  sharing. It is *not* a fast array — per-element access crosses a
  synchronization boundary. Bulk numeric data should travel as a `buffer`
  through `Actor:SendMessage` — but note that **message arguments are passed by
  copy across VM boundaries**, so that is a `memcpy`, not a handoff.
- **Native codegen (`--!native` / `@native`) is documented for server scripts**
  and only compiles *functions*, not top-level code. Confirm it is live with the
  `<native>` annotation in the Script Profiler and `debug.dumpcodesize()` in the
  command bar. It silently falls back on `getfenv`/`setfenv`, on builtins called
  with non-numeric args, and on mistyped arguments. Limits are hard: 64K
  instructions per code block, 32K blocks per function, 1M instructions per
  module, plus a global native-code memory cap.
- **Type annotations change runtime speed under native codegen**, not just
  correctness. Annotating `v: Vector3` lets the compiler emit vector-specialised
  code instead of generic table-index checks — this is the one place where
  strict typing is a *performance* feature.
- **Time-slicing is `os.clock()` plus a yield, nothing fancier.** Roblox kills a
  non-yielding thread with "Script timeout: exhausted allowed execution time"
  (`ScriptContext.ScriptsDisabled` / execution-timeout machinery); the fix is a
  budget check inside the innermost cheap loop and `task.wait()`/`RunService`
  yield when the budget is spent.
- **Frame order matters and is documented**: input → `BindToRenderStep` →
  `PreRender` (render step) and `PreAnimation` → `PreSimulation` → physics →
  `PostSimulation` → `Heartbeat`. Physics-affecting writes go in
  `PreSimulation`; physics-reading logic goes in `PostSimulation`; `Motor6D.Transform`
  writes must be in `PreSimulation`.
- **`debug.profilebegin`/`debug.profileend` labels show up in the MicroProfiler**,
  and `debug.setmemorycategory` labels show up in the Developer Console memory
  view. Both are nearly free and both are how you find the frame you are
  dropping. Studio numbers systematically flatter you: Studio runs server and
  client in one process on a developer-class machine.
- **Table presizing with `table.create(n)` and `table.create(n, v)`** avoids the
  rehash-and-copy cascade; mixing array and hash keys in one table splits it
  into two allocations and kills the array fast path.
- **Instance property access is a C++ round trip with a property-name lookup**;
  caching `part.CFrame` into a local once and writing once is the difference
  between a smooth frame and a stutter. The same applies to `game:GetService`
  and to globals: `local sqrt = math.sqrt` at module scope removes a table
  lookup per call (though Luau's fastcall path already covers many builtins).

---

## 1. Luau versus Lua 5.1: what you gained, what you lost

Luau is a fork of Lua 5.1 with a bytecode VM and compiler written from scratch.
It is **not** Lua 5.4 and never will be; it borrows selectively.

### 1.1 The value representation — why everything below follows from this

From `VM/src/lobject.h`:

```c
typedef union
{
    GCObject* gc;
    void* p;
    double n;
    int b;
    int64_t l;
    float v[2]; // v[0], v[1] live here; v[2] lives in TValue::extra
} Value;

typedef struct lua_TValue
{
    Value value;
    int extra[LUA_EXTRA_SIZE];
    int tt;
} TValue;
```

With `LUA_VECTOR_SIZE == 3` (`luaconf.h`), `LUA_EXTRA_SIZE` is `1`, so a
`TValue` is **16 bytes**: an 8-byte payload union, a 4-byte `extra` slot, and a
4-byte type tag. Three consequences you will feel every day:

1. A table array slot costs 16 bytes *regardless of what it holds*. One million
   numbers in a Luau array is 16 MB of `TValue` plus the table header. The same
   million `float32`s in a `buffer` is 4 MB. This is the entire argument for
   buffers, and it comes straight from the struct.
2. Numbers are IEEE754 **doubles**, always. There is no integer subtype in
   shipping Luau. (`master` has a `LuauIntegerLibrary` fast-flagged 64-bit
   integer library — `luauF_integeradd`, `buffer.readinteger` and friends in
   `lbuiltins.cpp`/`lbuflib.cpp` — but it is not exposed on Roblox as of Studio
   `0.739`. `[UNVERIFIED]` for Roblox availability; treat it as "coming".)
3. A `vector` fits **entirely inside a `TValue`** — `x`,`y` in `value.v[0..1]`
   and `z` in `extra[0]`. It is a value type. Copying one is copying 16 bytes.
   It never allocates and the GC never sees it.

### 1.2 Additions over Lua 5.1

Syntax and semantics (each has an RFC in `luau-lang/rfcs/docs/`):

| Feature | RFC | Note |
|---|---|---|
| `continue` | `syntax-continue-statement.md` | contextual keyword, not reserved |
| Compound assignment `+= -= *= /= //= %= ^= ..=` | `syntax-compound-assignment.md` | evaluates the target once |
| `if ... then ... else ...` **expressions** | `syntax-if-expression.md` | no `and/or` truthiness trap |
| String interpolation `` `x is {x}` `` | `syntax-string-interpolation.md` | calls `tostring` |
| Floor division `//` | `syntax-floor-division-operator.md` | |
| Generalized iteration `for k, v in t do` | `generalized-iteration.md` | no `pairs`/`ipairs` call needed |
| Type annotations, generics, type functions | many | see §2 |
| Function attributes `@native`, `@deprecated` | `syntax-attributes-functions.md`, `syntax-attribute-functions-native.md` | see §3 |
| `const` locals | `const-keyword.md` | `[UNVERIFIED]` on Roblox |
| Number literals `0b1010`, `1_000_000` | `syntax-number-literals.md` | |

Library additions confirmed present in the VM source and in Roblox's
`reference/engine/libraries/*.yaml`:

- **`buffer`** — the whole library. §4.
- **`vector`** — `create, magnitude, normalize, cross, dot, angle, floor, ceil, abs, sign, clamp, lerp, max, min` plus `vector.zero` / `vector.one` constants.
- **`bit32`** — `arshift band bnot bor btest bxor byteswap countlz countrz extract lrotate lshift replace rrotate rshift`. Note `byteswap`, `countlz`, `countrz` are Luau additions over Lua 5.2's `bit32`.
- **`table`** — adds `create`, `clear`, `clone`, `freeze`, `isfrozen`, `find`, `move`, `pack`, `unpack`. (`foreach`/`foreachi`/`getn` survive but are deprecated — `deprecate-table-getn-foreach.md`.)
- **`string`** — adds `split`, and Lua 5.3's `pack`/`unpack`/`packsize`.
- **`math`** — adds `clamp`, `sign`, `round`, `noise`, `lerp`, `map`, `isnan`,
  `isinf`, `isfinite`, and the constants `pi, huge, nan, e, phi, sqrt2, tau`.
  *All of these are present in Roblox's `math.yaml`.* Stop hand-rolling
  `math.clamp`, stop writing `n ~= n` for NaN checks, stop writing
  `a + (b - a) * t` for `math.lerp(a, b, t)`, and stop writing your own
  remap helper — `math.map(x, inMin, inMax, outMin, outMax)` exists.
- **`coroutine`** — adds `close` (`function-coroutine-close.md`) and `finally`.
- **`utf8`**, `typeof`, `newproxy`.
- **`debug`** — Roblox-specific: `profilebegin`, `profileend`, `info`,
  `traceback`, `getmemorycategory`, `setmemorycategory`, `resetmemorycategory`,
  `dumpcodesize`.

### 1.3 Removals and restrictions

Luau is a sandboxed language. Gone or restricted:

- **No `io`, no `package`, no `os.execute`/`os.getenv`/`os.exit`/`os.remove`.**
  `loslib.cpp` registers exactly four functions: `clock`, `date`, `difftime`, `time`.
- **No `loadstring`/`load`/`dofile`/`loadfile`** in Roblox's environment.
  Code is compiled ahead of time; there is no runtime `eval`.
- **No `goto`/labels.** Luau deliberately never adopted them.
- **No `_ENV`.** `getfenv`/`setfenv` still exist in `lbaselib.cpp` but are
  deprecated (`deprecate-getfenv-setfenv.md`) and — critically for this chapter —
  **their presence anywhere in a function disables native code generation**.
- **`debug` is gutted**: only `info` and `traceback` exist in the upstream VM;
  no `sethook`, `getlocal`, `setupvalue`, `getinfo` with arbitrary fields.
- **`collectgarbage`** is restricted on Roblox to `collectgarbage("count")`.
  You cannot force a full collection. `[COMMUNITY, SECOND-HAND]` for the exact
  Roblox restriction; the VM itself still has the full API.
- **`string.dump`** is absent.
- Metatables: `__gc` is not supported; `__len` exists
  (`len-metamethod-rawlen.md`); `__iter` exists via generalized iteration.

### 1.4 The `vector` type in depth

This is the highest-leverage item in the chapter for 3D work.

**What it is.** A first-class VM value holding `LUA_VECTOR_SIZE == 3` lanes of
`LUA_VECTOR_TYPE == float` (single precision, IEEE754 binary32). Confirmed in
`VM/include/luaconf.h`:

```c
#ifndef LUA_VECTOR_SIZE
#define LUA_VECTOR_SIZE 3 // must be 3 or 4
#endif

#ifndef LUA_VECTOR_DOUBLE
#define LUA_VECTOR_DOUBLE 0
#endif

#if LUA_VECTOR_DOUBLE == 1
#define LUA_VECTOR_TYPE double
#else
#define LUA_VECTOR_TYPE float
#endif
```

**How you get one.** `vector.create(x, y, z)`. `typeof()` returns `"vector"`;
`type()` also returns `"vector"` (it is a primitive tag, not a userdata).

**Field access.** `vector_index` in `VM/src/lveclib.cpp`:

```c
int ic = (name[0] | ' ') - 'x';
if (unsigned(ic) < LUA_VECTOR_SIZE) { lua_pushnumber(L, v[ic]); return 1; }
luaL_error(L, "attempt to index vector with '%s'", name);
```

Two facts fall out: **field access is case-insensitive** (`v.X` and `v.x` are
the same code path — `| ' '` lowercases the ASCII letter), and **there are no
swizzles**. `v.xy` errors. The comment in the source says this mirrors a
fast path in the interpreter, so the metamethod is only hit when the compiler
could not inline the access.

**Arithmetic.** `+ - * /` and unary `-` work component-wise between vectors and
between a vector and a number, in the VM, without a metamethod call. `==`
compares all three lanes.

**Precision — the thing that bites.** `vector` lanes are **float32**, ~7
decimal digits. A Luau `number` is float64. This is fine for positions in a
few-thousand-stud world, fine for normals, fine for colours; it is **not** fine
for accumulating a running sum over hundreds of thousands of terms, for world
coordinates far from the origin, or for anything you then use as a hash key.
Accumulate in `number`, store in `vector`.

**`vector` versus `Vector3`.** They are different types.

| | `vector` | `Vector3` |
|---|---|---|
| Kind | VM primitive, inline in `TValue` | Roblox userdata (heap object) |
| Allocation per value | **none** | one GC allocation |
| Precision | float32 ×3 | float32 ×3 (`[UNVERIFIED]` internally, behaves as f32) |
| `.Unit`, `.Magnitude`, `:Cross()` | no — use `vector.*` free functions | yes |
| Accepted by engine APIs | yes, widely (engine coerces) | yes |
| Fastcall'd builtins | `vectormagnitude`, `vectornormalize`, `vectorcross`, `vectordot`, `vectorfloor`, `vectorceil`, `vectorabs`, `vectorsign`, `vectorclamp`, `vectormin`, `vectormax`, `vectorlerp` (`lbuiltins.cpp`) | none |

Roblox's `Vector3` is implemented on top of the native vector type on modern
engine versions, which is why passing a `vector` where a `Vector3` is expected
generally works. `[UNVERIFIED]` — the exact coercion rules are not in the
public YAML; test the specific API before relying on it in shipping code.

**The hot-loop pattern.** Three lanes at once, no allocation, fastcall builtins:

```lua
--!strict
--!native

local vcreate, vdot, vcross = vector.create, vector.dot, vector.cross
local vmag, vnorm = vector.magnitude, vector.normalize

-- Compute a face normal for every triangle in a flat position buffer.
-- positions: buffer of float32 triples, one per vertex
-- indices:   buffer of uint32 triples, one per triangle
local function computeFaceNormals(positions: buffer, indices: buffer, triCount: number): buffer
	local out = buffer.create(triCount * 12) -- 3 floats per normal

	for t = 0, triCount - 1 do
		local base = t * 12
		local i0 = buffer.readu32(indices, base) * 12
		local i1 = buffer.readu32(indices, base + 4) * 12
		local i2 = buffer.readu32(indices, base + 8) * 12

		local a = vcreate(buffer.readf32(positions, i0), buffer.readf32(positions, i0 + 4), buffer.readf32(positions, i0 + 8))
		local b = vcreate(buffer.readf32(positions, i1), buffer.readf32(positions, i1 + 4), buffer.readf32(positions, i1 + 8))
		local c = vcreate(buffer.readf32(positions, i2), buffer.readf32(positions, i2 + 4), buffer.readf32(positions, i2 + 8))

		local n = vnorm(vcross(b - a, c - a))

		buffer.writef32(out, base, n.x)
		buffer.writef32(out, base + 4, n.y)
		buffer.writef32(out, base + 8, n.z)
	end

	return out
end
```

Note what is *not* in that loop: no table creation, no `Vector3.new`, no
closures, no `:` method calls. The only allocations for the whole loop are the
output buffer and nothing else — `a`, `b`, `c`, `n` are stack `TValue`s.

**`vector.angle`.** `vector.angle(a, b, axis?)` returns the angle in radians;
with an optional third `axis` argument it returns a *signed* angle. This is the
numerically stable version — prefer it to `math.acos(dot(a.Unit, b.Unit))`,
which loses catastrophic precision when the vectors are nearly parallel.

**`vector.lerp` is a real builtin** (`function-vector-lerp.md`,
`luauF_vectorlerp`), not sugar. Same for scalar `math.lerp`
(`function-math-lerp.md`, `luauF_lerp`). The RFC for `math.lerp` specifies the
monotonic, exactness-preserving form — `lerp(a, b, 1)` is exactly `b` — which
a naive `a + (b-a)*t` does not guarantee.

---

## 2. Typed Luau: correctness first, then runtime speed

### 2.1 The three modes

Set on the **first line** of a script, or globally via
`Workspace.LuauTypeCheckMode` (enum `LuauTypeCheckMode`: `Default`, `NoCheck`,
`Nonstrict`, `Strict` — confirmed in
`reference/engine/enums/LuauTypeCheckMode.yaml`):

- `--!nocheck` — the type checker does not run. Analysis warnings vanish.
- `--!nonstrict` — the historical default. Only explicitly annotated things are
  checked; everything else is `any`.
- `--!strict` — everything is checked against its annotated *or inferred* type.

The RFC `new-nonstrict.md` describes where this is heading: strict and
non-strict converge on the same **local type inference** engine, and the only
difference becomes *which errors are reported*. Non-strict's goal is stated as
"minimize false positives — if non-strict mode reports an error, we have high
confidence there is a code defect": runtime errors (`"hi" + 5`,
`math.abs("hi")`, `CFrame.new("hi")`), dead code, expressions that can only be
`nil`, and table properties written but never read.

Separately, `Workspace.UseNewLuauTypeSolver` (a `RolloutState`) controls which
*solver implementation* runs. Mode and solver are orthogonal. If your inference
quality changes between Studio versions without you touching anything, this is
usually why.

**Recommendation for numeric code: `--!strict`, always, no exceptions.** The
reason is in §2.3, and it is not about catching bugs.

### 2.2 The type system you actually use in hot code

```lua
--!strict

-- Primitives: nil boolean number string, plus thread, buffer, vector
-- Optionals
local maybeName: string? = nil

-- Casts: :: is an assertion, erased at runtime, zero cost
local n = (someAny :: number)

-- Function types
type Sampler = (x: number, y: number) -> number
type Pair = (number, number) -> (number, number)

-- Table types
local heights: {number} = table.create(4096, 0)     -- array-like
local byName: {[string]: number} = {}                -- map-like
type Vertex = { px: number, py: number, pz: number, nx: number, ny: number, nz: number }

-- Variadics: in a function signature use `...: T`,
-- in a *type* use `...T` (a genuine syntax asymmetry)
local function sum(...: number): number
	local s = 0
	for _, v in { ... } do s += v end
	return s
end
type SumFn = (...number) -> number

-- Unions and intersections
type NumberOrString = number | string
type Named = { name: string }
type Aged = { age: number }
type Person = Named & Aged

-- Literal (singleton) types — useful for tagged unions
type Op = "add" | "sub" | "mul"

-- Generics
type List<T> = { T }
type Map<K, V> = { [K]: V }
local function first<T>(xs: { T }): T?
	return xs[1]
end

-- typeof for inferred / metatable types
type Car = typeof({ Speed = 0, Wheels = 4 })

-- export makes a type visible to requirers
export type Chunk = { id: number, positions: buffer, normals: buffer }
```

**Tagged unions** are the idiom that makes strict mode pleasant for generator
code, because Luau narrows on the tag:

```lua
--!strict
type Shape =
	  { kind: "sphere", center: vector, radius: number }
	| { kind: "box", min: vector, max: vector }

local function volume(s: Shape): number
	if s.kind == "sphere" then
		return (4 / 3) * math.pi * s.radius ^ 3   -- s.radius is known here
	else
		local d = s.max - s.min                    -- s.min/s.max known here
		return d.x * d.y * d.z
	end
end
```

### 2.3 When types affect **runtime** performance

This is the part most Roblox developers get wrong. Under the *interpreter*,
type annotations are erased: `::` is a no-op, parameter annotations generate no
checks, and `--!strict` costs nothing at runtime. Types are analysis-only.

Under **native code generation**, this stops being true. From Roblox's
`luau/native-code-gen.md`:

> Native code generation attempts to infer the most likely type for a given
> variable in order to optimize code paths. For example, it's assumed that
> `a + b` is performed on numbers, or that a table is accessed in `t.X`. Given
> operator overloading, however, `a` and `b` may be tables or `Vector3` types,
> or `t` may be a Roblox datatype. […] While native code generation will
> support any type, mispredictions may trigger unnecessary checks, resulting in
> slower code execution.

And the concrete instruction:

```lua
--!native

-- "v" is assumed to be a table; function performs slower due to table checks
local function sumComponentsSlow(v)
	return v.X + v.Y + v.Z
end

-- "v" is declared to be a Vector3; code specialized for vectors is generated
local function sumComponentsFast(v: Vector3)
	return v.X + v.Y + v.Z
end
```

Three rules follow:

1. **Annotate every parameter of every `@native` function**, especially
   `Vector3`/`vector`/`buffer`/`number`. This is the single most effective
   native-codegen tuning knob.
2. **Do not lie in annotations.** The same doc lists "passing improperly typed
   parameters to typed functions, for example calling `foo(true)` when `foo` is
   declared as `function foo(arg: string)`" under *code to avoid* — it causes
   de-optimization or a fallback to interpreted execution. A wrong annotation
   is worse than none.
3. **Annotate return types too** when the value feeds another native function;
   it propagates the specialisation across the call.

There is a second, smaller runtime effect that applies even without native
codegen: **strict mode makes the compiler's own type inference available to the
bytecode compiler**, which is what lets it emit `FASTCALL` for builtin calls
and avoid generic metamethod dispatch on arithmetic. `[UNVERIFIED]` as to how
much of this is gated on `--!strict` versus done unconditionally by the
compiler's local inference — the observable effect in shipping code is small
compared to the native-codegen effect above.

### 2.4 Type functions, and what they are for

`user-defined-type-functions.md` (implemented) adds `type function`, which runs
at *analysis* time on type values:

```lua
type function MakeOptional(t)
	return types.unionof(t, types.singleton(nil))
end
type MaybeNumber = MakeOptional<number>
```

Plus the built-in type operators from their own RFCs: `keyof<T>`
(`keyof-type-operator.md`), `index<T, K>` (`index-type-operator.md`),
`rawget<T, K>` (`rawget-type-operator.md`), and negation types
(`negation-types.md`). Roblox availability of `type function` is
`[UNVERIFIED]` — it is implemented upstream but Roblox ships its own Luau
revision; check in Studio before depending on it.

For generator code, the practical payoff of all this is small. Types earn their
keep here in two places only: catching unit mistakes (studs vs pixels vs
normalized UV) at author time, and feeding native codegen. Do not build an
elaborate type-level DSL for a mesh generator; annotate the parameters and move
on.

### 2.5 Generics that matter in numeric code

Generics in Luau are not monomorphized — there is no runtime specialisation, so
a generic function is exactly as fast (or slow) as an untyped one. Their value
is API shape:

```lua
--!strict
-- A typed object pool: reuse tables instead of allocating in the hot loop.
type Pool<T> = { free: { T }, make: () -> T, reset: (T) -> () }

local function poolAcquire<T>(p: Pool<T>): T
	local n = #p.free
	if n > 0 then
		local v = p.free[n]
		p.free[n] = nil
		return v
	end
	return p.make()
end

local function poolRelease<T>(p: Pool<T>, v: T)
	p.reset(v)
	table.insert(p.free, v)
end
```

Generic *functions* also have a subtyping RFC (`generic-function-subtyping.md`)
and explicit instantiation (`explicit-type-parameter-instantiation.md`,
`f<number>(x)`), which is occasionally needed when inference picks `any`.

---

## 3. Native code generation

### 3.1 What it is and where it runs

Native codegen translates Luau bytecode to real CPU instructions at load time
instead of interpreting it. Roblox's own framing
(`content/en-us/luau/native-code-gen.md`):

> With Luau support for native code generation, **server-side scripts** in your
> game can be compiled directly into the machine code instructions that CPUs
> execute […] This feature can be used to improve execution speed for some
> scripts on the server, in particular those that have a lot of numerical
> computation without using too many heavy Luau library or Roblox API calls.

**This is the single most important caveat in this section: native codegen is
server-side.** As of the current documentation there is no client support, and
there is an open engine-feature request asking for it
(`devforum.roblox.com/t/enable-native-for-clients/3170510`)
`[COMMUNITY, SECOND-HAND]`.

For a runtime-geometry / runtime-image project this is decisive. `EditableImage`
pixel work and most `EditableMesh` deformation happen on the **client**, where
native codegen is not available. Plan accordingly:

- **Client-side pixel/mesh work**: your levers are `buffer`, `vector`, avoiding
  allocation, time-slicing, and parallel Luau. Not native codegen.
- **Server-side generation** (terrain, chunk layout, procedural placement,
  validation): native codegen is available and worth `--!native`.
- A useful architecture: generate on the server with `--!native`, ship the
  result as a `buffer` over a `RemoteEvent`, and have the client do only the
  `WritePixelsBuffer` / `BatchSetValues` commit.

### 3.2 Turning it on

Script-level:

```lua
--!native
--!strict

-- every function in this script is a candidate; the top-level scope is a
-- candidate only "if deemed profitable"
```

Function-level (RFC `syntax-attribute-functions-native.md`, status
*Implemented*):

```lua
@native
local function integrateParticles(pos: buffer, vel: buffer, count: number, dt: number)
	-- ...
end
```

**The attribute does not recurse.** From the RFC, verbatim: "It does not apply
recursively to the functions defined within the lexical scope of the attributed
function. These 'inner' functions have to be explicitly attributed for native
compilation." So this compiles only `parent`:

```lua
@native
function parent()
	function child() end   -- NOT native
end
```

and this compiles both:

```lua
@native
function parent()
	@native
	function child() end   -- native
end
```

That matters for the common closure-heavy style where the real work is in an
inner `local function`. Hoist it to module scope and attribute it.

### 3.3 What compiles, what falls back

Only **functions** are compiled. Top-level code usually runs once and is not
worth it.

Documented de-optimisation triggers (`native-code-gen.md`, "Code to avoid"):

| Trigger | Fix |
|---|---|
| `getfenv()` / `setfenv()` anywhere in the function | delete them; they are deprecated anyway |
| Builtins called with non-numeric arguments, e.g. `math.asin(someString)` | keep builtin arguments numeric; annotate |
| Argument types that contradict the declared type, e.g. `foo(true)` for `foo(arg: string)` | fix the call site or the annotation |
| Mispredicted types (unannotated `v.X` that is actually a `Vector3`) | annotate `v: Vector3` |
| A breakpoint placed in the function | remove it before measuring |

Note the asymmetry: an *unannotated* parameter gets a guess (usually "table"),
which costs guard checks; a *wrong* annotation is worse still.

### 3.4 Confirming it is actually active

Three independent checks — use at least two:

1. **Script Profiler** (Studio → Developer Console → Script Profiler, in
   **Server** view). Natively-executing functions are annotated `<native>` next
   to the name. If a function inside a `--!native` script has no `<native>`
   tag, it is being interpreted.
2. **`debug.dumpcodesize()`** from the Command Bar, in Server view. It prints
   the total number of natively compiled scripts and functions, the memory
   their native code occupies, and **the native code size limit**, followed by a
   per-script table in descending code size. Anonymous functions appear as
   `[anonymous]`, whole-script top-level code as `[top level]`, and the final
   column is the percentage of the global limit. This is the only way to see
   whether you are near the cap.
3. **Luau Heap** profiler — native code shows up as `[native]` elements in the
   graph (Developer Console → Memory → Luau Heap).

### 3.5 The hard limits

All four are quoted from `native-code-gen.md`:

| Limit | Error message | Meaning |
|---|---|---|
| 64K instructions per **code block** | *Function 'f' at line 20 exceeded single code block instruction limit* | one straight-line block got too big; split the function |
| 32K **blocks** per function | *…exceeded function code block limit* | control flow too complex; split the function |
| 1M instructions per **module** | *…exceeded total module instruction limit* | move big functions to a non-native script, or use `@native` selectively |
| global native-code **memory** cap | *Memory allocation limit reached for native code generation* | remove `--!native` from memory-heavy scripts |

Plus a general lowering failure: *encountered an internal lowering failure* /
*Internal error: Native code generation failed (assembly lowering)* — some
expression the backend cannot lower. Split the expression up and file a bug.

There is also an implicit limit worth stating plainly: **native compilation
happens at server startup and costs wall-clock time**. Marking every script
`--!native` measurably increases server boot time and RAM. Use `@native` on the
handful of functions that dominate a profile.

### 3.6 Measured speedups

Roblox publishes no official number. Community measurements from the beta
announcement thread `[COMMUNITY, SECOND-HAND]`:

- Ray→AABB intersection tests: ~2.6× faster.
- Ray→OBB intersection tests: ~1.3× faster.
- Conway's Game of Life step: ~1.4–2× faster.
- One developer reported "2–3× on average" for a suite of intersection tests.

Source: `devforum.roblox.com/t/luau-native-code-generation-preview-studio-beta/2572587`
(pages 3–4).

The shape of these results is the useful part: **native codegen pays for pure
arithmetic and loses its edge the moment you call into the engine**. A loop
that is 90% `Workspace:Raycast` will not speed up; a loop that is 90%
`buffer.readf32` + float math will. Measure with the Script Profiler, with and
without, on the same workload.

### 3.7 Writing native-friendly code

```lua
--!strict
--!native

-- Good: all parameters annotated, buffers, no closures, no engine calls.
@native
local function heightfieldToNormals(heights: buffer, w: number, h: number, scale: number): buffer
	local out = buffer.create(w * h * 12)

	for y = 0, h - 1 do
		local rowUp = (y > 0 and y - 1 or 0) * w * 4
		local rowDn = (y < h - 1 and y + 1 or h - 1) * w * 4
		local row = y * w * 4

		for x = 0, w - 1 do
			local xl = (x > 0 and x - 1 or 0) * 4
			local xr = (x < w - 1 and x + 1 or w - 1) * 4

			local hl = buffer.readf32(heights, row + xl)
			local hr = buffer.readf32(heights, row + xr)
			local hu = buffer.readf32(heights, rowUp + x * 4)
			local hd = buffer.readf32(heights, rowDn + x * 4)

			-- central differences; note we build a vector, not a Vector3
			local n = vector.normalize(vector.create((hl - hr) * scale, 2.0, (hu - hd) * scale))

			local o = (row + x * 4) * 3
			buffer.writef32(out, o, n.x)
			buffer.writef32(out, o + 4, n.y)
			buffer.writef32(out, o + 8, n.z)
		end
	end

	return out
end
```

Things that quietly kill native performance in real code:

- **Creating a closure inside the loop** (`function() ... end` captured per
  iteration). It allocates and it defeats specialisation. Hoist it.
- **`pcall` inside the hot loop.** Wrap the whole loop, not each iteration.
- **`table.insert` on a growing table.** Presize with `table.create` and write
  by index, or use a buffer.
- **String concatenation.** `..` allocates a new string every time; use
  `table.concat` or a buffer.
- **Any `Instance` property access.** It is a C++ call with a name lookup and
  it cannot be specialised. Cache before the loop.

---

## 4. The `buffer` library

### 4.1 Why it exists

From the RFC (`luau-lang/rfcs/docs/type-byte-buffer.md`, status *Implemented*):

> Tables can, at most, represent 64 bits per slot using expensive `vector`
> packing. Tables with or without packing severely bloat memory, as each array
> entry is subject to Luau value size and alignment. Strings are immutable and
> can't be used to efficiently construct binary data without exponential
> allocations.

Concretely: a `TValue` is 16 bytes (§1.1). One million float32s cost

- **16 MB** in a Luau array (plus GC scanning of the array every cycle), versus
- **4 MB** in a buffer (invisible to the GC's mark phase — it is a leaf object).

The buffer is a GCObject with its own tag, so it is collected normally, but its
*contents* are opaque bytes the collector never traverses. For a 1024×1024 RGBA
image that is the difference between a 4 MB allocation and a 67 MB table that
the GC walks.

### 4.2 The complete API

Ground truth: `VM/src/lbuflib.cpp` registration table, cross-checked against
Roblox's `reference/engine/libraries/buffer.yaml` (26 members, Studio `0.739`).

**Lifecycle**

| Function | Notes |
|---|---|
| `buffer.create(size: number): buffer` | `size` must be a non-negative integer. Every byte is zero-initialised. |
| `buffer.fromstring(s: string): buffer` | Size equals `#s`; contents `memcpy`'d. |
| `buffer.tostring(b: buffer): string` | Allocates a new string of `buffer.len(b)` bytes. |
| `buffer.len(b: buffer): number` | O(1). |

**Fixed-width numeric access** — all take a byte `offset`, all zero-based:

| Read | Write | Width | Range |
|---|---|---|---|
| `readi8` | `writei8` | 1 | −128 … 127 |
| `readu8` | `writeu8` | 1 | 0 … 255 |
| `readi16` | `writei16` | 2 | −32768 … 32767 |
| `readu16` | `writeu16` | 2 | 0 … 65535 |
| `readi32` | `writei32` | 4 | −2³¹ … 2³¹−1 |
| `readu32` | `writeu32` | 4 | 0 … 2³²−1 |
| `readf32` | `writef32` | 4 | IEEE754 binary32 |
| `readf64` | `writef64` | 8 | IEEE754 binary64 |

**Bulk**

| Function | Implementation |
|---|---|
| `buffer.copy(dst, dstOffset, src, srcOffset?, count?)` | a single `memmove` — **overlap-safe**, source and destination may be the same buffer |
| `buffer.fill(b, offset, value, count?)` | a single `memset` with `value & 0xff` |
| `buffer.readstring(b, offset, count): string` | |
| `buffer.writestring(b, offset, s, count?)` | `count` may not exceed `#s` |

**Sub-byte** (RFC `function-buffer-bits.md`)

| Function | Notes |
|---|---|
| `buffer.readbits(b, bitOffset, bitCount): number` | `bitCount` must be in `[0, 32]`; returns an unsigned value |
| `buffer.writebits(b, bitOffset, bitCount, value)` | read-modify-write of the touched bytes |

`bitOffset` is a **bit** offset, not a byte offset, and it is read with
`luaL_checknumber` (not `checkinteger`), so it may exceed 2³¹ safely for large
buffers.

> **Master-only, not on Roblox:** `buffer.readinteger` / `buffer.writeinteger`
> (64-bit) exist in `lbuflib.cpp` on `luau-lang/luau` `master` behind the
> `LuauIntegerLibrary` fast flag. They are **not** in Roblox's `buffer.yaml`.
> Do not use them yet. `[UNVERIFIED]` for a Roblox ship date.

### 4.3 Semantics you must get right

**Offsets are zero-based.** From the RFC: "All offsets start at 0 (not to be
confused with indices that start at 1 in Luau tables). This choice is made for
both performance reasons (no need to subtract 1) and for compatibility with
data formats." Mixing 1-based table idioms with 0-based buffer idioms in the
same function is the #1 source of buffer bugs. Pick a convention per file and
name your variables `offset`/`byteOffset` (0-based) versus `index` (1-based).

**Endianness is little-endian, everywhere.** The RFC: "Read and write
operations for relevant types are little endian as it is the most common use
case." The implementation backs this: on a big-endian host the VM explicitly
byte-swaps (`buffer_swapbe` using `htole64`/`htole32`/`htole16`) so that Luau
semantics stay little-endian. **Your serialized buffers are portable across
every platform Roblox runs on.**

**Alignment does not matter.** The RFC: "unaligned offsets in all operations
are valid and behave as expected." The implementation uses `memcpy` into a
local of the right type rather than a pointer cast, which is both UB-free and,
on every modern CPU, compiled to a single unaligned load. You can pack a
13-byte vertex struct with no padding and read `f32` at offset 9. **Do it
anyway only if memory is the binding constraint** — aligned layouts are still
marginally faster on some ARM cores. `[UNVERIFIED]` for magnitude on Roblox's
mobile targets.

**Bounds checks are one comparison.** From `lbuflib.cpp`:

```c
#define isoutofbounds(offset, len, accessize) \
    (uint64_t(unsigned(offset)) + (accessize) > uint64_t(len))
```

The comment above it explains the trick: "because offset is limited to an
integer, a single 64-bit comparison can be used and will not overflow". A
negative offset becomes a huge unsigned value and fails the check. So the cost
of a bounds check is **one 64-bit compare and a predictable branch** — on the
order of a nanosecond, not a function call. Every `buffer.read*` in a hot loop
pays it. That is the price of memory safety and it is cheap; do **not** try to
avoid it by hoisting reads into tables.

Native codegen additionally has dedicated fastcall lowerings for buffer access
(`luauF_readinteger<int8_t>`, `luauF_readfp<float>`, … in `lbuiltins.cpp`), so
under `--!native` a `buffer.readf32` becomes close to a bare load plus a
compare.

**Maximum size** is `MAX_BUFFER_SIZE = 1 << 30` = 1,073,741,824 bytes
(`VM/src/lbuffer.h`), and the implementation asserts it fits in `INT_MAX`.
Practically you will hit Roblox's memory budget long before this. A 4096×4096
RGBA image is 67 MB — already a lot on a mobile client.

**Minimum allocation** is 8 bytes of payload:
`sizebuffer(len) = offsetof(Buffer, data) + max(len, 8)`. `buffer.create(1)` is
not meaningfully cheaper than `buffer.create(8)`.

**Buffers are fixed-size.** There is no `buffer.resize`. The RFC explicitly
defers it. Grow by allocating a new buffer at 2× and `buffer.copy`-ing:

```lua
local function ensureCapacity(b: buffer, needed: number): buffer
	local cap = buffer.len(b)
	if needed <= cap then return b end
	local newCap = cap
	repeat newCap = math.max(newCap * 2, 64) until newCap >= needed
	local nb = buffer.create(newCap)
	buffer.copy(nb, 0, b, 0, cap)
	return nb
end
```

### 4.4 The RGBA pixel-buffer pattern

`EditableImage:ReadPixelsBuffer(position, size)` returns, per the YAML: "a
buffer where each pixel is represented by four bytes (red, green, blue and
alpha respectively). The length of the buffer can be calculated as
`Size.X * Size.Y * 4` bytes." `WritePixelsBuffer(position, size, buffer)` takes
the same layout. Note the YAML's warning: **these methods use *alpha*, not
transparency**, unlike the `Draw*` methods.

So the layout is: row-major, top-left origin, 4 bytes per pixel, `R,G,B,A`,
each `0..255`.

```lua
--!strict
-- A pixel canvas over a raw RGBA8 buffer. No tables, no per-pixel allocation.

local Canvas = {}
Canvas.__index = Canvas

export type Canvas = typeof(setmetatable(
	{} :: { w: number, h: number, data: buffer },
	Canvas
))

function Canvas.new(w: number, h: number): Canvas
	return setmetatable({ w = w, h = h, data = buffer.create(w * h * 4) }, Canvas)
end

-- Index math, isolated so you only get it wrong once.
local function pixelOffset(self: Canvas, x: number, y: number): number
	return (y * self.w + x) * 4
end

function Canvas.setPixel(self: Canvas, x: number, y: number, r: number, g: number, b: number, a: number)
	local o = (y * self.w + x) * 4
	buffer.writeu8(self.data, o, r)
	buffer.writeu8(self.data, o + 1, g)
	buffer.writeu8(self.data, o + 2, b)
	buffer.writeu8(self.data, o + 3, a)
end

-- Faster: one 32-bit write instead of four 8-bit writes.
-- Little-endian means byte 0 is the LOW byte, so R is bits 0-7.
function Canvas.setPixelFast(self: Canvas, x: number, y: number, rgba: number)
	buffer.writeu32(self.data, (y * self.w + x) * 4, rgba)
end

local function packRGBA(r: number, g: number, b: number, a: number): number
	-- r | g<<8 | b<<16 | a<<24, as an unsigned 32-bit value
	return bit32.bor(r, bit32.lshift(g, 8), bit32.lshift(b, 16), bit32.lshift(a, 24))
end

function Canvas.getPixel(self: Canvas, x: number, y: number): (number, number, number, number)
	local o = (y * self.w + x) * 4
	return buffer.readu8(self.data, o),
		buffer.readu8(self.data, o + 1),
		buffer.readu8(self.data, o + 2),
		buffer.readu8(self.data, o + 3)
end

function Canvas.commit(self: Canvas, image: EditableImage)
	image:WritePixelsBuffer(Vector2.zero, Vector2.new(self.w, self.h), self.data)
end

return Canvas
```

Two measured-in-principle wins in that code:

1. **`writeu32` instead of four `writeu8`** cuts four bounds checks and four VM
   calls down to one. For a full 1024×1024 clear that is 4.2 million calls
   saved.
2. **Hoisting the offset computation.** `(y * self.w + x) * 4` computed once per
   pixel, never inside a colour expression.

### 4.5 The doubling-memcpy fill — O(log N) clears and tiles

`buffer.fill` is a `memset`, so a single-byte fill is already optimal. But a
**repeating multi-byte pattern** — a solid RGBA colour, a 16-pixel checker, a
tiled row — has no memset. The classic trick is to write the pattern once and
then repeatedly double it with `buffer.copy` (which is `memmove`, running at
memory bandwidth):

```lua
--!strict
--!native

-- Fill `dst[offset .. offset+count-1]` by tiling `pattern` (patternLen bytes).
-- Does ceil(log2(count / patternLen)) + 1 Luau-level calls instead of
-- count/patternLen of them.
local function tileFill(dst: buffer, offset: number, count: number, pattern: buffer, patternLen: number)
	if count <= 0 then return end

	-- Seed: one copy of the pattern (clamped, in case count < patternLen).
	local seed = math.min(patternLen, count)
	buffer.copy(dst, offset, pattern, 0, seed)

	-- Double: each iteration copies everything written so far to the region
	-- immediately after it, so the written length goes 1, 2, 4, 8, ... n.
	local written = seed
	while written < count do
		local chunk = math.min(written, count - written)
		buffer.copy(dst, offset + written, dst, offset, chunk)
		written += chunk
	end
end

-- Clear an entire RGBA canvas to one colour.
local function clearRGBA(data: buffer, w: number, h: number, r: number, g: number, b: number, a: number)
	-- Fast path: a fully-uniform byte pattern is just a memset.
	if r == g and g == b and b == a then
		buffer.fill(data, 0, r, w * h * 4)
		return
	end

	local px = buffer.create(4)
	buffer.writeu8(px, 0, r); buffer.writeu8(px, 1, g)
	buffer.writeu8(px, 2, b); buffer.writeu8(px, 3, a)

	tileFill(data, 0, w * h * 4, px, 4)
end
```

For a 1024×1024 canvas (4,194,304 bytes) `tileFill` does **21 `buffer.copy`
calls**. The naive loop does 1,048,576 `writeu32` calls. The doubling version
is not 50,000× faster in wall clock — it is bounded by memory bandwidth, not
call count — but it removes essentially all interpreter overhead, and in
practice it turns a multi-frame clear into a sub-millisecond one.

The same structure tiles a texture row, then tiles that row down the image:

```lua
-- Tile a WxH RGBA tile across a canvas of cw x ch.
local function tileImage(dst: buffer, cw: number, ch: number, tile: buffer, tw: number, th: number)
	local rowBytes = cw * 4
	local tileRowBytes = tw * 4

	-- 1. Build the first `th` rows by tiling horizontally.
	for y = 0, math.min(th, ch) - 1 do
		local dstRow = y * rowBytes
		buffer.copy(dst, dstRow, tile, y * tileRowBytes, math.min(tileRowBytes, rowBytes))
		local written = math.min(tileRowBytes, rowBytes)
		while written < rowBytes do
			local chunk = math.min(written, rowBytes - written)
			buffer.copy(dst, dstRow + written, dst, dstRow, chunk)
			written += chunk
		end
	end

	-- 2. Double the completed block downwards.
	local doneRows = math.min(th, ch)
	while doneRows < ch do
		local chunkRows = math.min(doneRows, ch - doneRows)
		buffer.copy(dst, doneRows * rowBytes, dst, 0, chunkRows * rowBytes)
		doneRows += chunkRows
	end
end
```

**Why the doubling is safe with overlap:** `buffer.copy` is `memmove`, and the
RFC states explicitly that "copying an overlapping region inside the same
buffer acts as if the source region is copied into a temporary buffer and then
that buffer is copied over to the target". In the doubling loop the source and
destination never overlap anyway (`chunk <= written`), but the guarantee means
you do not have to prove it.

### 4.6 The vertex-buffer pattern

Interleaved or planar — both work; pick based on access pattern.

```lua
--!strict
--!native

-- Interleaved vertex: position (3xf32) + normal (3xf32) + uv (2xf32) = 32 bytes
local STRIDE = 32
local OFF_POS, OFF_NRM, OFF_UV = 0, 12, 24

local function newVertexBuffer(vertexCount: number): buffer
	return buffer.create(vertexCount * STRIDE)
end

local function setPosition(vb: buffer, i: number, p: vector)
	local o = i * STRIDE + OFF_POS
	buffer.writef32(vb, o, p.x)
	buffer.writef32(vb, o + 4, p.y)
	buffer.writef32(vb, o + 8, p.z)
end

local function getPosition(vb: buffer, i: number): vector
	local o = i * STRIDE + OFF_POS
	return vector.create(buffer.readf32(vb, o), buffer.readf32(vb, o + 4), buffer.readf32(vb, o + 8))
end

-- Index buffer: u32 triples. u16 if you are certain vertexCount <= 65535 —
-- halves the memory and is measurably friendlier to cache.
local function newIndexBuffer(triCount: number): buffer
	return buffer.create(triCount * 12)
end
```

Planar (structure-of-arrays) instead — one buffer per attribute — is better when
a pass touches only one attribute (e.g. recomputing normals, or smoothing
positions), because every cache line you pull in is 100% useful. Interleaved is
better when a pass touches all attributes of one vertex (e.g. a transform).
For `EditableMesh` specifically, the `Batch*` API takes per-attribute arrays,
which nudges you toward planar.

### 4.7 Buffer versus table: the decision rule

Use a **buffer** when:

- the data is homogeneous numbers (positions, colours, indices, heights, flags);
- there are more than a few thousand elements;
- you need to hand it to an engine API that takes a buffer
  (`WritePixelsBuffer`, `RemoteEvent` payloads);
- the data crosses an Actor boundary (buffers are cheap to hand over);
- memory or GC pressure is a concern.

Use a **table** when:

- elements are heterogeneous or reference objects (`Instance`, closures);
- the collection is small (< ~1000) and clarity matters more;
- you need `table.sort`, `table.find`, or key-value lookup.

Do **not** use a table of `Vector3`s for vertex data. A million vertices as a
table of `Vector3` is 16 MB of `TValue` *plus* a million heap objects the GC
must mark and sweep every cycle. The same data in a buffer is 12 MB, one
allocation, zero GC traversal.

---

## 5. Parallel Luau

### 5.1 The execution model

Roblox's frame has a **serial phase** and a **parallel phase**. Code runs
serially by default. Code inside an `Actor` may move itself into the parallel
phase with `task.desynchronize()` and back with `task.synchronize()`.

Facts that constrain every design (`Actor.yaml`, `task.yaml`,
`scripting/multithreading.md`):

- **Each `Actor` runs in its own Luau VM.** `ModuleScript`s required by an Actor
  are **not** shared or cached across Actors or with the main thread. Each VM
  executes its own copy of the module, so module-level state is isolated per
  Actor. A memoization cache in a module is per-Actor. A "singleton" is not a
  singleton.
- `script:GetActor()` returns `nil` when called from a `ModuleScript` unless
  that module is a **descendant of the Actor**. Modules in `ReplicatedStorage`
  required by an Actor are not descendants.
- Only descendants of an `Actor` may call `task.desynchronize()`. Elsewhere it
  errors.
- `task.desynchronize()` in an already-parallel phase returns immediately and
  does nothing. It is idempotent, not a nesting counter.
- **`require()` is illegal in a desynchronized phase.** Require everything
  during the serial startup of the Actor's script.
- Scripts under the *same* Actor still execute sequentially with respect to
  each other. Parallelism comes from having **many Actors**, not many scripts.
- Do not nest Actors. If you do, the script belongs to its **closest ancestor**
  Actor.

`RBXScriptSignal:ConnectParallel(fn)` is the efficient form of "connect, then
immediately desynchronize" — the YAML says it is "similar to, but more
efficient than, using `Connect` followed by a call to `task.desynchronize()`".
It also requires the script to be rooted under an Actor.

### 5.2 Thread-safety levels — the authoritative definitions

From `scripting/multithreading.md`:

| Level | Properties | Functions |
|---|---|---|
| **Unsafe** | Cannot be read or written in parallel. | Cannot be called in parallel. |
| **Read Parallel** (`ReadSafe` in the YAML) | Can be read but not written in parallel. | N/A |
| **Local Safe** (`LocalSafe`) | Usable within the same Actor; readable but not writable by other Actors. | Callable within the same Actor; not callable by other Actors. |
| **Safe** | Can be read and written. | Can be called. |

And the default, which you must internalise:

> If an API member doesn't specify a thread safety level, by default its thread
> safety level is **Unsafe**.

In the machine-readable reference this appears as a `thread_safety:` key on
every member of every `*.yaml` under
`content/en-us/reference/engine/classes/`. That is the ground truth used
throughout this section; the values below were extracted directly from Studio
version `0.739.0.7390687` of `Roblox/creator-docs`.

### 5.3 `EditableImage`: almost nothing is parallel-safe

This matters a great deal for a runtime-image project, so here is the complete
table, every member, verbatim from `EditableImage.yaml`:

| Member | `thread_safety` |
|---|---|
| `EditableImage.Size` | **ReadSafe** |
| `EditableImage:ReadPixelsBuffer` | **Safe** |
| `EditableImage:WritePixelsBuffer` | **Unsafe** |
| `EditableImage:DrawCircle` | Unsafe |
| `EditableImage:DrawImage` | Unsafe |
| `EditableImage:DrawImageProjected` | Unsafe |
| `EditableImage:DrawImageTransformed` | Unsafe |
| `EditableImage:DrawLine` | Unsafe |
| `EditableImage:DrawRectangle` | Unsafe |
| `EditableImage:SampleImageProjected` | Unsafe |
| `EditableImage:Destroy` | Unsafe |

**Conclusion: you can read pixels in parallel and you cannot write them.**
`ReadPixelsBuffer` is `Safe`, so multiple Actors may simultaneously sample the
same image. `WritePixelsBuffer` and every `Draw*` operation must run in the
serial phase.

Also note `AssetService:CreateEditableImage` and
`AssetService:CreateEditableImageAsync` are both **Unsafe** — you cannot even
create an `EditableImage` in parallel. Create it serially, hand the reference
to the workers.

### 5.4 `EditableMesh`: every reader is safe, every writer is not

From `EditableMesh.yaml` (95 members carry `thread_safety`). The rule is
mechanically clean:

**Safe in parallel** — every query and every getter:

`GetPosition`, `GetVertices`, `GetFaces`, `GetFaceVertices`, `GetNormal`,
`GetNormals`, `GetUV`, `GetUVs`, `GetColor`, `GetColorAlpha`, `GetColors`,
`GetFaceColors`, `GetFaceNormals`, `GetFaceUVs`, `GetVertexColors`,
`GetVertexNormals`, `GetVertexUVs`, `GetVertexFaces`, `GetVertexFaceColor`,
`GetVertexFaceNormal`, `GetVertexFaceUV`, `GetAdjacentFaces`,
`GetAdjacentVertices`, `GetCenter`, `GetSize`,
`GetVerticesWithAttribute`, `GetVerticesWithColor`, `GetVerticesWithNormal`,
`GetVerticesWithUV`, `GetFacesWithAttribute`, `GetFacesWithColor`,
`GetFacesWithNormal`, `GetFacesWithUV`,
`FindClosestPointOnSurface`, `FindClosestVertex`, `FindVerticesWithinSphere`,
`RaycastLocal`,
the bone getters (`GetBones`, `GetBoneByName`, `GetBoneCFrame`, `GetBoneName`,
`GetBoneParent`, `GetBoneIsVirtual`, `GetVertexBones`, `GetVertexBoneWeights`),
the FACS getters (`GetFacsPose`, `GetFacsPoses`, `GetFacsCorrectivePose`,
`GetFacsCorrectivePoses`), and **all four batch readers**:
`BatchGetValues`, `BatchGetVertexAttributes`, `BatchGetFaceAttributes`,
`BatchGetVertexFaceAttributes`.

`EditableMesh.FixedSize` is **ReadSafe**.

**Unsafe in parallel** — every mutator, without exception:

`AddVertex`, `AddTriangle`, `AddNormal`, `AddUV`, `AddColor`, `AddBone`,
`BatchAdd`, `BatchRemove`, `BatchSetValues`, `BatchSetFaceAttributes`,
`BatchSetVertexFaceAttributes`, `SetPosition`, `SetNormal`, `SetUV`,
`SetColor`, `SetColorAlpha`, `SetFaceVertices`, `SetFaceColors`,
`SetFaceNormals`, `SetFaceUVs`, `SetVertexFaceColor`, `SetVertexFaceNormal`,
`SetVertexFaceUV`, `SetVertexBones`, `SetVertexBoneWeights`, `SetBoneCFrame`,
`SetBoneName`, `SetBoneParent`, `SetBoneIsVirtual`, `SetFacsPose`,
`SetFacsBonePose`, `SetFacsCorrectivePose`, `RemoveFace`, `RemoveBone`,
`RemoveUnused`, `ResetNormal`, `MergeVertices`, `Triangulate`, `Clear`,
`Destroy`, `IdDebugString`.

`AssetService:CreateEditableMesh` and `CreateEditableMeshAsync` are **Unsafe**;
so is `AssetService:CreateMeshPartAsync`.

**This asymmetry is the whole design.** `EditableMesh` is a read-many /
write-one structure in parallel terms. Deformation, collision queries, nearest-
point searches, and attribute reads all parallelize perfectly. Committing the
result does not.

### 5.5 The pattern that follows: compute parallel, commit serial

Everything above collapses into one recipe.

```lua
--!strict
-- ModuleScript-free worker script, placed under an Actor.
-- The Actor is created and the EditableImage handed over in the serial phase.

local actor = script:GetActor()
assert(actor, "this script must be a descendant of an Actor")

-- Requires MUST happen here, in the serial phase.
local Noise = require(script.Parent.NoiseModule)

actor:BindToMessageParallel("PaintTile", function(image: EditableImage, ox: number, oy: number, w: number, h: number, seed: number)
	-- ============ PARALLEL PHASE ============
	-- Pure Luau + buffers. No Instance writes, no EditableImage writes.
	local tile = buffer.create(w * h * 4)

	for y = 0, h - 1 do
		local wy = (oy + y) * 0.01
		local row = y * w * 4
		for x = 0, w - 1 do
			local n = Noise.fbm((ox + x) * 0.01, wy, seed)      -- returns 0..1
			local v = math.floor(n * 255 + 0.5)
			-- one 32-bit store, little-endian: R in the low byte
			buffer.writeu32(tile, row + x * 4,
				bit32.bor(v, bit32.lshift(v, 8), bit32.lshift(v, 16), 0xFF000000))
		end
	end

	-- ============ SERIAL PHASE ============
	task.synchronize()
	image:WritePixelsBuffer(Vector2.new(ox, oy), Vector2.new(w, h), tile)
end)
```

And the dispatcher, which is the self-cloning idiom Roblox's own docs use:

```lua
--!strict
-- Dispatcher: runs once, spawns N Actor clones of the worker, fans out tiles.
local AssetService = game:GetService("AssetService")

local WORKERS = 32          -- more than core count on purpose; see §5.8
local TILE = 64

local image = AssetService:CreateEditableImage({ Size = Vector2.new(1024, 1024) })

local workers = table.create(WORKERS)
for i = 1, WORKERS do
	local a = Instance.new("Actor")
	script.WorkerTemplate:Clone().Parent = a
	workers[i] = a
end
for _, a in workers do
	a.Parent = script
end

local n = 0
for ty = 0, 1024 // TILE - 1 do
	for tx = 0, 1024 // TILE - 1 do
		n += 1
		workers[(n - 1) % WORKERS + 1]:SendMessage("PaintTile", image, tx * TILE, ty * TILE, TILE, TILE, 1337)
	end
end
```

Three properties of this that are worth naming:

1. **The expensive part (noise, per-pixel math) is fully parallel.** The serial
   part is one `WritePixelsBuffer` per tile, which is a bounded `memcpy` into
   the image.
2. **Tiles do not overlap**, so the serial writes never conflict, and you do not
   need any locking.
3. **Each worker allocates its own tile buffer.** Buffers are ordinary Luau
   values living in the Actor's own VM; no engine permission is involved.

### 5.6 Cross-Actor communication: the three mechanisms and their costs

**(a) Actor messaging** — `Actor:SendMessage(topic, ...)`,
`Actor:BindToMessage(topic, fn)` (serial callback),
`Actor:BindToMessageParallel(topic, fn)` (parallel callback). All three are
`thread_safety: Safe`.

The cost model, straight from `Actor.yaml`:

> Message arguments are **passed by copy** across Luau VM boundaries, not by
> reference. Sending large tables incurs a full copy on each call. Functions are
> bound to a specific VM and cannot be passed in messages.

So:

- `SendMessage` is asynchronous; the sender never blocks.
- A `buffer` argument costs a `memcpy` of its bytes. That is cheap *per byte*
  but it is still O(n) — do not ping-pong a 64 MB buffer every frame.
- A table argument costs a **deep copy**, element by element, with all the
  allocation that implies. Convert to a buffer first if it is numeric.
- Closures cannot cross. Neither can anything holding a closure.
- `Instance` references *can* cross (the dispatcher above passes an
  `EditableImage`), because an Instance is engine-side, not VM-side.

**(b) `SharedTable`** — the only genuinely *shared* mutable structure.

From `datatypes/SharedTable.yaml`:

- **Keys**: a string, or a non-negative integer `< 2³²`. Nothing else.
- **Values**: boolean, number, **vector**, string, `SharedTable`, or a
  serializable data type. (A `buffer` is **not** listed. `[UNVERIFIED]` whether
  buffers are accepted; assume not and use `buffer.tostring` → string, since
  strings are immutable and therefore safe to share.)
- Distinct `SharedTable`s never compare equal, even with equal contents.
- `SharedTable.clear(st)` is **atomic**.
- `SharedTable.increment(st, key, delta)` is **atomic** and returns the
  *original* value. The element must already exist and be a number. This is
  your atomic counter.
- `SharedTable.update(st, key, fn)` applies a transform atomically — the
  general read-modify-write primitive.
- `SharedTable.clone(st, deep?)` is **atomic per table** and uses structural
  sharing; a *deep* clone is atomic per node but not atomic as a whole.
- `SharedTable.cloneAndFreeze(st, deep?)` gives you an immutable snapshot.
  Writes to a frozen SharedTable raise an error. `SharedTable.isFrozen(st)`
  tests it.
- `SharedTable.size(st)`.
- `SharedTableRegistry:GetSharedTable(name)` / `:SetSharedTable(name, st)` —
  both `Safe` — are the global-by-name access path.

**Cost model.** Every element access on a SharedTable crosses a
synchronization boundary and involves reference counting and copy-on-read of
the value. It is nowhere near as fast as a Luau table index, let alone a buffer
read. Use SharedTables for **coordination** (a work queue index, a counter, a
frozen snapshot of configuration) and never as a bulk numeric array.

A concrete idiom — an atomic work-stealing counter shared by all workers:

```lua
local SharedTableRegistry = game:GetService("SharedTableRegistry")

-- Serial setup, once:
local queue = SharedTable.new({ next = 1, total = 4096 })
SharedTableRegistry:SetSharedTable("ChunkQueue", queue)

-- In each parallel worker:
local q = SharedTableRegistry:GetSharedTable("ChunkQueue")
while true do
	local i = SharedTable.increment(q, "next", 1)  -- returns the ORIGINAL value
	if i > q.total then break end
	generateChunk(i)
end
```

**(c) Direct data model communication** — writing a property or attribute in
serial and reading it in parallel. The docs are explicit that this "comes with
restrictions and may force scripts to synchronize frequently, which can impact
performance". Use it for small, slow-changing configuration, not for a data
channel.

### 5.7 What is legal in the parallel phase — a checklist

Legal (verified `Safe` or `ReadSafe` in the YAML, or pure Luau):

- All pure Luau: arithmetic, `buffer.*`, `vector.*`, `math.*`, `table.*`,
  `string.*`, `bit32.*`, `os.clock`.
- Creating and mutating local tables and buffers inside the Actor's own VM.
- `Workspace:Raycast`, `Workspace:GetPartBoundsInBox` and friends
  (spatial queries are `Safe` — verify the specific member's `thread_safety`
  before relying on it).
- Reading `ReadSafe` properties of Instances (most geometric properties are).
- `EditableMesh` getters and queries (§5.4).
- `EditableImage:ReadPixelsBuffer` and `.Size`.
- `Actor:SendMessage`, and all `SharedTable` operations.
- `RunService:IsClient/IsServer/IsStudio/IsEdit/IsRunMode/IsResimulating`.

Illegal (and the engine will detect and error):

- `require()`.
- Writing **any** Instance property.
- `Instance.new`, `:Destroy()`, reparenting.
- `EditableImage:WritePixelsBuffer` and every `Draw*`.
- Every `EditableMesh` mutator, including the `Batch*Set*` family.
- `AssetService:CreateEditableImage/Mesh/MeshPartAsync`.
- `Terrain:WriteVoxels` (Roblox's own sample calls `task.synchronize()` before
  it, with the comment "Currently, `WriteVoxels()` must be called in the serial
  phase").
- Firing `RemoteEvent`s. `[UNVERIFIED]` — check
  `RemoteEvent.yaml`'s `thread_safety` for your engine version before assuming.

### 5.8 How many Actors?

Roblox's own guidance, verbatim:

> For the best performance, use more Actors. Even if the device has fewer cores
> than Actors, the granularity allows for more efficient load balancing between
> the cores. […] it's reasonable to use 64 Actors and more instead of just 4,
> even if you're targeting 4-core systems.

Balanced against:

> Even in parallel, long computations can block execution of other scripts and
> cause lag. Avoid using parallel programming to handle a large volume of long,
> unyielding calculations.

Practical rule for generation work: **make the unit of work small enough that a
single unit fits comfortably inside one frame's parallel budget**, then make
the number of Actors ≫ core count so the scheduler can balance. A 64×64 tile
of Perlin noise is a good unit; a 1024×1024 image is not.

The second half of that quote is the trap people fall into: parallel does not
mean unbounded. The parallel phase still lives inside a frame. If every Actor
takes 40 ms, you dropped the frame on every core simultaneously. **Time-slicing
(§6.4) still applies inside parallel workers.**

### 5.9 Debugging parallel code

- An illegal operation in the parallel phase raises a normal Luau error naming
  the member. Read it literally: "cannot be called in parallel" means exactly
  the `thread_safety: Unsafe` in the YAML.
- Because each Actor is its own VM, `print` output interleaves
  nondeterministically. Prefix with the Actor name.
- Module state is per-Actor (§5.1). A bug where "the cache is always empty" is
  almost always this.
- The MicroProfiler shows parallel work on worker-thread lanes; see §9.

---

