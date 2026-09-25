--!nocheck
-- Html.rich on every HTML string the game showed in the view dumps (data/html/cases, from tools/html_cases.py):
-- the RichText must be well-formed.
local Html = require("../../src/shared/Html")
local cases = require("../data/html/cases")
local RT = { b = true, i = true, u = true, s = true, font = true, stroke = true, uppercase = true, smallcaps = true, mark = true }
local bad, total, t0 = 0, 0, os.clock()
local function check(r)
	local stack = {}
	for closing, tag in string.gmatch(r, "<(/?)(%a+)[^>]*>") do
		if not RT[tag] then return "unknown tag " .. tag end
		if closing == "/" then
			if stack[#stack] ~= tag then return "bad nesting: </" .. tag .. "> vs " .. tostring(stack[#stack]) end
			table.remove(stack)
		else table.insert(stack, tag) end
	end
	if #stack > 0 then return "unclosed " .. stack[#stack] end
	local stripped = string.gsub(r, "<[^>]*>", "")
	if string.find(stripped, "[<>]") then return "raw < or > in text" end
	if string.find(stripped, "&[^%a#]") then return "raw & in text" end
	return nil
end
for i, h in cases do
	for _, part in Html.split(h) do
		if type(part) == "string" then
			total += 1
			local r = Html.rich(part, 14, i % 2 == 0)
			local e = check(r)
			if e then bad += 1; if bad < 8 then print("BAD", e, "\n  in: " .. string.sub(part, 1, 200) .. "\n  out: " .. string.sub(r, 1, 300)) end end
		end
	end
end
print(string.format("%d strings, %d bad, %.1f ms", total, bad, (os.clock() - t0) * 1000))
for _, i in { 1, 5, 40, 120, 300 } do if cases[i] then print("----\n" .. string.sub(cases[i], 1, 250) .. "\n=>\n" .. string.sub(Html.rich(cases[i], 14), 1, 350)) end end
