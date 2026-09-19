--!strict
-- Minimal headless test harness for the plain `luau` CLI. No Roblox APIs.
-- Usage in a test file:
--   local T = require("./_harness")
--   T.test("name", function() T.eq(actual, expected, "label") end)
--   return T.finish()
local Harness = {}

local passed, failed = 0, 0
local failures: { string } = {}
local current = ""

local function fail(msg: string)
	failed += 1
	table.insert(failures, string.format("  [%s] %s", current, msg))
end

function Harness.test(name: string, fn: () -> ())
	current = name
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		fail("threw: " .. tostring(err))
	end
end

-- Exact equality with a readable message. Numbers compare with a tolerance so
-- values that pass through float arithmetic still match the source data.
function Harness.eq(actual: any, expected: any, label: string?, tol: number?)
	local l = label or ""
	if type(actual) == "number" and type(expected) == "number" then
		if math.abs(actual - expected) > (tol or 1e-9) then
			error(string.format("%s expected %s, got %s", l, tostring(expected), tostring(actual)), 0)
		end
		return
	end
	if actual ~= expected then
		error(string.format("%s expected %s, got %s", l, tostring(expected), tostring(actual)), 0)
	end
end

function Harness.truthy(v: any, label: string?)
	if not v then
		error(string.format("%s expected truthy, got %s", label or "", tostring(v)), 0)
	end
end

function Harness.throws(fn: () -> (), label: string?)
	local ok = pcall(fn)
	if ok then
		error(string.format("%s expected an error, none thrown", label or ""), 0)
	end
end

function Harness.finish(): number
	if failed > 0 then
		print(string.format("FAIL  %d passed, %d failed", passed, failed))
		for _, f in failures do
			print(f)
		end
		return 1
	end
	print(string.format("ok    %d passed", passed))
	return 0
end

return Harness
