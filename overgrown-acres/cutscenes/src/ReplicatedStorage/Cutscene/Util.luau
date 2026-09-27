local Util = {}

function Util.easeInOut(t: number): number
	if t < 0.5 then
		return 4 * t * t * t
	end
	return 1 - ((-2 * t + 2) ^ 3) / 2
end

-- Waits for `duration` seconds, returning early if `shouldStop` returns true.
function Util.wait(duration: number, shouldStop: (() -> boolean)?)
	local elapsed = 0
	while elapsed < duration do
		if shouldStop and shouldStop() then
			return
		end
		elapsed += task.wait()
	end
end

-- Creates an instance with properties and children in one call.
function Util.make(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props or {} do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

return Util
