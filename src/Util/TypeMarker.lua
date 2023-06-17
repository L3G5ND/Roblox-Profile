local TypeMarker = {}
local Markers = {}

TypeMarker.Mark = function(name)
	assert(typeof(name) == "string", string.format("Invalid argument #1 (must be a 'string')"))

	local marker = newproxy(true)

	getmetatable(marker).__tostring = function()
		return name
	end

	Markers[marker] = true

	return marker
end

TypeMarker.Is = function(typeMarker)
	return Markers[typeMarker] == true
end

return TypeMarker
