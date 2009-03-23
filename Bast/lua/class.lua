-- $Id$

--[[
  Class library for lua 5.0 (& 5.1)

  http://class.luaforge.net/
  License: public domain

  o  one metatable for all objects
  o  one special attribute `__info' holding all object's information
  o  Object and Class are two predefined classes
  o  initializer and finalizer methods
  o  meta-methods
  o  class methods
  o  super() function
  o  no multiple inheritance (currently)
--]]


-- TODO: add lua 5.1 meta-methods support (# ?)
-- FIXME: add to error message all meta-methods lookup results
-- FIXME: simplify super() mechanism
-- FIXME: protect objects' metatable
-- ?: add __r*** meta-methods
-- ?: create weak class list?
-- !: comments?

--[[ v.8 TODO
  rid of __xxx__ meta-methods, correct API
--]]





---- UTILITIES ----

local u = {}

function u.wrongarg(n,expected,got)
  return 'arg '..n..' expected to be '..expected..' (got '..tostring(got)..')'
end

local wrongarg = u.wrongarg

function u.isname(name)
  return type(name)=='string' and string.find(name,'^[_%a][_%w]*$')
end

local isname = u.isname

function u.assert(value,errmsg,...)
  if value then
    return value
  else
    if type(errmsg)=='nil' then
      error('assertion failed!',2)
    elseif type(errmsg)=='string' then
      error(errmsg,2)
    else
      --trying to call second arg
      error(errmsg(unpack(arg)),2)
    end
  end
end

local assert = u.assert

function u.fwrongarg(...)
  return function()
    return wrongarg(unpack(arg))
  end
end

local fwrongarg = u.fwrongarg





function table.key(t,x)
  for key, value in pairs(t) do
    if value == x then
      return key
    end
  end
end

function table.keys(t)
  local u = {}
  for key in pairs(t) do
    table.insert(u,key)
  end
  return u
end




local INFO = '__info'


function u.isobject(o)
  return type(o)=='table' and rawget(o,INFO)
end

local isobject = u.isobject




---- METATABLE ----

local METAMETHODS = {
  '__tostring',
  '__add',
  '__sub',
  '__mul',
  '__div',
  '__pow',
  '__lt',
  '__le',
  '__eq',
  '__call',
  '__unm',
  '__concat',
  '__newindex',
}


local metatable = {}

for _, name in ipairs(METAMETHODS) do
  local name = name
  metatable[name] = function(...)
    ----
    local arg = {...}
    local a, b = unpack(arg)
    local f
    if isobject(a) then
      f = a[name]
    end
    if not f and isobject(b) then
      f = b[name]
    end
    if not f then
    ----
      local name = name..'__'
      if isobject(a) then
        f = a[name]
      end
      if not f and isobject(b) then
        f = b[name]
      end
    ----
    end
    ----
    assert(f, function()
                 local class = rawget(a,INFO).__class
                 local cname = rawget(class,INFO).__name
                 return 'meta-method not found: '..cname..':'..name
               end)
    return f(unpack(arg))
  end
end




---- PRIMITIVES ----

local
function table2object(t)
  assert(type(t)=='table', fwrongarg(1,'table',t))
  local info = {}
  rawset(t,INFO,info)
  setmetatable(t,metatable)

  ----
  local p = newproxy(true)
  local mp = getmetatable(p)
  function mp:__gc()
    if rawget(t,INFO) == info then
      t:finalize()
    end
  end
  rawget(t,INFO).__proxy = p
  ----

  return t
end

local
function object2table(o)
  assert(isobject(o), fwrongarg(1,'object',o))
  setmetatable(o,nil)
  rawset(o,INFO,nil)
  return o
end

local
function givename(o,name)
  assert(isobject(o), fwrongarg(1,'object',o))
  assert(isname(name), fwrongarg(2,'name',name))
  rawget(o,INFO).__name = name
  getfenv(2)[name] = o
end

local
function setclass(o,class)
  assert(isobject(o), fwrongarg(1,'object',o))
  assert(isobject(class), fwrongarg(2,'object',class))
  rawget(o,INFO).__class = class
end

local
function setsuper(class,superclass)
  assert(isobject(class), fwrongarg(1,'object',class))
  assert(isobject(superclass), fwrongarg(2,'object',superclass))
  rawget(class,INFO).__super = superclass
end

local
function object2class(o,name)
  assert(isobject(o), fwrongarg(1,'object',o))
  assert(isname(name), fwrongarg(2,'name',name))
  givename(o,name)
  rawget(o,INFO).__methods = {}
  ----
  rawget(o,INFO).__isclass = true
  rawget(o,INFO).__cmethods = {}
  ----
end

local
function findmethod(class,name,iscmethod)
  local storage = iscmethod and '__cmethods' or '__methods'
  while class do
    local info = rawget(class,INFO)
    value = info[storage][name]
    if value ~= nil then
      return value
    end
    class = info.__super
  end
end



function metatable:__index(name)
  local value
  ----
  -- class method lookup
  if rawget(self,INFO).__isclass then
    value = findmethod(self,name,true)
    if value ~= nil then
      return value
    end
  end
  ----
  -- instance method lookup
  local class = rawget(self,INFO).__class
  value = findmethod(class,name)
  if value ~= nil then
    return value
  end
  ----
  -- custom lookup
  if name ~= '__index' and name ~= '__index__' then
    local index = self.__index or self.__index__  -- recursion
    if index then
      value = index(self,name)
      if value ~= nil then
        return value
      end
    end
  end
end





---- OBJECT CLASS ----

local _Object = table2object{}
object2class(_Object,"Object")



---- CLASS CLASS ----

local _Class = table2object{}
object2class(_Class,"Class")



---- SETUP ----

setclass(Object,Class)
setclass(Class,Class)
setsuper(Class,Object)



---- INSTANCE/CLASS METHOD REGISTRATION ----

local
function makesupermethod(self,name,iscmethod)
  return function(...)
    local method
    local classinfo
    if iscmethod then
      classinfo = rawget(self,INFO)
    else
      local class = rawget(self,INFO).__class
      classinfo = rawget(class,INFO)
    end
    local super = classinfo.__super
    if super then
      method = findmethod(super,name,iscmethod)
    end
    assert(method, "no super method for "..classinfo.__name..":"..name)
    return method(self,...)
  end
end

local methodsmeta = {}

function methodsmeta:__call(object,...)
  local env = getfenv(self.__f)
  local metafenv = {
    __newindex = env,
    __index = env,
  }
  local fenv = {
    super = makesupermethod(object,self.__name,self.__iscmethod),
  }
  setmetatable(fenv,metafenv)
  setfenv(self.__f,fenv)
  local result = {self.__f(object,...)}
  setfenv(self.__f,env)
  return unpack(result)
end

local
function storemethod(storage,name,iscmethod,method)
  if type(method) == 'function' then
    local t = {
      __name = name,
      __f = method,
      __iscmethod = iscmethod,
    }
    setmetatable(t,methodsmeta)
    storage[name] = t
  else
    storage[name] = method
  end
end

rawget(Class,INFO).__methods.__newindex =
  function(self,name,method)
    storemethod(rawget(self,INFO).__methods,name,false,method)
  end



---- CLASS METHODS ----

function Class:__call__(...)
  local instance = self:new(...)
  instance:initialize(...)
  return instance
end

function Class:initialize(name,superclass)
  assert(isname(name), fwrongarg(1,'name',name))
  object2class(self,name)
  superclass = superclass or Object
  assert(isobject(superclass), fwrongarg(2,'object',superclass))
  setsuper(self,superclass or Object)
end

function Class:name()
  return rawget(self,INFO).__name
end

function Class:super()
  return rawget(self,INFO).__super
end

function Class:classtable()
  local t = {}
  local mt = {}
  function mt.__newindex(_,name,method)
    storemethod(rawget(self,INFO).__cmethods,name,true,method)
  end
  setmetatable(t,mt)
  return t
end

function Class:__tostring__()
  return self:name()
end

function Class:derives(class)
  local superclass = self:super()
  if superclass then
    return superclass == class or superclass:derives(class)
  end
end

--function Class:findmethod(name)

--[[
function Class:definition()
  local s = 'class "'..self:name()..'"'
  local super = self:super()
  if super and super ~= Object then
    s = s..' ('..super:name()..')'
  end
  s = s..' do\n'
  for name, _ in pairs(self) do
    ....
  end
  ....
  return 'class "'....'"'..super_s..' do\n'..
    ..?..
    'end'
end
--]]

function Class:adopt(t,initialize,...)
  assert(type(t)=='table', wrongarg(1,'table',t))
  local o = table2object(t)
  setclass(o,self)
  if initialize then
    o:initialize(...)
  end
  return o
end



---- OBJECT METHODS ----

-- class methods

local Objectclass = Object:classtable()

function Objectclass:new()
  ----
  --return self:adopt{}
  ----
  local o = table2object{}
  setclass(o,self)
  return o
end

-- instance methods

function Object:initialize()
end

function Object:finalize()
end

function Object:class()
  return rawget(self,INFO).__class
end

function Object:__eq__(other)
  return rawequal(self,other)
end

function Object:__newindex__(name,value)
  rawset(self,name,value)
end

function Object:instanceof(class)
  --assert?
  return self:class() == class
end

function Object:inherits(class)
  --assert?
  local _class = self:class()
  return _class == class or _class:derives(class)
end

--[[
function Object:isclass()
  return self:inherits(Class)
end
--]]

function Object:__tostring__()
  return 'instance of '..self:class():name()
end

function Object:__concat__(other)
  if isobject(self) then
    self = tostring(self)
  elseif isobject(other) then
    other = tostring(other)
  end
  return self..other
end

--[[
function Object:variables(retset)
  local vars = {}
  for name in pairs(self) do
    vars[name] = true
  end
  vars[INFO] = nil
  if retset then
    return vars
  end
  local t = {}
  for name in pairs(vars) do
    table.insert(t,name)
  end
  return t
end
--]]

--[[
function Object:methods(listinherited)
  listinherited = default(true,listinherited)
  if self:isclass() then
    local vset = self:variables(true)
    if listinherited then
      for name in ? do
      end
      ....
    end
    ?
    ....
  else
    return self:class():methods()
  end
end
--]]

function Object:totable(finalize)
  if finalize then
    self:finalize()
  end
  setmetatable(self,nil)
  local info = rawget(self,INFO)
  rawset(self,INFO,nil)
  return self, info
end

function Object:address()
  local mt = getmetatable(self)
  setmetatable(self,nil)
  local s = tostring(self)
  local _, _, s = string.find(s,'(0x%x+)$')
  setmetatable(self,mt)
  return s
end

function Object:bound(name)
  local method = self[name]
  return function(...)
    return method(self,...)
  end
end

function Object:send(name,...)
  local f = self:bound(name)
  return f(...)
end

function Object:instanceeval(f,...)
  return f(self,...)
end

--[[
function Object:methods()
  ....
end
--]]

function Object:vars()
  local set = {}
  for key in pairs(self) do
    set[key] = true
  end
  set[INFO] = nil
  return table.keys(set)
end

--[[
function Object:next()
  ....
end

function Object:pairs()
  ....
end

function Object:ipairs()
  ....
end
--]]


--Object:superclasses()






-- weak class list ?



function class(name)
  assert(isname(name), fwrongarg(1,'name',name))
  local _class = Class(name)
  return function(superclass)
    assert(isobject(superclass), fwrongarg(1,'object',superclass))
    setsuper(_class,superclass)
  end
end

classu = u
