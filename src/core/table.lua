--- @param deep number
--- @return string
local function addSpace(deep)
	local space = ""

	for i = 1, deep do
		space = space .. "	"
	end

	return space
end

--- @param tbl table
--- @param blAddLineJump boolean?
--- @param deepIndex number?
--- @return string
function table.ToString(tbl, blAddLineJump, deepIndex)
	local result = "{"
	deepIndex = (deepIndex or 0) + 1

	if blAddLineJump then result = result.."\n" .. addSpace(deepIndex) end

	local i = 0
	local lastKey

    for k, v in pairs(tbl) do
		i = i + 1
        if type(k) == "string" then
			if tonumber(k) then
				result = result.."[" .. k .. "] = "
			else
            	result = result.."" .. k .. " = "
			end
		elseif type(k) == "number" then
			if (lastKey and lastKey + 1 ~= k and lastKey ~= 1) or k == 0 then
				result = result.."[" .. k .. "] = "
			end

			if k == 0 then
				lastKey = nil
			else
				lastKey = k
			end
		end

		if type(k) == "string" and k == "flags" and type(v) == "string" then
			result = result .. v
		elseif type(v) == "table" then
            result = result..table.ToString(v, blAddLineJump, deepIndex)
        elseif type(v) == "boolean" then
            result = result..tostring(v)
		else
			if type(v) == "number" then
            	result = result .. v
			else
				result = result.."\""..v.."\""
			end
        end

        result = result .. (table.Count(tbl) == i and "" or ",")
		if blAddLineJump then result = result.."\n".. addSpace(deepIndex) end
    end

    if result ~= "" and result:len() > 1 and result[result:len()] == "," then
        result = string.sub(result, 1, string.len(result) - 1)
    end

    return result.."}"
end

--- @param tbl table
--- @param checkCount number?
--- @return number|boolean
function table.Count(tbl, checkCount)
	if not tbl or type(tbl) ~= "table" then return not checkCount and 0 end
	local n = 0
	for k,v in pairs(tbl) do
		n = n + 1
		if checkCount and n >= checkCount then return true end
	end
	return not checkCount and n
end

--- @param tbl table
--- @param key any
--- @param value any
--- @return any
function table.GetFromValue(tbl, key, value)
	for _,v in pairs(tbl) do
		if v[key] == value then return v end
	end
end

--- @param tbl table
--- @return table
function table.GetValues(tbl)
	local list = {}

	for _,v in pairs(tbl) do
		list[#list + 1] = v
	end

	return list
end

--- @param tbl table
--- @param value any
--- @param inKey any?
--- @return any
function table.GetKeyFromValue(tbl, value, inKey)
	for k,v in pairs(tbl) do
		local check = inKey and v[inKey] or v
		if check == value then return k end
	end
end

--- @param tbl table
--- @param value any
--- @param keyName any?
--- @return any, any
function table.find(tbl, value, keyName)
	for k, v in pairs(tbl) do
		if (keyName and v[keyName] == value) or (not keyName and v == value) then return k, v end
	end
end

return table