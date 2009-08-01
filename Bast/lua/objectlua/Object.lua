local pairs = pairs

local bootstrap = require "objectlua.bootstrap"

require 'objectlua.Class'

local Object = bootstrap.Object

function Object:initialize()
end

function Object:isKindOf(class)
   return self.class == class or self.class:inheritsFrom(class)
end

function Object:clone(object)
    local clone = self.class:basicNew()
    for k, v in pairs(self) do
        clone[k] = v
    end
    return clone
end

function Object:className()
    return self.class:name()
end

function Object:subclassResponsibility()
    error("Error: subclass responsibility.")
end

return Object
