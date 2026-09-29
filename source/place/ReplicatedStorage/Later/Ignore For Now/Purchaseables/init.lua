local purchaseableInfo = require(script.Info)

local Purchaseables = {
	Names = {
		Gamepasses = {};
		Products = {};
	};
	IDs = {
		Gamepasses = {};
		Products = {};
	};
	Effects = {
		Gamepasses = {};
		Products = {};
	};
}

--// Auto Conversion for Purchaseable Names & IDs \\--
for gamepassID , info in purchaseableInfo do
	Purchaseables.Names[info.productType or "Products"][gamepassID] = info.Name
	Purchaseables.IDs[info.productType or "Products"][info.Name] = gamepassID
	Purchaseables.Effects[info.productType or "Products"][info.Name] = info.Effect
end

function Purchaseables.gamepassName(ID : number)
	return Purchaseables.Names.Gamepasses[ID]
end

function Purchaseables.gamepassID(Name : string)
	return Purchaseables.IDs.Gamepasses[Name]
end

function Purchaseables.productName(ID : number)
	return Purchaseables.Names.Products[ID]
end

function Purchaseables.productID(Name : string)
	return Purchaseables.IDs.Products[Name]
end

return Purchaseables
