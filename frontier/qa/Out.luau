-- Headless QA output: timings, checks and RGBA frames, streamed on stdout for qa/run.py.
-- Protocol (one record per call):
--   @@TIME <name> <ms per iteration> <iterations>
--   @@CHECK <name> <ok|FAIL> <detail>
--   @@IMG <name> <w> <h> <nbytes>   followed by exactly nbytes of raw RGBA8 and a newline

local Out = {}

local failures = 0

function Out.time(name: string, iters: number, f: () -> ())
	f() -- warm-up (also lets native code settle)
	local t0 = os.clock()
	for _ = 1, iters do
		f()
	end
	local ms = (os.clock() - t0) * 1000 / iters
	print(string.format("@@TIME %s %.4f %d", name, ms, iters))
	return ms
end

function Out.check(name: string, ok: boolean, detail: string?)
	if not ok then
		failures += 1
	end
	print(string.format("@@CHECK %s %s %s", name, if ok then "ok" else "FAIL", detail or ""))
end

function Out.image(name: string, w: number, h: number, rgba: buffer)
	assert(buffer.len(rgba) == w * h * 4, "image size mismatch for " .. name)
	print(string.format("@@IMG %s %d %d %d", name, w, h, w * h * 4))
	print(buffer.tostring(rgba))
end

function Out.done()
	print(string.format("@@DONE %d", failures))
end

return Out
