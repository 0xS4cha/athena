--- @class ArgParser
--- @field definitions table<string, table>
--- @field parsed table<string, any>
local ArgParser = {}
ArgParser.__index = ArgParser

--- @return ArgParser
function ArgParser.new()
    local self = setmetatable({}, ArgParser)
    self.definitions = {}
    self.parsed = {}
    return self
end


--- @param name string
--- @param options table?
function ArgParser:add_argument(name, options)
    options = options or {}
    options.type = options.type or "boolean"
    
    self.definitions[name] = options
    self.parsed[name] = options.default
end

--- @param args string[]
--- @return table<string, any>
function ArgParser:parse(args)
    local i = 1
    while i <= #args do
        local token = args[i]
        
        local found_name = nil
        local found_opt = nil
        
        for name, opt in pairs(self.definitions) do
            if token == "--" .. name or (opt.short and token == "-" .. opt.short) then
                found_name = name
                found_opt = opt
                break
            end
        end
        
        if found_name then
            if found_opt.type == "boolean" then
                self.parsed[found_name] = not found_opt.default
            elseif found_opt.type == "value" then
                i = i + 1
                local val = args[i]
                if tonumber(val) then val = tonumber(val) end
                self.parsed[found_name] = val
            end
        end
        
        i = i + 1
    end
    return self.parsed
end

--- @param name string
--- @return any
function ArgParser:get(name)
    return self.parsed[name]
end

return ArgParser