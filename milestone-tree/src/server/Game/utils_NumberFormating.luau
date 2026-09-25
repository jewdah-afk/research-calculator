--!nocheck
-- transpiled from utils/NumberFormating.js by port/build.js: do not edit
return function()
-- transpiled from utils/NumberFormating.js
addCommas = function(this, s)
	if (JS.len(s) <= 3) then
		do return s end
	end
	local rem = math.fmod(JS.len(s), 3)
	if JS.eq(rem, 0) then
		rem = 3
	end
	do return ((JS.str(JS.m(s, "slice", 0, rem)) .. ",") .. JS.str(addCommas(nil, JS.m(s, "slice", rem)))) end
end
exponentialFormat = function(this, num, precision, mantissa)
	if mantissa == nil then mantissa = true end
	local e = num:log10():floor()
	local m = num:div(Decimal.pow(10, e))
	if JS.eq(m:toStringWithDecimalPlaces(precision), 10) then
		m = decimalOne
		e = e:add(1)
	end
	e = (if e:gte(1000000000) then format(nil, e, 3) else (if e:gte(10000) then commaFormat(nil, e, 0) else e:toStringWithDecimalPlaces(0)))
	if JS.t(mantissa) then
		do return ((JS.str(m:toStringWithDecimalPlaces(precision)) .. "e") .. JS.str(e)) end
	else
		do return ("e" .. JS.str(e)) end
	end
end
commaFormat = function(this, num, precision)
	if ((num == JS.NULL) or (num == nil)) then
		do return "NaN" end
	end
	if (JS.tonum(JS.P(num, "mag")) < 0.001) then
		do return JS.m(0, "toFixed", precision) end
	end
	local init = num:toStringWithDecimalPlaces(precision)
	local portions = JS.m(init, "split", ".")
	JS.set(portions, 0, JS.m(portions[0], "replace", JS.re("(\\d)(?=(\\d\\d\\d)+(?!\\d))","g"), "$1,"))
	if JS.eq(JS.len(portions), 1) then
		do return portions[0] end
	end
	do return ((JS.str(portions[0]) .. ".") .. JS.str(portions[1])) end
end
regularFormat = function(this, num, precision)
	if ((num == JS.NULL) or (num == nil)) then
		do return "NaN" end
	end
	if (JS.tonum(JS.P(num, "mag")) < 0.0001) then
		do return JS.m(0, "toFixed", precision) end
	end
	if ((JS.tonum(JS.P(num, "mag")) < 0.1) and (not (precision == 0))) then
		precision = Math.max(precision, 4)
	end
	do return num:toStringWithDecimalPlaces(precision) end
end
fixValue = function(this, x, y)
	if y == nil then y = 0 end
	do return (if JS.t(x) then x else JS.D(y)) end
end
sumValues = function(this, x)
	x = Object.values(x)
	if (not JS.t(x[0])) then
		do return decimalZero end
	end
	do return JS.m(x, "reduce", function(_, a, b)
		do return Decimal.add(a, b) end
	end) end
end
format = function(this, decimal, precision, small)
	if precision == nil then precision = 2 end
	local slog
	small = (if JS.t(small) then small else modInfo.allowSmall)
	decimal = JS.D(decimal)
	if ((isNaN(nil, JS.P(decimal, "sign")) or isNaN(nil, JS.P(decimal, "layer"))) or isNaN(nil, JS.P(decimal, "mag"))) then
		JS.setk(player, "hasNaN", true)
		do return "NaN" end
	end
	if (JS.tonum(JS.P(decimal, "sign")) < 0) then
		do return ("-" .. JS.str(format(nil, decimal:neg(), precision, small))) end
	end
	if JS.eq(JS.P(decimal, "mag"), Number.POSITIVE_INFINITY) then
		do return "Infinity" end
	end
	if decimal:gte("eeee1000") then
		slog = decimal:slog()
		if slog:gte(1000000) then
			do return ("F" .. JS.str(format(nil, slog:floor()))) end
		else
			do return ((JS.str(Decimal.pow(10, slog:sub(slog:floor())):toStringWithDecimalPlaces(3)) .. "F") .. JS.str(commaFormat(nil, slog:floor(), 0))) end
		end
	elseif decimal:gte("1e1000000") then
		do return exponentialFormat(nil, decimal, 0, false) end
	elseif decimal:gte("1e10000") then
		do return exponentialFormat(nil, decimal, 0) end
	elseif decimal:gte(1000000000) then
		do return exponentialFormat(nil, decimal, precision) end
	elseif decimal:gte(1000) then
		do return commaFormat(nil, decimal, 0) end
	elseif (decimal:gte(0.0001) or (not JS.t(small))) then
		do return regularFormat(nil, decimal, precision) end
	elseif decimal:eq(0) then
		do return JS.m(0, "toFixed", precision) end
	end
	decimal = invertOOM(nil, decimal)
	local val = ""
	if decimal:lt("1e1000") then
		val = exponentialFormat(nil, decimal, precision)
		do return JS.m(val, "replace", JS.re("([^(?:e|F)]*)$",""), "-$1") end
	else
		do return (JS.str(format(nil, decimal, precision)) .. "⁻¹") end
	end
