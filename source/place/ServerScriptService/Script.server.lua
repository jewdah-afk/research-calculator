--local DataStoreService = game:GetService("DataStoreService")

--local DATASTORE_NAME = "Studio_103" -- or "Test_101"
--local dataStore = DataStoreService:GetDataStore(DATASTORE_NAME)

---- Get target rollback time (1 hour ago in UTC)
--local nowUnix = os.time(os.date("!*t"))
--local rollbackUnix = nowUnix - 3600 -- 1 hour ago
--local rollbackTime = DateTime.fromUnixTimestamp(rollbackUnix)

--print("Rolling back to approx:", rollbackTime)

---- List all keys
--local allKeys = {}
--local listSuccess, keyPages = pcall(function()
--	return dataStore:ListKeysAsync()
--end)

--if not listSuccess then
--	warn("Failed to list keys")
--	return
--end

--local allKeys = {}

--while true do
--	local page = keyPages:GetCurrentPage()
--	for _, keyEntry in page do
--		table.insert(allKeys, keyEntry.KeyName)
--	end

--	if keyPages.IsFinished then
--		break
--	end

--	local success, err = pcall(function()
--		keyPages:AdvanceToNextPageAsync()
--	end)
--	if not success then
--		warn("Failed to advance page:", err)
--		break
--	end

--	task.wait() -- prevent script timeout
--end

--local restored = 0
--for _, key in ipairs(allKeys) do
--	local versionSuccess, versionPages = pcall(function()
--		return dataStore:ListVersionsAsync(key, Enum.SortDirection.Descending, nil, rollbackTime.UnixTimestampMillis)
--	end)

--	if versionSuccess then
--		local versions = versionPages:GetCurrentPage()
--		if #versions > 0 then
--			local version = versions[1]

--			local getSuccess, value, info = pcall(function()
--				return dataStore:GetVersionAsync(key, version.Version)
--			end)

--			if getSuccess and value then
--				print("Rolling back", key, "to version at", DateTime.fromUnixTimestampMillis(version.CreatedTime))

--				local setOptions = Instance.new("DataStoreSetOptions")
--				setOptions:SetMetadata(info:GetMetadata())

--				dataStore:SetAsync(key, value, nil, setOptions)
--			end
--		end
--	end
--end

--print(`✅ Rollback complete. Restored {restored}/{#allKeys} keys.`)
