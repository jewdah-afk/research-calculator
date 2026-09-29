return {
	--[ FEATURED] --
	[3345873146] = function(Player : Player)
		if Player.Stats.RuneBulkProduct.Value < 1000000 then return true end
		return "You have already maxed out the Rune Bulk Product!"
	end,
	
	[3345688812] = function(Player : Player)
		if Player.Stats.RuneBulkProduct.Value < 1000000 then return true end
		return "You have already maxed out the Rune Bulk Product!"
	end,
	
	[3345764905] = function(Player : Player)
		if Player.Stats.RuneLuckLevel.Value < 25 then return true end
		return "You have already maxed out the Rune Luck Product!"
	end,
	

	[3357869982] = function(Player : Player)
		if Player.Stats.AntimatterProduct.Value < 30 then return true end
		return "You have already maxed out the Antimatter Product!"
	end,
	

	[3357915813] = function(Player : Player)
		if Player.Stats.BoundlessProduct.Value < 30 then return true end
		return "You have already maxed out the Boundless Product!"
	end,
	

	[3360190882] = function(Player : Player)
		if Player.Stats.EtherbornProduct.Value < 5 then return true end
		return "You have already maxed out the Etherborn Product!"
	end,
	

	[3362614318] = function(Player : Player)
		if Player.Stats.AnkhProduct.Value < 8 then return true end
		return "You have already maxed out the Ankh Product!"
	end,
	
	[3365757590] = function(Player : Player)
		if Player.Stats.PrimordialProduct.Value < 4 then return true end
		return "You have already maxed out the Primordial Product!"
	end,
	
	[3365754337] = function(Player : Player)
		if Player.Stats.OmenProduct.Value < 4 then return true end
		return "You have already maxed out the Omen Product!"
	end,
	
	[3365757966] = function(Player : Player)
		if Player.Stats.EternalProduct.Value < 4 then return true end
		return "You have already maxed out the Eternal Product!"
	end,
	
	[3359401666] = function(Player : Player)
		if Player.Stats.SecretStatsLevel.Value < 10 then return true end
		return "You have already maxed out the Secret Stats Product!"
	end,
	

	[3348081399] = function(Player : Player)
		if Player.Stats.RuneSpeedLevel.Value < 50 then return true end
		return "You have already maxed out the Rune Speed Product!"
	end,
	
	[3350893660] = function(Player : Player)
		if Player.Stats.RuneBulkLevel.Value < 20 then return true end
		return "You have already maxed out the Rune Bulk Multiplier Product!"
	end,
	
	[2837094737] = function(Player : Player)
		if Player.Stats.Tier.Value < 4 then return true end
		return "You have already reached Tier 4. Starter Pack disabled for you."
	end,
	
	[3144442512] = function(Player : Player)
		if Player.Stats.Tier.Value < 4 then return true end
		return "You have already reached Tier 4. Starter Pack disabled for you."
	end,
	
	[2700373904] = function(Player : Player)
		if Player.Stats.RuneCloneProduct.Value < 9 then return true end
		return "You have already maxed out Rune Clone Products!"
	end,
	
	[3144471596] = function(Player : Player)
		if not Player.Stats.Runic_Bundle.Value then return true end
		return "You have already bought the Runic Bunlde. Its a one time purchase."
	end,
	
	
	[3226710712] = function(Player : Player)
		if not Player.Gamepasses.FasterSecretStats.Value then return true end
		return "You have already bought Faster Secret Stats!"
	end,
	
	[3226702193] = function(Player : Player)
		if Player.Gamepasses.X2Chromium.Value < 1 then return true end
		return "You have already bought x2 Chromium!"
	end,
	
}