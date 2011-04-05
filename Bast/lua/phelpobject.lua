-- phelpobject.lua
-- $Id$
-- base class for using pluginhelper

-- Author: Eric Davis - 24th July 2009

--[[

Events for phelpobject:
    self:processevent('option_' .. option, {option=option, value=value}) 
      - an event for a specific option
    self:processevent('option-any', {option=option, value=value}) 
      - an event to notify on any option change

to use events register with   self:registerevent('option_textfont', object, object.onfontchange) if the target is a phelper object
                              self:registerevent('visibility', {}, toggleexample) if the target function is just a function

the function must look like:
function shadeexample(object, args)
  -- object will be same as the second argument in registerevent
  -- args, see the actual event
  examplewin:show(not args.flag)
end

--]]
require 'var'
require 'tprint'
require 'verify'
require 'serialize'
require 'copytable'
require 'tablefuncs'

AddFont (GetInfo (66) .. "\\Dina.fon")

local Object = require 'objectlua.Object'

Phelpobject = Object:subclass()

function Phelpobject:initialize(args)
  --[[

  --]]
  self:mdebug('phelpobject __init')
  self.phelper = nil
  self.classinit = true
  self.shutdownf = false
  self.disabled = false
  self.set_options = {}
  self.cname = args.name or "Default"
  self.id = GetPluginID() .. '-' .. self.cname
  self:mdebug('phelpobject __init self.cname', self.cname)
  self.cmds_table = {}
  self.events = {}

  self:add_setting( 'tdebug', {type="bool", help="show debugging info for this option", default=verify_bool(false), sortlev=1})
  self:add_setting( 'ignorebsetting', {type="bool", help="show debugging info for this option", default=verify_bool(false), sortlev=1, longname="Ignore Broadcast Settings"})

  self:add_cmd('help', {func="cmd_help", help="show help", prio=99})
  self:add_cmd('debug', {func="cmd_debug", help="toggle debugging", prio=99})
  self:add_cmd('set', {func="cmd_set", help="set settings", nomenu=true, prio=99})
  self:add_cmd('reset', {func="cmd_reset", help="reset settings to default values", prio=99})
  self:add_cmd('save', {func=SaveState, help="save plugin variables", prio=99})
  self:add_cmd('showvars', {func="cmd_showvars", help="show plugin variables", prio=99})
  self:add_cmd('showevents', {func="cmd_showevents", help="show functions registered for all events", prio=99})
  
end


function Phelpobject:registerevent(tevent, object, tfunction, plugin)
  if not tfunction then
    print(self.id, 'function does not exist for', tevent)
    return
  end
  if self.events[tevent] == nil then
    self.events[tevent] = {}
  end
  table.insert(self.events[tevent], {object=object, func=tfunction, plugin=plugin})
end


function Phelpobject:processevent(tevent, args)
  if self.events[tevent] == nil then
    return
  end
  for i,v in ipairs(self.events[tevent]) do
    if v.plugin then
      local targs = serialize.save_simple(args)
      --print('calling', v.plugin, v.func, targs)
      CallPlugin(v.plugin, v.func, targs)
    else
      if v.func then
        v.func(v.object, args)
      end
    end
  end
end

function Phelpobject:unregisterevent(tevent, object, tfunction, plugin)
  if self.events[tevent] then
    for i,v in ipairs(self.events[tevent]) do
      if v.func == tfunction and (v.object == object or v.plugin == plugin) then
        table.remove(self.events[tevent], i)
      end
    end
  end
end

function Phelpobject:cmd_showvars(cmddict)
  tprint(GetVariableList())
end

function Phelpobject:cmd_showevents(cmddict)
  tprint(self.events)
end

