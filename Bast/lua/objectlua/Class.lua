local bootstrap = require 'objectlua.bootstrap'

local Object = bootstrap.Object
local Class  = bootstrap.Class

local classes

local function addClass(class)
    local name = class:name()
    assert('string' == type(name))
    classes[name] = class
end

----
--  Class methods

function Class:new(...)
   local instance = self:basicNew()
   instance:initialize(...)
   return instance
end

function Class:subclass(className)
   local metaclass = Class:new()
   metaclass:setSuperclass(self.class)
   bootstrap.setAsMetaclass(metaclass)
   local subclass = metaclass:new()
   subclass:setSuperclass(self)
   if 'string' == type(className) then
       assert(nil == self:find(className))
       local metaclassName = className..' Metaclass'
       rawset(subclass, '__name__', className)
       rawset(metaclass, '__name__', metaclassName)

       addClass(subclass)
       addClass(metaclass)
   end
   return subclass
end

function Class:isMeta()
   return self.class == Class
end

function Class:name()
    return self.__name__
end

function Class:inheritsFrom(class)
    if nil == self or Object == self then
        return false
    end
    local superclass = self.superclass
    if superclass == class then
        return true
    end
    return superclass:inheritsFrom(class)
end

-- function Class:has(symbol)
--     local functionName = symbol:match('%w+')
--     functionName = functionName:sub(1, 1):upper()..functionName:sub(2)
--     local geterSymbol = 'get'..functionName
--     local seterSymbol = 'set'..functionName

--     assert(nil == self.__prototype__[geterSymbol])
--     assert(nil == self.__prototype__[seterSymbol])

--     rawset(self.__prototype__, geterSymbol, function(self)
--                                                 return self[symbol]
--                                             end)
--     rawset(self.__prototype__, seterSymbol, function(self, value)
--                                                 self[symbol] = value
--                                             end)
-- end

function Class:all()
    local t = {}
    for k, v in pairs(classes) do
        t[k] = v
    end
    return t
end

function Class:find(name)
    return classes[name]
end

function Class:reset()
    classes = {}

    local Prototype       = require 'objectlua.Prototype'
    local bootstrap       = require 'objectlua.bootstrap'
    local ObjectMetaclass = bootstrap['Object Metaclass']
    local ClassMetaclass  = bootstrap['Class Metaclass']

    addClass(Object)
    addClass(Class)
    addClass(ObjectMetaclass)
    addClass(ClassMetaclass)
end

Class:reset()

return Class
