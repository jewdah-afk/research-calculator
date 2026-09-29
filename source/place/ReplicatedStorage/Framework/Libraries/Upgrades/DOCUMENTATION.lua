--[[ Read when confused

--// Tags | Tags are not placed in every upgrade unless they need to be for balance purposes \\--
Exponential = number; | Will make effects exponentially scaled | Compatible with Log
Log = number; | Will make effects logged by the specific base you put down | Compatible with Exponential
Price_Jump = {Interval, Scale} | Every x interval levels, Price will jump by Scale
Reverse = true/false; | Setting this to true will make the effect downscale | Used primarily for cooldown upgrades

--// Bonuses \\--
EX) When you want a x2 bonus to the Effect every 25 levels
Effect_Bonus = number;
Bonus_Needed = number;

--// Examples \\--

--[              Exponential Upgrades              ]--
Base_Effect = 1; 
Effect_Scale = 0;
Reverse = false;
Effect_Bonus = 0;
Bonus_Needed = 0;
Exponential = 1.45; -- Makes upgrade do 1.45 ^ Level



--[              Logarithmic Upgrades              ]--
Base_Effect = 1; 
Effect_Scale = 0.1;
Reverse = false;
Effect_Bonus = 0;
Bonus_Needed = 0;
Log = 2; -- Logs the effect before effect bonus



--[              Exponential + Logarithmic Upgrades              ]--
Base_Effect = 1; 
Effect_Scale = 0.1;
Reverse = false;
Effect_Bonus = 0;
Bonus_Needed = 0;
Exponential = 1.45;
Log = 2; -- Same rule applies as in "Logarithmic Upgrades"



--[              Normal Additive Upgrades              ]--
Base_Effect = 1; 
Effect_Scale = 0.1;
Reverse = false;
Effect_Bonus = 0;
Bonus_Needed = 0;



--[              Cooldown Upgrades              ]--
Base_Effect = 1; 
Effect_Scale = 0.1;
Reverse = true; -- Subtracts from base instead of adds
Effect_Bonus = 0; 
Bonus_Needed = 0;



--[              Milestone Upgrades              ]--
Base_Effect = 1; 
Effect_Scale = 0.1;
Reverse = false;
Effect_Bonus = 2; -- x2 Effect per 10 Levels Reached
Bonus_Needed = 10; -- How many levels per Milestone reached

]]