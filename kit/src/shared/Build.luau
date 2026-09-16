--!nonstrict
--[[
	Build — every visual in this kit is generated here, in code.

	No toolbox models, no uploaded meshes, no asset ids to break. That means you
	can clone the repo, `rojo serve`, hit F5 and be playing in under a minute,
	and it means your art pass is a rewrite of one file rather than an
	archaeology dig through a place file. (The same choice `adit-rah/ttt` makes.)
]]

local Build = {}

function Build.part(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	part.Size = Vector3.new(4, 1, 4)

	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			part[key] = value
		end
	end
	if props and props.Parent then
		part.Parent = props.Parent
	end
	return part
end

function Build.wedge(props)
	local wedge = Instance.new("WedgePart")
	wedge.Anchored = true
	wedge.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			wedge[key] = value
		end
	end
	if props and props.Parent then
		wedge.Parent = props.Parent
	end
	return wedge
end

function Build.billboard(adornee, text, offsetY, size)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(size or 8, (size or 8) * 0.35)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY or 3, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 220
	gui.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.35
	label.Text = text or ""
	label.Parent = gui

	return gui, label
end

-- Deterministic per-id variation so "Fox Cub" always looks like a Fox Cub.
local function seedFor(id)
	local seed = 0
	for index = 1, #id do
		seed = (seed * 31 + string.byte(id, index)) % 2147483647
	end
	return seed
end

--[[
	A small creature built from primitives. Swap this one function for your
	imported models when you do the art pass; nothing else in the codebase
	knows what a pet looks like.
]]
function Build.petModel(petDef, tier)
	tier = tier or 0
	local rng = Random.new(seedFor(petDef.id))
	local model = Instance.new("Model")
	model.Name = petDef.id

	local baseColor = petDef.color or Color3.fromRGB(220, 220, 220)
	if tier > 0 then
		baseColor = baseColor:Lerp(Color3.fromRGB(255, 220, 130), math.min(tier * 0.22, 0.8))
	end

	local body = Build.part({
		Name = "Body",
		Size = Vector3.new(1.6, 1.4, 2.2),
		Color = baseColor,
		Material = tier >= 2 and Enum.Material.Neon or Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = model,
	})
	model.PrimaryPart = body

	local head = Build.part({
		Name = "Head",
		Size = Vector3.new(1.2, 1.1, 1.1),
		Color = baseColor:Lerp(Color3.new(1, 1, 1), 0.15),
		Material = body.Material,
		CanCollide = false,
		CFrame = body.CFrame * CFrame.new(0, 0.7, -1.2),
		Parent = model,
	})

	for side = -1, 1, 2 do
		Build.part({
			Name = "Eye",
			Size = Vector3.new(0.22, 0.22, 0.12),
			Color = Color3.fromRGB(22, 22, 28),
			CanCollide = false,
			CFrame = head.CFrame * CFrame.new(side * 0.3, 0.12, -0.56),
			Parent = model,
		})

		-- ears, horns or wings depending on the id hash
		local flavour = rng:NextInteger(1, 3)
		local size = flavour == 1 and Vector3.new(0.3, 0.7, 0.2)
			or flavour == 2 and Vector3.new(0.25, 0.5, 0.25)
			or Vector3.new(0.15, 0.9, 1.1)
		local offset = flavour == 3
			and CFrame.new(side * 1.0, 0.3, 0.2) * CFrame.Angles(0, 0, side * 0.5)
			or CFrame.new(side * 0.35, 0.75, 0)
		Build.part({
			Name = flavour == 3 and "Wing" or "Ear",
			Size = size,
			Color = baseColor:Lerp(Color3.new(0, 0, 0), 0.15),
			CanCollide = false,
			CFrame = (flavour == 3 and body.CFrame or head.CFrame) * offset,
			Parent = model,
		})

		for front = -1, 1, 2 do
			Build.part({
				Name = "Leg",
				Size = Vector3.new(0.35, 0.7, 0.35),
				Color = baseColor:Lerp(Color3.new(0, 0, 0), 0.25),
				CanCollide = false,
				CFrame = body.CFrame * CFrame.new(side * 0.55, -0.9, front * 0.7),
				Parent = model,
			})
		end
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end

	if tier >= 1 then
		local glow = Instance.new("PointLight")
		glow.Color = baseColor
		glow.Range = 6 + tier * 2
		glow.Brightness = 0.6 + tier * 0.4
		glow.Parent = body
	end

	return model
end

-- A nest egg: a squat ellipsoid plus speckles, coloured by the biome.
function Build.eggModel(color, label)
	local model = Instance.new("Model")
	model.Name = "Egg"

	local shell = Build.part({
		Name = "Shell",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.6, 3.2, 2.6),
		Color = color,
		Material = Enum.Material.Marble,
		CanCollide = false,
		Parent = model,
	})
	model.PrimaryPart = shell

	local rng = Random.new(seedFor(label or "egg"))
	for _ = 1, 5 do
		Build.part({
			Name = "Speckle",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.5, 0.5, 0.5),
			Color = color:Lerp(Color3.new(0, 0, 0), 0.35),
			CanCollide = false,
			CFrame = shell.CFrame * CFrame.Angles(
				rng:NextNumber() * 6.28,
				rng:NextNumber() * 6.28,
				0
			) * CFrame.new(0, 0, 1.2),
			Parent = model,
		})
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanTouch = false
		end
	end

	return model
end

return Build
