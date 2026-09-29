local website = 'https://games.roproxy.com/v1/'

local refreshTime = 60
local gameID = 5897843522 -- game.gameID

local HttpServices = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local LikesMemory = MemoryStoreService:GetHashMap("LikesMemory")

local function updateInfo()
	pcall(function()
		--// Likes \\--
		local response = HttpServices:GetAsync(website.."games/"..gameID.."/votes")
		local result = HttpServices:JSONDecode(response)

		if result then
			local Value = result.upVotes
			game.ReplicatedStorage.Likes.Value = Value
		else
			warn("SERVER | ERROR | GAME LIKES RETRIEVAL FAILED")
		end

		--// Info \\--
		local response = HttpServices:GetAsync(website.."games?universeIds="..gameID)
		local result = HttpServices:JSONDecode(response)

		if result then
			result = result.data[1]
			local currentlyPlaying = result.playing
			local Favorites = result.favoritedCount
			local Visits = result.visits

			print("Currently Playing: " .. currentlyPlaying)
			print("Currently Favorites: " .. Favorites)
			print("Currently Visits: " .. Visits)

			game.ReplicatedStorage.Favorites.Value = Favorites
			game.ReplicatedStorage.Visits.Value = Visits
			game.ReplicatedStorage.CurrentPlaying.Value = currentlyPlaying
		else
			warn("SERVER | ERROR | GAME INFO RETRIEVAL FAILED")
		end
	end)
end

while true do
	task.wait(5)
	updateInfo()
	task.wait(refreshTime)
end