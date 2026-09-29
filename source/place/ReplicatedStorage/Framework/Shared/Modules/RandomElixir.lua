local Elixirs = {"StatsElixir","RuneLuckElixir","RuneSpeedElixir"}

return function(Player : Player, Amount : number)
	local Reward = Elixirs[math.random(1, #Elixirs)]
	Player.Stats[Reward].Value += Amount or 1
end