function Phelpobject:cmd_set(cmddict)
  option = cmddict[1]
  value = cmddict[2]
  if option == nil or self.set_options[option] == nil then
    ColourNote("", "", "")
    if option ~= nil and option ~= '' then
      self:plugin_header()
      ColourNote("white", "black", "That is not a valid setting")
    end
    self:print_settings_helper()
    return false
  end
  return self:set_external(option, value, {silent=false, istable=self.set_options[option].istable})
end

function Phelpobject:cmd_debug(cmddict)
  newvalue = not self.tdebug
  retcode = self:set('tdebug', not self.tdebug)
  if retcode then
     self:plugin_header()
     colourname = RGBColourToName(var.plugin_colour)
     if newvalue then
        ColourNote(colourname, "black", "Debugging is now on")
     else
        ColourNote(colourname, "black", "Debugging is now off")
     end
     ColourNote("", "", "")
  end
  return retcode
end

function Phelpobject:cmd_help(cmddict)
  --[[
    this function prints a help table for cmds_table
  --]]
  self:plugin_header("Commands")

  for i,v in tableSort(self.cmds_table) do
    if v.help ~= '' then
      ColourNote( "white", "black", string.format("%-15s", i),
              RGBColourToName(var.plugin_colour),  "black", ": " .. v.help )
    end
  end
  ColourNote( "", "", "")
  return true
end

function Phelpobject:cmd_reset(cmddict)
  self:init_vars(true)
  self:plugin_header()
  ColourNote(RGBColourToName(var.plugin_colour), "black", "Plugin options reset for " .. self.cname)
  return true
end

function Phelpobject:set_default(option, value)
  varstuff = self.set_options[option]
  retcode, tvalue = self:checkvalue(option, value)
  if retcode then
    varstuff.default = tvalue
  end
end


function Phelpobject:plugin_header(header)
  header = header or ""
  ColourNote("", "", "")
  ColourNote(RGBColourToName(var.plugin_colour), "black", GetPluginInfo(GetPluginID (),1) .. " ",
             RGBColourToName(var.plugin_colour), "black", "v" .. GetPluginInfo(GetPluginID (),19) .. " " .. self.cname .. " ",
             "white", "black", header)
  ColourNote("white", "black", "-----------------------------------------------")
end


function Phelpobject:savestate(override)
  if self.classinit and not override then
    return
  end
  for i,v in pairs(self.set_options) do

    if v.istable then
      SetVariable(i .. self.cname, serialize.save_simple((self[i])))
    else
      SetVariable(i .. self.cname, tostring(self[i]))
    end
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

function Phelpobject:find_setting(setting)
  soption = self.set_options[setting]
  return soption
end

function Phelpobject:init()
  self:init_vars()
  self:disable()
end

function Phelpobject:init_vars(reset)
  for name,setting in tableSort(self.set_options, 'sortlev', 50) do
    local gvalue = GetVariable(name..self.cname)
    if gvalue == nil or gvalue == 'nil' or reset then
      gvalue = setting.default
    end
    if setting.istable then
      local tvalue = loadstring('return ' .. gvalue or "")()
      gvalue = tvalue
    end
    local tvalue = verify(gvalue, setting.type, {silent = true, window = self})
    self:set(name, tvalue, {silent = true, window = self, istable=setting.istable})
  end
  self:savestate(true)
  SaveState()
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
  self.disabled = true
end

function Phelpobject:checkvalue(option, value, args)
  if args == nil then
    args = {}
  end
  local varstuff = self.set_options[option]
  if not varstuff then
    self:plugin_header()
    ColourNote("red", "", "Option " .. option .. " does not exist.")
    return 2, nil
  end
  if value == 'default' then
    if varstuff.istable then
      value = loadstring('return ' .. varstuff.default or "")()
    else
      value = varstuff.default
    end
  end
  local default = varstuff.default
  if self[option] then
    default = self[option]
  end
  local ttable = {silent=args.silent, low=varstuff.low, high=varstuff.high, window=self, msg=varstuff.msg, help=varstuff.help, default=default}
  tvalue = verify(value, varstuff.type, ttable)
  if tvalue == nil then
    self:plugin_header()
    ColourNote("red", "", "That is not a valid value for " .. option)
    return 3, nil
  end
  return true, tvalue
