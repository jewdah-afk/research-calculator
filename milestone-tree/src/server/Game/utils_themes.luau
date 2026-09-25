--!nocheck
-- transpiled from utils/themes.js by port/build.js: do not edit
return function()
-- transpiled from utils/themes.js
changeTheme = function(this)
	colors_theme = colors[JS.k((if JS.t(options.theme) then options.theme else "default"))]
	document.body.style:setProperty("--background", colors_theme["background"])
	document.body.style:setProperty("--background_tooltip", colors_theme["background_tooltip"])
	document.body.style:setProperty("--color", colors_theme["color"])
	document.body.style:setProperty("--points", colors_theme["points"])
	document.body.style:setProperty("--locked", colors_theme["locked"])
end
getThemeName = function(this)
	do return (if JS.t(options.themeName) then options.themeName else "Default") end
end
switchTheme = function(this)
	local index = JS.m(themes, "indexOf", options.theme)
	if (((options.theme == JS.NULL) or (JS.tonum(index) >= (JS.len(themes) - 1))) or (JS.tonum(index) < 0)) then
		JS.setk(options, "theme", themes[0])
		JS.setk(options, "themeName", themeNames[0])
	else
		index = (JS.tonum(index) + 1)
		JS.setk(options, "theme", themes[JS.k(index)])
		JS.setk(options, "theme", themes[JS.k(index)])
		JS.setk(options, "themeName", themeNames[JS.k(index)])
		JS.setk(options, "themeName", themeNames[JS.k(index)])
	end
	changeTheme(nil)
	resizeCanvas(nil)
end
themes = JS.A(4, "default", "aqua", "nature", "steel")
themeNames = JS.A(4, "Default", "Aqua", "Nature", "Steel")
colors = JS.O({
	default = JS.O({
	[1] = "#ffffff",
	[2] = "#bfbfbf",
	[3] = "#7f7f7f",
	[4] = "#c25757",
	color = "#dfdfdf",
	points = "#ffffff",
	locked = "#bf8f8f",
	background = "#0f0f0f",
	background_tooltip = "rgba(0, 0, 0, 0.75)"
}, {"color", "points", "locked", "background", "background_tooltip"}),
	aqua = JS.O({
	[1] = "#bfdfff",
	[2] = "#8fa7bf",
	[3] = "#5f6f7f",
	color = "#bfdfff",
	points = "#dfefff",
	locked = "#c4a7b3",
	background = "#001f3f",
	background_tooltip = "rgba(0, 15, 31, 0.75)"
}, {"color", "points", "locked", "background", "background_tooltip"}),
	nature = JS.O({
	[1] = "#7A8579",
	[2] = "#8fa7bf",
	[3] = "#5f6f7f",
	color = "#7A8579",
	points = "#dfefff",
	locked = "#c4a7b3",
	background = "#142811",
	background_tooltip = "rgba(11,22,9,0.75)"
}, {"color", "points", "locked", "background", "background_tooltip"}),
	steel = JS.O({
	[1] = "#BCFD4C",
	[2] = "#8fa7bf",
	[3] = "#5f6f7f",
	color = "#BCFD4C",
	points = "#dfefff",
	locked = "#c4a7b3",
	background = "#191919",
	background_tooltip = "rgba(11,22,9,0.75)"
}, {"color", "points", "locked", "background", "background_tooltip"})
}, {"default", "aqua", "nature", "steel"})

end
