--!nocheck
-- Replays data/dec/cases through the port's Decimal and reports differences by op (node dec_gen.js makes them).
local L = require("./lib")
local TN = L.TN
local JS = L.JSRT(TN, L.BEcore)
local cases = L.data("dec", "cases")
local ARGS = { ... }
local FROM, TO = tonumber(ARGS[1]) or 1, tonumber(ARGS[2]) or 1e9
local idx = 0
local function fromC(str)
	local s, l, m = string.match(str, "^([^,]+),([^,]+),([^,]+)$")
	local function num(x) if x == "Infinity" then return math.huge elseif x == "-Infinity" then return -math.huge elseif x == "NaN" then return 0/0 end return tonumber(x) end
	s, l, m = num(s), num(l), num(m)
	-- break_eternity components -> TowerNum value
	local v
	if l ~= l or m ~= m then return JS.fromTri({ s = s, l = l, m = m }) end                -- the NaN kinds
	if l == math.huge then local d = JS.D(s * math.huge); d.be = { s = s, l = math.huge, m = math.huge }; return d end   -- Decimal.dInf
	if l == 1 and m == math.huge then return JS.D(s * math.huge) end                 -- new Decimal(Infinity)
	if s == 0 then v = 0
	elseif l == 0 then v = s * m
	else
		v = math.abs(m)
		for _ = 1, l - 1 do v = TN.exp10(v) end
		if m < 0 then v = TN.neg(v) end
		v = TN.exp10(v)
		if s < 0 then v = TN.neg(v) end
	end
	return JS.D(v)
end
local TOL = 1e-9
local function close(x, y)
	if x == y then return true end
	if x ~= x and y ~= y then return true end
	return math.abs(x - y) <= TOL * math.max(1, math.abs(x), math.abs(y))
end
local bad, tot, byop, ex = 0, 0, {}, {}
for line in string.gmatch(cases, "[^\n]+") do
	idx += 1
	if idx < FROM or idx > TO then continue end
	local op, as, bs, exp = string.match(line, "^([^|]+)|([^|]+)|([^|]+)|(.+)$")
	local a, b = fromC(as), fromC(bs)
	local ok, res = pcall(function()
		if op == "tetrate" or op == "pow" or op == "root" or op == "log" or op == "add" or op == "sub" or op == "mul" or op == "div" or op == "max" or op == "min" or op == "gte" or op == "gt" or op == "lte" or op == "lt" or op == "eq" or op == "cmp" then return a[op](a, b) end
		return a[op](a)
	end)
	local got
	if not ok then got = "ERR"
	elseif JS.isD(res) and res.be then got = "D" .. JS.numToString(res.be.s) .. "," .. JS.numToString(res.be.l) .. "," .. JS.numToString(res.be.m)
	elseif JS.isD(res) then local s, l, m = JS.comps(res.v); got = "D" .. JS.numToString(s) .. "," .. JS.numToString(l) .. "," .. JS.numToString(m)
	elseif type(res) == "number" then got = "N" .. JS.numToString(res)
	else got = "B" .. tostring(res) end
	tot += 1
	local same = got == exp
	if not same and string.sub(got, 1, 1) == string.sub(exp, 1, 1) then
		local k = string.sub(got, 1, 1)
		if k == "D" then
			local s1, l1, m1 = string.match(string.sub(got, 2), "^([^,]+),([^,]+),([^,]+)$")
			local s2, l2, m2 = string.match(string.sub(exp, 2), "^([^,]+),([^,]+),([^,]+)$")
			s1, l1, m1, s2, l2, m2 = tonumber(s1), tonumber(l1), tonumber(m1), tonumber(s2), tonumber(l2), tonumber(m2)
			if s1 == 0 and s2 == 0 then same = true
			elseif (s1 ~= s1 or m1 ~= m1) and (s2 ~= s2 or m2 ~= m2) then same = (l1 ~= l1) == (l2 ~= l2) and (s1 ~= s1) == (s2 ~= s2)   -- both NaN, same kind
			elseif s1 == s2 and l1 == l2 then same = close(m1, m2)
			elseif s1 == s2 and math.abs(l1 - l2) == 1 then
				if l1 < l2 then m1 = math.log10(m1) else m2 = math.log10(m2) end
				same = close(m1, m2)
			end
		elseif k == "N" then same = close(tonumber(string.sub(got, 2)), tonumber(string.sub(exp, 2)))
		end
	end
	if not same then
		bad += 1
		byop[op] = (byop[op] or 0) + 1
		ex[op] = ex[op] or {}
		if #ex[op] < 4 then table.insert(ex[op], as .. " " .. op .. " " .. bs .. "  js=" .. exp .. "  lua=" .. got) end
	end
end
print(string.format("%d cases, %d differ", tot, bad))
for op, n in byop do print(op, n); for _, e in ex[op] do print("    " .. e) end end
