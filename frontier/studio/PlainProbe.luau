--!optimize 2
-- Interpreter baseline for NativeProbe.luau (identical body, no --!native).
return function(buf: buffer, n: number): number
	local acc = 0
	for i = 0, n - 1 do
		local v = buffer.readu32(buf, i * 4)
		v = bit32.bxor(v * 1664525 + 1013904223, bit32.rshift(v, 7))
		buffer.writeu32(buf, i * 4, v)
		acc += bit32.band(v, 255)
	end
	return acc
end
