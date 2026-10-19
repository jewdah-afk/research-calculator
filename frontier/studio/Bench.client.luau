-- Frontier benchmark: measures the numbers the research docs list as never measured.
-- Put this LocalScript in StarterPlayerScripts with NativeProbe and PlainProbe as children (ModuleScripts),
-- press Play (or run on a phone through a published test place), and read the on-screen report.
-- Everything is wrapped in pcall, so a missing permission or API shows up as a line in the report.
--
-- Measures:
--   1. WritePixelsBuffer / ReadPixelsBuffer cost by size
--   2. Whether native codegen runs on this client
--   3. The real editable memory budget (creates 256² images until the engine says no)
--   4. EditableMesh build cost, per-frame vertex update cost, CreateMeshPartAsync cost
--   5. Whether bones on an EditableMesh produce Bone instances that animate (look at the screen)

local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local lines = {}
local label: TextLabel

local function report(fmt: string, ...)
	local s = string.format(fmt, ...)
	print("[Bench] " .. s)
	table.insert(lines, s)
	if label then
		label.Text = table.concat(lines, "\n")
	end
end

local function ms(f: () -> (), iters: number): number
	f()
	local t0 = os.clock()
	for _ = 1, iters do
		f()
	end
	return (os.clock() - t0) * 1000 / iters
end

local function setupGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FrontierBench"
	gui.ResetOnSpawn = false
	label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.6, 1)
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextSize = 14
	label.Font = Enum.Font.Code
	label.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function benchPixels()
	report("== 1. Pixel upload ==")
	for _, size in { 64, 128, 256, 512, 1024 } do
		local ok, err = pcall(function()
			local img = AssetService:CreateEditableImage({ Size = Vector2.new(size, size) })
			if img == nil then
				report("%d²: CreateEditableImage returned nil (budget)", size)
				return
			end
			local buf = buffer.create(size * size * 4)
			local v2, sz = Vector2.zero, Vector2.new(size, size)
			local w = ms(function()
				img:WritePixelsBuffer(v2, sz, buf)
			end, if size >= 512 then 10 else 50)
			local r = ms(function()
				img:ReadPixelsBuffer(v2, sz)
			end, if size >= 512 then 10 else 50)
			report("%4d²: write %.3f ms (%.0f MB/s)  read %.3f ms", size, w, size * size * 4 / (w / 1000) / 1e6, r)
			img:Destroy()
		end)
		if not ok then
			report("%d²: ERROR %s", size, tostring(err))
		end
	end
end

local function benchNative()
	report("== 2. Native codegen on this client ==")
	local ok, err = pcall(function()
		local native = require(script:WaitForChild("NativeProbe"))
		local plain = require(script:WaitForChild("PlainProbe"))
		local n = 256 * 256
		local buf = buffer.create(n * 4)
		local tn = ms(function()
			native(buf, n)
		end, 20)
		local tp = ms(function()
			plain(buf, n)
		end, 20)
		report("65k-pixel loop: native %.3f ms, plain %.3f ms, speed-up %.2fx -> %s", tn, tp, tp / tn,
			if tp / tn > 1.5 then "NATIVE ON" else "native OFF (or no gain)")
	end)
	if not ok then
		report("ERROR %s", tostring(err))
	end
end

