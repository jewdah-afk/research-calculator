-- This Library is utilized for easier rich text formats
local RichText = {}
RichText.__index = RichText
RichText.__call = function(Table , Msg : string)
	local Text = setmetatable({}, RichText)
	Text.Msg = Msg
	Text.OriginalMsg = Msg
	
	
	--[ FORMATTING FUNCTIONS ]--
	function Text:Color(color : Color3) -- Conversion from Decimal
		local newR = colorConvert(color.R)
		local newG = colorConvert(color.G)
		local newB = colorConvert(color.B)

		return string.format("%s,%s,%s",newR,newG,newB)
	end
	
	function Text:Colored(color : Color3) -- Converts the text to a colored text
		self.Msg = `<font color="rgb({self:Color(color)})">{self.Msg}</font>`
	end
	
	function Text:Bold() -- Converts the entire text to bold
		self.Msg = `<b>{self.Msg}</b>`
	end
	
	function Text:StrikeThrough(msg : string) -- Strikes a line through the text
		self.Msg = `<s>{msg}</s>`
	end
	
	function Text:Uppercase()
		self.Msg = `<uc>{self.Msg}</uc>`
	end
	
	function Text:SmallCaps()
		self.Msg = `<sc>{self.Msg}</sc>`
	end
	
	function Text:Transparency(Transparency : number)
		self.Msg = `<font transparency='{Transparency}'>{self.Msg}</font>`
	end
	
	function Text:Stroke(StrokeColor : string, JoinType : string, Thickness : string, Transparency : string) -- Puts a stroke on the text
		--[ Reconcile ]--
		StrokeColor = StrokeColor or "#000000"
		JoinType = JoinType or "round"
		Thickness = Thickness or "3"
		Transparency = Transparency or "0"
		
		self.Msg = `<stroke color='{StrokeColor}' joins='{JoinType}' thickness='{Thickness}' transparency='{Transparency}'>{self.Msg}</stroke>`
	end
	
	
	--[ GENERAL FUNCTIONS ]--
	function Text:ClearFormat() -- Removes all of the RichText formatting from text
		Text.Msg = Text.OriginalMsg
	end
	
	function Text:Return() -- Returns the Msg variable from the metatable
		return Text.Msg
	end
	
	
	return Text
end

function colorConvert(val)
	return math.floor(val * 255)
end

return setmetatable({}, RichText)
