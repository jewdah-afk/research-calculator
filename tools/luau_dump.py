#!/usr/bin/env python3
"""Parse a generated Luau data module into Python objects.

Only supports the strict subset tools/gen_luau.py emits: one `local <Name> = {...}`
table literal of numbers, strings, booleans, arrays and records, plus `::` type
assertions on a table (which carry no value and are skipped). No Luau runtime
is available in this environment, so the gates parse the emitted text directly --
which also means the gates validate the exact bytes that ship.

Usage as a library: load(path) -> dict.  As a CLI: luau_dump.py <file> -> JSON.
"""
import json, re, sys

TOKEN = re.compile(r"""
    (?P<ws>\s+)
  | (?P<comment>--\[\[.*?\]\]|--[^\n]*)
  | (?P<typecast>::\s*(?:\{[^{}]*\}|[A-Za-z_][A-Za-z0-9_.]*))
  | (?P<string>"(?:[^"\\]|\\.)*")
  | (?P<number>-?\d+\.\d+(?:[eE][-+]?\d+)?|-?\d+(?:[eE][-+]?\d+)?)
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<punct>[\{\}\[\]=,.])
""", re.X | re.S)

ESCAPES = {"n": "\n", "r": "\r", "t": "\t", '"': '"', "\\": "\\"}


def tokenize(src, stop_on_balance=False):
    pos, out, depth, started = 0, [], 0, False
    while pos < len(src):
        m = TOKEN.match(src, pos)
        if not m:
            raise SyntaxError("unparsable at offset {}: {!r}".format(pos, src[pos:pos + 40]))
        pos = m.end()
        kind = m.lastgroup
        if kind in ("ws", "comment", "typecast"):
            continue
        out.append((kind, m.group()))
        if stop_on_balance and kind == "punct":
            if m.group() == "{":
                depth += 1
                started = True
            elif m.group() == "}":
                depth -= 1
                if started and depth == 0:
                    break
    return out


def unquote(s):
    body, out, i = s[1:-1], [], 0
    while i < len(body):
        c = body[i]
        if c == "\\":
            i += 1
            out.append(ESCAPES.get(body[i], body[i]))
        else:
            out.append(c)
        i += 1
    return "".join(out)


class Parser:
    def __init__(self, toks, consts=None):
        self.t, self.i = toks, 0
        self.consts = consts or {}

    def peek(self):
        return self.t[self.i] if self.i < len(self.t) else (None, None)

    def take(self, val=None):
        k, v = self.t[self.i]
        if val is not None and v != val:
            raise SyntaxError("expected {!r}, got {!r}".format(val, v))
        self.i += 1
        return v

    def value(self):
        k, v = self.peek()
        if v == "{":
            return self.table()
        self.i += 1
        if k == "string":
            return unquote(v)
        if k == "number":
            return float(v) if ("." in v or "e" in v or "E" in v) else int(v)
        if v == "true":
            return True
        if v == "false":
            return False
        if v == "nil":
            return None
        if k == "name":
            # A bare identifier in value position is the module's UNKNOWN
            # sentinel (possibly written `M.UNKNOWN`). Both mean "absent from
            # the source data"; the gates treat it as None.
            while self.peek()[1] == ".":
                self.take(".")
                v = self.take()
            if v.endswith("UNKNOWN"):
                return None
            if v in self.consts:
                return self.consts[v]
            raise SyntaxError("unexpected identifier in value position: {!r}".format(v))
        raise SyntaxError("unexpected value token {!r}".format(v))

    def table(self):
        self.take("{")
        arr, rec = [], {}
        while True:
            k, v = self.peek()
            if v == "}":
                self.take("}")
                break
            if v == "[":
                self.take("[")
                key = self.value()
                self.take("]")
                self.take("=")
                rec[key] = self.value()
            elif k == "name" and self.t[self.i + 1][1] == "=":
                key = self.take()
                self.take("=")
                rec[key] = self.value()
            else:
                arr.append(self.value())
            if self.peek()[1] == ",":
                self.take(",")
        if rec and arr:
            raise SyntaxError("mixed array/record table")
        return rec if rec or not arr else arr


def load(path):
    src = open(path).read()
    # The module table is the LAST `local <Name> = {` in the file; earlier ones
    # are helpers (sentinels, constants) the gates do not need.
    ms = list(re.finditer(r"^local\s+[A-Za-z_][A-Za-z0-9_]*\s*=\s*\{", src, re.M))
    if not ms:
        raise SyntaxError("no module table found in " + path)
    m = ms[-1]
    consts = {n: (float(x) if "." in x else int(x))
              for n, x in re.findall(r"^local\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(-?\d+\.?\d*)\s*$",
                                     src, re.M)}
    toks = tokenize(src[m.end() - 1:], stop_on_balance=True)
    return Parser(toks, consts).table()


if __name__ == "__main__":
    print(json.dumps(load(sys.argv[1]), indent=1, sort_keys=True))