end

function Phelpobject:set(option, value, args)
  if args == nil then
    args = {}
  end
  retcode, tvalue = self:checkvalue(option, value, args)
  varstuff = self.set_options[option]
  if retcode == true then
    self[option] = tvalue
    afterf = varstuff.after
    if args.putvar then
      if args.istable then
        var[option] = serialize.save_simple(tvalue)
      else
        var[option] = tvalue
      end
    end
    if afterf ~= nil then
      self:run_func(afterf)
    end
    if not args.noevent then
      self:processevent('option_' .. option, {option=option, value=value})    
      self:processevent('option-any', {option=option, value=value})  
    end
    SaveState()
    return true
  end
  return false
end

function Phelpobject:set_external(option, value, args)
  varstuff = self.set_options[option]
  if varstuff.readonly and not self.classinit and value ~= 'default' then
    self:plugin_header()
    ColourNote(RGBColourToName(var.plugin_colour), "", "That is a read-only var")
    ColourNote("", "", "")
    return 1, nil
  end
  args = args or {}
  local function changedsetting(toption, tvarstuff, cvalue)
      self:plugin_header()
      if tvarstuff.type == "colour" then
        colourname = RGBColourToName(self:get_colour(cvalue))
        ColourNote("orange", "black", toption .. " set to : ",
              colourname, "black", colourname)
      else
        colourname = RGBColourToName(var.plugin_colour)
        if formatfunc then
          cvalue = formatfunc(cvalue)
        elseif istable then
          cvalue = serialize.save_simple(cvalue)
        end
        ColourNote("orange", "black", toption .. " set to : ",
              colourname, "black", tostring(cvalue))
      end
      ColourNote("", "", "")
  end
  retcode = self:set(option, value, args)
  if retcode == true then
    changedsetting(option, varstuff, tvalue)
    return true
  end
  return false
end

function Phelpobject:print_settings_helper(ttype)
  --[[
    this function goes through the setoptions table and the window and prints each setting
  --]]
  self:plugin_header("Settings")
  for v,t in tableSort(self.set_options, 'sortlev', 50) do
    self:print_setting_helper(v, self[v], t.help, t.type, t.readonly, t.istable, t.formatfunc)
  end
  ColourNote("", "", "")
end

function Phelpobject:print_setting_helper(setting, value, help, ttype, readonly, istable, formatfunc)
  --[[
    this function prints a setting a standard format
     if the setting is a colour, then it will print the value in that colour
  --]]
  local colour = var.plugin_colour
  if ttype == "colour" then
    local tcolour = verify_colour(value)
    if tcolour ~= nil then
     colour = tcolour
     value = RGBColourToName(colour)
    end
  end
  if readonly then
    help = help .. ' (readonly)'
  end
  if formatfunc then
    value = formatfunc(value)
  elseif istable then
    value = serialize.save_simple(value)
  end
  ColourNote( "white", "black", string.format("%-30s : ", setting),
              RGBColourToName(colour), "black", string.format("%-20s", tostring(value)),
              "white", "black", " - " .. help)
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
    self:print_setting_helper(v, value, t.help, t.type, t.readonly, t.istable, t.formatfunc)
  end
end


function Phelpobject:add_setting(name, setting)
  self.set_options[name] = setting
end

function Phelpobject:mdebug(...)
  if (var.tdebug == "true" or self.tdebug) and self.disabled == false then
    print("DEBUG: " .. GetPluginInfo (GetPluginID (), 1), "- Object", self.cname, ": Debug")
    print("---------------------------------------------")
    local tstring = {}
    for n=1,select('#',...) do
      local e = select(n,...)
      if type(e) == 'table' then
        if #tstring > 0 then
          print(unpack(tstring))
          tstring = {}
        end
        tprint(e)
      else
        table.insert(tstring, e)
      end
    end
    if #tstring > 0 then
      print(unpack(tstring))
    end
    print(" ")
  end
