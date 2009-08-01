local bootstrap = {}

----
--  Helper methods

local function delegated(table)
   if nil == rawget(table, '__index') then
      rawset(table, '__index', table)
      rawset(table, '__metatable', 'private')
   end
   return setmetatable({}, table)
end

local function basicNew(self)
   assert(nil ~= self.__prototype__)
   local instance = delegated(self.__prototype__)
   rawset(instance, 'class', self)
   return instance
end

local function setSuperclass(self, class)
   assert(nil ~= class.__prototype__)
   rawset(self, 'superclass', class)
   rawset(self, '__prototype__', delegated(class.__prototype__))
end

local function getSuper(superclass, symbol)
    return function(self, ...)
               return superclass.__prototype__[symbol](self, ...)
           end
end

local function addSuper(superclass, symbol, method)
    local fenv = getfenv(method)
    return setfenv(method, setmetatable(
                       {super = getSuper(superclass, symbol)},
                       {__index = fenv, __newindex = fenv}))
end

local function newindex(t, k, v)
    local prototype = t.__prototype__
    local superclass = t.superclass
    if nil ~= superclass and 'function' == type(v) then
        v = addSuper(superclass, k, v)
    end
    assert(nil ~= prototype)
    rawset(prototype, k, v)
end

function bootstrap.setAsMetaclass(...)
   for _, class in pairs{...} do
      rawset(class.__prototype__, '__newindex',  newindex)
   end
end

----
--  Bootstraping.
--  Basic ideas:
--  * All Metaclasses are instances of Class
--  * Any class is a (unique) instance of its Metaclass

-- Object prototype (end point of method lookups)
local objectPrototype = {}

-- Class is a superclass of Object (1/2)
local Class = {__prototype__ = delegated(objectPrototype)}

-- ObjectMetaclass is an instance of Class
local ObjectMetaclass = basicNew(Class)
ObjectMetaclass.__name__ = 'objectlua.Object Metaclass'
-- ObjectMetaclass is a subclass of Class
setSuperclass(ObjectMetaclass, Class)

-- Class instances have the method basicNew
Class.__prototype__.basicNew = basicNew
Class.__prototype__.setSuperclass = setSuperclass
Class.__name__ = 'objectlua.Class'

-- Object is an instance of ObjectMetaclass
local Object = ObjectMetaclass:basicNew()

-- Class is a superclass of Object (2/2)
Object.__prototype__ = objectPrototype
Object.__name__ = 'objectlua.Object'
Class.superclass = Object

-- ClassMetaclass is an instance of Class
local ClassMetaclass = basicNew(Class)
-- ClassMetaclass is a subclass of ObjectMetaclass
ClassMetaclass:setSuperclass(ObjectMetaclass)

-- Class is an instance of ClassMetaclass (crossed reference)
ClassMetaclass.__prototype__.__index = ClassMetaclass.__prototype__
ClassMetaclass.__name__ = 'objectlua.Class Metaclass'
setmetatable(Class, ClassMetaclass.__prototype__)
Class.class = ClassMetaclass

-- redirect assignments in instances to instance's class __prototype__
bootstrap.setAsMetaclass(ObjectMetaclass, ClassMetaclass, Class)

-- Put Class and Object in the module
bootstrap.Object = Object
bootstrap.Class = Class
bootstrap['Object Metaclass'] = ObjectMetaclass
bootstrap['Class Metaclass'] = ClassMetaclass

return bootstrap