local function benchBudget()
	report("== 3. Editable memory budget ==")
	local imgs = {}
	local ok, err = pcall(function()
		for i = 1, 400 do
			local img = AssetService:CreateEditableImage({ Size = Vector2.new(256, 256) })
			if img == nil then
				break
			end
			imgs[i] = img
		end
	end)
	report("created %d × 256² before nil = %.1f MB of pixels%s", #imgs, #imgs * 256 * 256 * 4 / 1048576,
		if #imgs >= 400 then " (hit the probe cap; budget is larger)" else "")
	if not ok then
		report("stopped by error: %s", tostring(err))
	end
	for _, img in imgs do
		img:Destroy()
	end
	task.wait(0.5)
	local again = AssetService:CreateEditableImage({ Size = Vector2.new(256, 256) })
	report("after destroying all: new image %s", if again then "OK (budget returned)" else "NIL (budget leaked)")
	if again then
		again:Destroy()
	end
end

local function gridMesh(mesh: EditableMesh, n: number): { number }
	local ids = table.create((n + 1) * (n + 1))
	for z = 0, n do
		for x = 0, n do
			ids[z * (n + 1) + x + 1] = mesh:AddVertex(Vector3.new(x - n / 2, 0, z - n / 2))
		end
	end
	for z = 0, n - 1 do
		for x = 0, n - 1 do
			local a = ids[z * (n + 1) + x + 1]
			local b = ids[z * (n + 1) + x + 2]
			local c = ids[(z + 1) * (n + 1) + x + 1]
			local d = ids[(z + 1) * (n + 1) + x + 2]
			mesh:AddTriangle(a, c, b)
			mesh:AddTriangle(b, c, d)
		end
	end
	return ids
end

local function benchMesh()
	report("== 4. EditableMesh ==")
	for _, n in { 22, 50, 99 } do -- 968, 5000, 19602 triangles
		local ok, err = pcall(function()
			local mesh = AssetService:CreateEditableMesh()
			if mesh == nil then
				report("CreateEditableMesh returned nil (budget)")
				return
			end
			local t0 = os.clock()
			local ids = gridMesh(mesh, n)
			local build = (os.clock() - t0) * 1000
			local tris = n * n * 2
			local t1 = os.clock()
			local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh), { CollisionFidelity = Enum.CollisionFidelity.Box })
			local mpa = (os.clock() - t1) * 1000
			part.Anchored = true
			part.Position = Vector3.new(0, 20, 0)
			part.Parent = workspace
			local frameCost = 0
			local frames = 30
			for f = 1, frames do
				local tf = os.clock()
				for i, id in ids do
					local x = (i - 1) % (n + 1)
					mesh:SetPosition(id, Vector3.new(x - n / 2, math.sin(x * 0.3 + f * 0.2), (i - 1) // (n + 1) - n / 2))
				end
				frameCost += os.clock() - tf
				RunService.RenderStepped:Wait()
			end
			report("%5d tris: build %.1f ms, CreateMeshPartAsync %.1f ms, move all %d verts %.2f ms/frame",
				tris, build, mpa, #ids, frameCost * 1000 / frames)
			part:Destroy()
			mesh:Destroy()
		end)
		if not ok then
			report("n=%d ERROR %s", n, tostring(err))
		end
	end
end

local function benchBones()
	report("== 5. Bones (watch the strip above spawn) ==")
	local ok, err = pcall(function()
		local mesh = AssetService:CreateEditableMesh()
		local root = mesh:AddBone({ Name = "Root", CFrame = CFrame.new(0, 0, 0) })
		local tip = mesh:AddBone({ Name = "Tip", ParentId = root, CFrame = CFrame.new(0, 10, 0) })
		local ids = {}
		for i = 0, 20 do
			local y = i * 0.5
			local a = mesh:AddVertex(Vector3.new(-0.5, y, 0))
			local b = mesh:AddVertex(Vector3.new(0.5, y, 0))
			local wTip = i / 20
			for _, v in { a, b } do
				mesh:SetVertexBones(v, { root, tip })
				mesh:SetVertexBoneWeights(v, { 1 - wTip, wTip })
			end
			table.insert(ids, a)
			table.insert(ids, b)
		end
		for i = 0, 19 do
			local a, b, c, d = ids[i * 2 + 1], ids[i * 2 + 2], ids[i * 2 + 3], ids[i * 2 + 4]
			mesh:AddTriangle(a, b, c)
			mesh:AddTriangle(b, d, c)
			mesh:AddTriangle(c, b, a) -- back faces so it's visible from both sides
			mesh:AddTriangle(c, d, b)
		end
		local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
		part.Anchored = true
		part.Position = Vector3.new(0, 8, -10)
		part.Parent = workspace
		local bones = {}
		for _, d in part:GetDescendants() do
			if d:IsA("Bone") then
				table.insert(bones, d)
			end
		end
		report("Bone instances under the MeshPart: %d %s", #bones,
			if #bones > 0 then "(animating Bone.Transform for 6 s: strip should sway)" else "(no Bone instances)")
		local t0 = os.clock()
		while os.clock() - t0 < 6 do
			local t = os.clock() - t0
			for _, b in bones do
				if b.Name == "Tip" then
					b.Transform = CFrame.Angles(0, 0, math.sin(t * 3) * 0.8)
				end
			end
			RunService.RenderStepped:Wait()
		end
		-- Second path: move the bind pose itself (does the mesh follow live?)
		report("now animating SetBoneCFrame on the EditableMesh for 4 s")
		t0 = os.clock()
		while os.clock() - t0 < 4 do
			local t = os.clock() - t0
			mesh:SetBoneCFrame(tip, CFrame.new(math.sin(t * 3) * 3, 10, 0))
			RunService.RenderStepped:Wait()
		end
		report("bones done: note whether the strip moved in each phase")
	end)
	if not ok then
		report("ERROR %s", tostring(err))
	end
end

setupGui()
report("Frontier bench, %s", if RunService:IsStudio() then "Studio" else "live client")
task.wait(2)
benchPixels()
benchNative()
benchBudget()
benchMesh()
benchBones()
report("== done ==")