end

function Phelpobject:broadcast(num, data, broadcastdata)
  if data then
    self:mdebug("Broadcast " .. num .. "\n", data)
  else
    self:mdebug("Broadcast " .. num .. "\n")
  end
  BroadcastPlugin(tonumber(num), broadcastdata)
end

function Phelpobject:add_cmd(name, stuff)
  if not self.cmds_table[name] then
    self.cmds_table[name] = stuff
    if self.cmds_table[name].func == nil then
      print("cmd", name, "function does not exist")
    end
  else
    print("cmd", name, "already exists")
  end
end

function Phelpobject:find_cmd(cmd)
  --[[
    find the cmd
  --]]
  if cmd == nil or cmd == '' then
    return nil, nil
  end
  cmd = string.lower(cmd)
  if self.cmds_table[cmd] then
    return cmd, self.cmds_table[cmd]
  end
  fcmd = "^" .. cmd .. ".*$"
  for tcmd,cmditem in tableSort(self.cmds_table, "prio", 50) do
    tstart, tend =  string.find(string.lower(tcmd), fcmd)
    if tstart and tstart > 0 then
      return tcmd, self.cmds_table[tcmd]
    end
  end

  return nil, nil

end

function Phelpobject:run_func(tfunc, args)
  if type(tfunc) == 'string' then
    func = self[tfunc]
    if func then
      func(self, args)
      return true
    else
      ColourNote("red", "", "Could not find function " .. fullcmd .. " in " .. self.cname)
      return false
    end
  elseif type(tfunc) == 'function' then
    tfunc(args)
    return true
  end
  ColourNote("red", "", "The function for command " .. fullcmd .. " is invalid, please check plugin")
  return false
end

function Phelpobject:run_cmd(cmddict, silent)
  if self.disabled then
    self:init(true)
    self:enable()   
  end
  if silent == nil then
    silent = false
  end
  if (cmddict.action == nil or cmddict.action == '') and silent == false then
    self:cmd_help(cmddict)
    return false
  end
  fullcmd, cmd = self:find_cmd(cmddict.action)
  if fullcmd ~= nil then
    retcode = self:run_func(cmd.func, cmddict)
    return retcode
  end
  if not silent then
    ColourNote("", "", "")
    ColourNote("white", "black", "That is not a valid command")
    self:cmd_help(cmddict)
  end
  return false

end

function Phelpobject:enabletriggroup(group, flag)
  if EnableTriggerGroup (group, flag) == 0 then
    if flag then
      print("no triggers to enable for group", group)
    else
      print("no triggers to disable for group", group)
    end
    print("")
  end
end

function Phelpobject:cmd_update(cmd, key, value)
  self.cmds_table[cmd][key] = value
end

function Phelpobject:get_colour(colour, default, return_original)
  local return_orig = return_original or false
  local tcolour = nil
  local i = 0
  local found = false
  if colour then
    local temp = colour
    while i < 5 do
      if self[temp] then
        temp = self[temp]
      elseif not self[temp] and i > 0 then
        found = true
        break
      end
      i = i + 1
    end
    if temp and found then
      colour = temp
    end
  end
  if colour then
    tcolour = verify_colour(colour, {})
    if tcolour ~= nil and tcolour ~= -1 then
      if return_orig then
        return colour
      else
        return tcolour
      end
    end
  end
  if self.parent then
    colour = self.parent:get_colour(colour, default, return_original)
    if colour then
      return colour
    end
  end
  return default
end

function Phelpobject:onSettingChange(settable)
  if not self.ignorebsetting then
    for i,v in pairs(settable) do
      self:set(i,v)
    end
  end
end
