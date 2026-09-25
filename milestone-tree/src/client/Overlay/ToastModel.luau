--!strict
--[[
	ToastModel: the pure bookkeeping behind the toasts (DESIGN.md 4.7): coalescing, the ×N count, the sub line of a
	merged toast (a count or a range, never joined names), expiry and the notification history (the last 20).
	No Roblox services: the unit tests run it under plain luau (port/tests/unit/overlay.luau).

	    local model = ToastModel.new()
	    local t, merged = model:push({ kind, title, sub, layer }, now)   -- kind: milestone | achievement | corruption |
	                                                                     -- other | notice
	    model:active(now)          the live toasts, newest first
	    model:history()            the last 20 (newest first); model:clear()
	    ToastModel.kindOf(pop)     the view's kind, else guessed from title / type
	    ToastModel.plain(html)     the popup message as plain text
]]

local ToastModel = {}

export type Item = { kind: string, title: string, sub: string, layer: string? }
export type Toast = {
	id: number,
	kind: string,
	title: string,
	sub: string,
	layer: string?,
	count: number,
	subs: { string },
	born: number, -- the last push (a merge restarts the life)
	life: number,
}
export type Model = {
	push: (self: Model, item: Item, now: number) -> (Toast, boolean),
	active: (self: Model, now: number) -> { Toast },
	history: (self: Model) -> { Toast },
	clear: (self: Model) -> (),
}

ToastModel.LIFE = 4
ToastModel.NOTICE_LIFE = 6
ToastModel.HISTORY = 20

function ToastModel.plain(s: string?): string
	if s == nil then return "" end
	local t = string.gsub(s, "<br%s*/?>", " ")
	t = string.gsub(t, "<[^>]*>", "")
	t = string.gsub(t, "&nbsp;", " ")
	t = string.gsub(t, "&lt;", "<")
	t = string.gsub(t, "&gt;", ">")
	t = string.gsub(t, "&amp;", "&")
	t = string.gsub(t, "%s+", " ")
	t = string.gsub(t, "^ ", "")
	t = string.gsub(t, " $", "")
	return t
end

function ToastModel.kindOf(p: { [string]: any }): string
	local k = p.kind
	if type(k) == "string" and k ~= "" and k ~= "other" then return k end
	local title = if type(p.title) == "string" then string.lower(p.title) else ""
	local ty = if type(p.type) == "string" then p.type else ""
	if ty == "milestone" or string.find(title, "milestone", 1, true) then return "milestone" end
	if ty == "achievement" or string.find(title, "achievement", 1, true) then return "achievement" end
	if string.find(title, "corruption", 1, true) then return "corruption" end
	if string.find(title, "challenge", 1, true) then return "challenge" end
	return if type(k) == "string" and k ~= "" then k else "other"
end

-- "18th Meta-Milestone" -> 18, "Meta-Milestone"; "Spark Milestone #2" -> 2, "Spark Milestone #"
local function ordinal(s: string): (number?, string?)
	local n, rest = string.match(s, "^(%d+)%a%a%s+(.+)$")
	if n and rest then return tonumber(n), "o|" .. rest end
	local head, m = string.match(s, "^(.-#)(%d+)$")
	if head and m then return tonumber(m), "h|" .. head end
	return nil, nil
end
local function suffix(n: number): string
	local t = n % 100
	if t >= 11 and t <= 13 then return "th" end
	local u = n % 10
	return if u == 1 then "st" elseif u == 2 then "nd" elseif u == 3 then "rd" else "th"
end

-- the sub line of a merged toast
function ToastModel.mergedSub(kind: string, subs: { string }): string
	local n = #subs
	if n <= 1 then return subs[1] or "" end
	local lo, hi, key = math.huge, -math.huge, nil :: string?
	local same = true
	for _, s in subs do
		local v, k = ordinal(s)
		if v == nil or k == nil then
			same = false
			break
		end
		if key == nil then
			key = k
		elseif key ~= k then
			same = false
			break
		end
		lo, hi = math.min(lo, v), math.max(hi, v)
	end
	if same and key then
		local kind2, rest = string.sub(key, 1, 1), string.sub(key, 3)
		if kind2 == "o" then
			return string.format("%d%s – %d%s %s", lo, suffix(lo), hi, suffix(hi), rest)
		end
		return string.format("%s%d – #%d", rest, lo, hi)
	end
	if kind == "achievement" then return string.format("%d achievements", n) end
	if kind == "milestone" then return string.format("%d milestones", n) end
	return string.format("%d updates", n)
end

function ToastModel.new(): Model
	local self = {} :: Model
	local live: { Toast } = {}
	local hist: { Toast } = {}
	local nextId = 0

	function self.push(_: Model, item: Item, now: number): (Toast, boolean)
		local life = if item.kind == "notice" then ToastModel.NOTICE_LIFE else ToastModel.LIFE
		for _, t in live do
			if t.kind == item.kind and t.title == item.title and now - t.born < t.life and item.kind ~= "notice" then
				t.count += 1
				table.insert(t.subs, item.sub)
				t.sub = ToastModel.mergedSub(t.kind, t.subs)
				t.born = now
				t.layer = item.layer or t.layer
				return t, true
			end
		end
		nextId += 1
		local t: Toast = {
			id = nextId, kind = item.kind, title = item.title, sub = item.sub, layer = item.layer, count = 1,
			subs = { item.sub }, born = now, life = life,
		}
		table.insert(live, 1, t)
		table.insert(hist, 1, t)
		while #hist > ToastModel.HISTORY do table.remove(hist) end
		return t, false
	end
	function self.active(_: Model, now: number): { Toast }
		local i = 1
		while i <= #live do
			local t = live[i]
			if now - t.born >= t.life then table.remove(live, i) else i += 1 end
		end
		return live
	end
	function self.history(_: Model): { Toast }
		return hist
	end
	function self.clear(_: Model)
		table.clear(hist)
	end
	return self
end

return ToastModel
