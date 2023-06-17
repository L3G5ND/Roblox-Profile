local function indent(source, indentLevel)
	local indentString = ("\t"):rep(indentLevel)
	return indentString .. source:gsub("\n", "\n" .. indentString)
end

return function(message, level)
	local trace = debug.traceback("", level):sub(2)
	local fullMessage = ("%s\n%s"):format(message, indent(trace, 1))
	error("[Profile] - " .. fullMessage, 0)
end
