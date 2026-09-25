--!nocheck
-- transpiled from utils/options.js by port/build.js: do not edit
return function()
-- transpiled from utils/options.js
getStartOptions = function(this)
	do return JS.O({
		autosave = true,
		msDisplay = "always",
		theme = "default",
		themeName = "Default",
		hqTree = false,
		offlineProd = true,
		hideChallenges = false,
		showStory = true,
		forceOneTab = true,
		oldStyle = false,
		tooltipForcing = true,
		reverseMilestones = true,
		changeCorruptTooltipPlace = "right",
		menuShown = true
	}, {"autosave", "msDisplay", "theme", "themeName", "hqTree", "offlineProd", "hideChallenges", "showStory", "forceOneTab", "oldStyle", "tooltipForcing", "reverseMilestones", "changeCorruptTooltipPlace", "menuShown"}) end
end
toggleOpt = function(this, name)
	if ((name == "oldStyle") and (JS.tonum(styleCooldown) > 0)) then
		do return end
	end
	JS.set(options, JS.k(name), (not JS.t(options[JS.k(name)])))
	if (name == "hqTree") then
		changeTreeQuality(nil)
	end
	if (name == "oldStyle") then
		updateStyle(nil)
	end
end
updateStyle = function(this)
	styleCooldown = 1
	local css = document.getElementById("styleStuff")
	JS.setk(css, "href", (if JS.t(options.oldStyle) then "oldStyle.css" else "style.css"))
	needCanvasUpdate = true
end
changeTreeQuality = function(this)
	local on
	on = options.hqTree
	document.body.style:setProperty("--hqProperty1", (if JS.t(on) then "2px solid" else "4px solid"))
	document.body.style:setProperty("--hqProperty2a", (if JS.t(on) then "-4px -4px 4px rgba(0, 0, 0, 0.25) inset" else "-4px -4px 4px rgba(0, 0, 0, 0) inset"))
	document.body.style:setProperty("--hqProperty2b", (if JS.t(on) then "0px 0px 20px var(--background)" else ""))
	document.body.style:setProperty("--hqProperty3", (if JS.t(on) then "2px 2px 4px rgba(0, 0, 0, 0.25)" else "none"))
end
toggleAuto = function(this, toggle)
	Vue.set(player[JS.k(toggle[0])], JS.A(1, toggle[1]), (not JS.t(player[JS.k(toggle[0])][JS.k(toggle[1])])))
	needCanvasUpdate = true
end
adjustMSDisp = function(this)
	JS.setk(options, "msDisplay", MS_SETTINGS[JS.k(math.fmod(JS.tonum(JS.add(JS.m(MS_SETTINGS, "indexOf", options.msDisplay), 1)), 5))])
end
adjustCCTP = function(this)
	JS.setk(options, "changeCorruptTooltipPlace", CCTP_SETTINGS[JS.k(math.fmod(JS.tonum(JS.add(JS.m(CCTP_SETTINGS, "indexOf", options.changeCorruptTooltipPlace), 1)), 4))])
end
milestoneShown = function(this, layer, id)
	complete = JS.m(player[JS.k(layer)].milestones, "includes", id)
	auto = layers[JS.k(layer)].milestones[JS.k(id)].toggles
	do
		local __sw1 = options.msDisplay
		local __ft2 = false
		repeat
			if __ft2 or JS.eq(__sw1, "always") then
				__ft2 = true
				do return true end
				break
			end
			if __ft2 or JS.eq(__sw1, "last") then
				__ft2 = true
				do return JS.or_((if JS.t(auto) then auto else (not JS.t(complete))), function() return JS.eq(player[JS.k(layer)].lastMilestone, id) end) end
				break
			end
			if __ft2 or JS.eq(__sw1, "automation") then
				__ft2 = true
				do return (if JS.t(auto) then auto else (not JS.t(complete))) end
				break
			end
			if __ft2 or JS.eq(__sw1, "incomplete") then
				__ft2 = true
				do return (not JS.t(complete)) end
				break
			end
			if __ft2 or JS.eq(__sw1, "never") then
				__ft2 = true
				do return false end
				break
			end
		until true
	end
	do return false end
end
options = JS.O({})
styleCooldown = 0
MS_DISPLAYS = JS.A(5, "ALL", "LAST, AUTO, INCOMPLETE", "AUTOMATION, INCOMPLETE", "INCOMPLETE", "NONE")
CCTP_DISPLAYS = JS.A(4, "AT RIGHT", "AT LEFT", "AT TOP", "AT BOTTOM")
CCTP_SETTINGS = JS.A(4, "right", "left", "top", "bottom")
MS_SETTINGS = JS.A(5, "always", "last", "automation", "incomplete", "never")

end
