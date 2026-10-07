-- Pull every .luau from the local server (python -m http.server 8778 in rc-main/roblox) into the open Peckwood place.
local Http = game:GetService("HttpService")
local BASE = "http://127.0.0.1:8778/"
local was = Http.HttpEnabled
Http.HttpEnabled = true
local n, err = 0, nil
local ok, e = pcall(function()
	local m = Http:JSONDecode(Http:GetAsync(BASE .. "tools/manifest.json?" .. os.clock()))
	for _, it in m do
		local cur = game:GetService(it.path[1])
		for i = 2, #it.path do
			local nxt = cur:FindFirstChild(it.path[i])
			if i == #it.path and nxt and nxt.ClassName ~= it.class then nxt:Destroy(); nxt = nil end
			if not nxt then nxt = Instance.new(if i == #it.path then it.class else "Folder"); nxt.Name = it.path[i]; nxt.Parent = cur end
			cur = nxt
		end
		local src = Http:GetAsync(BASE .. it.url .. "?" .. os.clock())
		if cur.Source ~= src then cur.Source = src; n += 1 end
	end
end)
Http.HttpEnabled = was
return if ok then ("synced " .. n) else tostring(e)