end
formatWhole = function(this, decimal)
	decimal = JS.D(decimal)
	if decimal:gte(1000000000) then
		do return format(nil, decimal, 2) end
	end
	if (decimal:lte(0.99) and (not decimal:eq(0))) then
		do return format(nil, decimal, 2) end
	end
	do return format(nil, decimal, 0) end
end
formatTime = function(this, s)
	if (JS.tonum(s) < 60) then
		do return (JS.str(format(nil, s)) .. "s") end
	elseif (JS.tonum(s) < 3600) then
		do return (((JS.str(formatWhole(nil, Math.floor((JS.tonum(s) / 60)))) .. "m ") .. JS.str(format(nil, math.fmod(JS.tonum(s), 60)))) .. "s") end
	elseif (JS.tonum(s) < 86400) then
		do return (((((JS.str(formatWhole(nil, Math.floor((JS.tonum(s) / 3600)))) .. "h ") .. JS.str(formatWhole(nil, math.fmod(Math.floor((JS.tonum(s) / 60)), 60)))) .. "m ") .. JS.str(format(nil, math.fmod(JS.tonum(s), 60)))) .. "s") end
	elseif (JS.tonum(s) < 31536000) then
		do return (((((((JS.str(formatWhole(nil, math.fmod(Math.floor((JS.tonum(s) / 86400)), 365))) .. "d ") .. JS.str(formatWhole(nil, math.fmod(Math.floor((JS.tonum(s) / 3600)), 24)))) .. "h ") .. JS.str(formatWhole(nil, math.fmod(Math.floor((JS.tonum(s) / 60)), 60)))) .. "m ") .. JS.str(format(nil, math.fmod(JS.tonum(s), 60)))) .. "s") end
	else
		do return (((((((((JS.str(formatWhole(nil, Math.floor((JS.tonum(s) / 31536000)))) .. "y ") .. JS.str(formatWhole(nil, math.fmod(Math.floor((JS.tonum(s) / 86400)), 365)))) .. "d ") .. JS.str(formatWhole(nil, math.fmod(Math.floor((JS.tonum(s) / 3600)), 24)))) .. "h ") .. JS.str(formatWhole(nil, math.fmod(Math.floor((JS.tonum(s) / 60)), 60)))) .. "m ") .. JS.str(format(nil, math.fmod(JS.tonum(s), 60)))) .. "s") end
	end
end
toPlaces = function(this, x, precision, maxAccepted)
	x = JS.D(x)
	local result = x:toStringWithDecimalPlaces(precision)
	if (JS.D(result)):gte(maxAccepted) then
		result = (JS.D((JS.tonum(maxAccepted) - Math.pow(0.1, precision)))):toStringWithDecimalPlaces(precision)
	end
	do return result end
end
formatSmall = function(this, x, precision)
	if precision == nil then precision = 2 end
	do return format(nil, x, precision, true) end
end
invertOOM = function(this, x)
	local e = x:log10():ceil()
	local m = x:div(Decimal.pow(10, e))
	e = e:neg()
	x = (JS.D(10)):pow(e):times(m)
	do return x end
end

end
