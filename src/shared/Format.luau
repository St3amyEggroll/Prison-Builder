-- Format: tiny helpers for turning numbers into friendly text,
-- shared by the server (buy-pad price tags) and the client (cash HUD).

local Format = {}

-- 1234567 -> "1,234,567"
function Format.thousands(n)
	local s = tostring(math.floor(n + 0.5))
	while true do
		local replaced
		s, replaced = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if replaced == 0 then
			break
		end
	end
	return s
end

-- 1234567 -> "$1,234,567"
function Format.money(n)
	return "$" .. Format.thousands(n)
end

return Format
