-- phelpobject.lua
-- $Id$
-- base class for using pluginhelper

-- Author: Eric Davis - 24th July 2009

--[[

--]]

--require 'classlib'
require 'tprint'
require 'verify'
require 'pluginhelper'
require 'serialize'
require 'copytable'
require 'tableSort'

local Object = require 'objectlua.Object'

Phelpobject = Object:subclass()

function Phelpobject:initialize(args)
  --[[

  --]]
  mdebug('phelpobject __init')
  self.classinit = true
  self.shutdownf = false
  self.set_options = {}
  self.cname = args.name or "Default"
  mdebug('phelpobject __init self.cname', self.cname)
end

function Phelpobject:reset()
  for i,v in pairs(self.set_options) do
    self[i] = verify(v.default, v.type, {low=v.low, high=v.high, silent=true})
  end
end

function Phelpobject:savestate(override)
  if self.classinit and not override then
    return
  end
  mdebug(self.cname, 'savestate')
  for i,v in pairs(self.set_options) do
    SetVariable(i .. self.cname, tostring(self[i]))
  end
end

function Phelpobject:NotifyChildren()
  for i, v in ipairs (self.children) do
    v.UpdatefromParent()
  end
end

function Phelpobject:__tostring()
  return self.cname
end

function Phelpobject:shutdown()
  self.shutdownf = true
  self:disable()
end

function Phelpobject:init()
  for name,setting in pairs(self.set_options) do
    local gvalue = GetVariable(name..self.cname)
    if gvalue == nil or gvalue == 'nil' then
      gvalue = setting.default
    end
    local tvalue = verify(gvalue, setting.type, {window = self})
    self:set(name, tvalue, {silent = true})
  end
  self:savestate(true)
  SaveState()
  self:disable()
end

function Phelpobject:enable()
  self.shutdownf = false
  self.classinit = false
  if self.disabled then
    self.disabled = false
  end
end

function Phelpobject:disable()
  self:savestate()
end

function Phelpobject:checkvalue(option, value)
  local varstuff = self.set_options[option]
  if not varstuff then
    ColourNote("red", "", "Option" .. option .. "does not exist.")
    return 2, nil
  end
  if varstuff.readonly and not self.classinit then
    plugin_header()
    ColourNote(RGBColourToName(var.plugin_colour), "", "That is a read-only var")
    ColourNote("", "", "")
    return 1, nil
  end
  if value == 'default' then
    value = varstuff.default
  end
  tvalue = verify(value, varstuff.type, {low=varstuff.low, high=varstuff.high, window=self})
  if tvalue == nil then
    ColourNote("red", "", "That is not a valid value for " .. option)
    return 3, nil
  end
  mdebug('phelpobject checkvalue', value, 'type', varstuff.type, 'returned', tvalue)
  return true, tvalue
end

function Phelpobject:set(option, value, args)
  mdebug('phelpobject set option', option, 'value', value)
  varstuff = self.set_options[option]
  local changedsetting = nil
  args = args or {}
  if args.silent == nil or args.silent then
    function changedsetting(toption, tvarstuff, cvalue)

    end
  else
    function changedsetting(toption, tvarstuff, cvalue)
      plugin_header()
      if tvarstuff.type == "colour" then
        colourname = RGBColourToName(self:get_colour(cvalue))
        ColourNote("orange", "black", toption .. " set to : ",
              colourname, "black", colourname)
      else
        colourname = RGBColourToName(var.plugin_colour)
        ColourNote("orange", "black", toption .. " set to : ",
              colourname, "black", tostring(cvalue))
      end
      ColourNote("", "", "")
    end
  end
  retcode, tvalue = self:checkvalue(option, value, args)
  mdebug('phelpobject set checkvalue retcode', retcode, 'tvalue', tvalue)
  if retcode == true then
    if args.default then
      varstuff.default = tvalue
      return
    end
    self[option] = tvalue
    mdebug("setting", option, "to", tvalue)
    changedsetting(option, varstuff, tvalue)
    SaveState()
    return true
  end
  return false
end

function Phelpobject:set_default(option, value)
  varstuff = self.set_options[option]
  retcode, tvalue = self:checkvalue(option, value)
  if retcode then
    varstuff.default = tvalue
  end
end

function Phelpobject:print_settings()
  for v,t in tableSort(self.set_options, 'sortlev', 50) do
    if t.get then
       value = t.get(i)
    else
       value = self[v]
    end
    if t.type == "colour" then
      value = verify_colour(value, {window = self})
    end
    print_setting_helper(v, value, t.help, t.type, t.readonly)
  end
end


function Phelpobject:add_setting(name, setting)
  mdebug('phelpobject add_setting', name)
  self.set_options[name] = setting
  --self.skeys = sort_settings(self.set_options)

  --self:set(name, verify(GetVariable(name..self.cname) or setting.default, setting.type, {window = self}), {silent = true})
  mdebug('done add_setting', name)
end

