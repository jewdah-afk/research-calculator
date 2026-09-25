--!nocheck
-- transpiled from tree.js by port/build.js: do not edit
return function()
-- transpiled from tree.js
layoutInfo = JS.O({
	startTab = "m",
	startNavTab = "tree-tab",
	showTree = true,
	treeLayout = ""
}, {"startTab", "startNavTab", "showTree", "treeLayout"})
addLayer(nil, "tree-tab", JS.O({
	tabFormat = JS.A(1, JS.A(2, "tree", function(this)
	do return (if JS.t(layoutInfo.treeLayout) then layoutInfo.treeLayout else TREE_LAYERS) end
end)),
	previousTab = "",
	leftTab = true
}, {"tabFormat", "previousTab", "leftTab"}))

end
