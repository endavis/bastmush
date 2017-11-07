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

function getversion()
  if not local_version then
    checkLocalFile()
  end
  if not local_version then
    local_version = 'Unkn'
  end
  return local_version
end

function checkLocalFile()
    -- open the local version file
    local changesfile = scan_dir_for_file (GetInfo(60), "BastmushChanges.txt")

    if not changesfile then
      return false
    end

    version_file,err = io.open (changesfile, "r")
    if not version_file then -- the file is missing or unreadable
       ErrorMessage = "The file \'BastmushChanges.txt\' appears to be missing or unreadable (this is bad), so the version check cannot proceed.\n\nThe system returned the error:\n"..err.."\n\nYou should download the latest development snapshot from:"
       return false
    end
    --- read the snapshot revision from the third line
    line = version_file:read ("*l") -- read one line
    line = version_file:read ("*l") -- read one line
    line = version_file:read ("*l") -- read one line
    local_version = nil
    if line then -- if we got something
       local_version = tonumber(string.match(line, "r(%d+) snapshot"))
    end
    if not local_version then -- the file is messed up such that the third line doesn't contain "r<###> snapshot"
       ErrorMessage = "The file \'BastmushChanges.txt\' appears to have been modified (this is bad), so the version check cannot proceed. You should download the latest development snapshot from:"
       return false
    end
    version_file:close ()
    return true
end


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

  self.bastmushversion = 'Unkn'
  version = getversion()
  if version then
    self.bastmushversion = version
  end

  self.id = GetPluginID() .. '_' .. self.cname
  self:mdebug('phelpobject __init self.cname', self.cname)
  self.cmds_table = {}
  self.cmds_groups = {}
  self.cmds_groups_sequence = {}
  self.cmds_groups_sequence_lookup = {}
  self.events = {}
  self.registered_events = {}

  self:add_setting( 'tdebug', {type="bool", help="show debugging info for this option", default=verify_bool(false), sortlev=99})
  self:add_setting( 'ignorebsetting', {type="bool", help="ignore setting of options through broadcast", default=verify_bool(false), sortlev=1, longname="Ignore Broadcast Settings", sortlev=99})
  self:add_setting( 'showevents', {type="bool", help="show events", default=verify_bool(false), sortlev=1, longname="Show events", sortlev=99})

  self:add_cmd('help', {func="cmd_help", help="show help", sortgroup='Default', prio=99})
  self:add_cmd('debug', {func="cmd_debug", help="toggle debugging", sortgroup='Default', prio=99})
  self:add_cmd('set', {func="cmd_set", help="set settings", nomenu=true, sortgroup='Default', prio=99})
  self:add_cmd('reset', {func="cmd_reset", help="reset settings to default values", sortgroup='Default', prio=99})
  self:add_cmd('save', {func=SaveState, help="save plugin variables", sortgroup='Default', prio=99})
  self:add_cmd('showvars', {func="cmd_showvars", help="show plugin variables", sortgroup='Default', prio=99})
  self:add_cmd('showevents', {func="cmd_showevents", help="show functions registered for all events", sortgroup='Default', prio=99})

end

-- "registerevent", "' .. tostring(id) .. '", "wearlocchange", "onwearlocchange")'
function Phelpobject:register_remote(id, eventname, callback, now)
  if id ~= GetPluginID() then
    if not self.registered_events[id] then
      self.registered_events[id] = {}
    end
    if not self.registered_events[id][eventname] then
      if now then
        CallPlugin(id, "registerevent", GetPluginID(), eventname, callback)
      else
       local cmd = 'CallPlugin("' .. id .. '", "registerevent", "' .. GetPluginID() .. '", "' .. eventname .. '", "' .. callback .. '")'
       DoAfterSpecial(2, cmd, 12)
      end
    end
    self.registered_events[id][eventname] = {}
    self.registered_events[id][eventname]['callback']= callback
  else
    print('use registerevent for local registration', id, eventname, callback)
  end
end

function Phelpobject:unregister_remote(id, eventname, callback, removeevent)
  if id ~= GetPluginID() then
    if removeevent then
      self.registered_events[id][eventname] = nil
    end

    CallPlugin(id, "unregisterevent", GetPluginID(), eventname, callback)
  else

  end
end

function Phelpobject:reregister_remote(id)
   if self.registered_events[id] ~= nil then
     for eventname,callback in pairs(self.registered_events[id]) do
       --print('registering', id, eventname, callback, 'after 2 seconds')
       local cmd = 'CallPlugin("' .. id .. '", "registerevent", "' .. GetPluginID() .. '", "' .. eventname .. '", "' .. callback.callback .. '")'
       DoAfterSpecial(2, cmd, 12)
     end
   end
end

function Phelpobject:check_registration(id, event, callback)
  if self.registered_events[id] and self.registered_events[id][eventname] then
    return true
  end
  return false
end

function Phelpobject:registerevent(tevent, object, tfunction, plugin)
  if not tfunction then
    print(self.id, 'function does not exist for', tevent)
    return
  end
  if self.events[tevent] == nil then
    self.events[tevent] = {}
  end
  local found = false
  --print('registering', tevent, object, tfunction, plugin)
  for i,v in ipairs(self.events[tevent]) do
    if not object and v.func == tfunction and v.plugin == plugin then
      --print('found an event that already exists')
      found = true
    end
  end
  if not found then
    if not plugin then
      pluginname = 'None'
    else
      pluginname = GetPluginInfo(plugin, 1)
    end
    table.insert(self.events[tevent], {object=object or {}, func=tfunction, plugin=plugin, name=pluginname})
  end
end

function Phelpobject:processevent(tevent, args)
  if self.showevents then
    print(GetPluginInfo(GetPluginID (),1), ' - Processing event: ', tevent)
  end
  if self.events[tevent] == nil then
    return
  end
  for i,v in ipairs(self.events[tevent]) do
    if v.plugin then
      local targs = serialize.save_simple(args)
      targs = string.gsub(targs, '%[%[', '[')
      targs = string.gsub(targs, '%]%]', ']')
      --print('calling', v.plugin, v.func, targs)
      local funcstr = string.format("CallPlugin('%s', '%s', [[%s]])", tostring(v.plugin) ,tostring(v.func), targs)
      --print(funcstr)
      if self.showevents then
        print('Callback: ', funcstr)
      end
      DoAfterSpecial(.1, funcstr, sendto.script)
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
  local option = cmddict[1]
  local value = cmddict[2]
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
  local newvalue = not self.tdebug
  local retcode = self:set('tdebug', not self.tdebug)
  if retcode then
     self:plugin_header()
     local colourname = RGBColourToName(var.plugin_colour)
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
  local varstuff = self.set_options[option]
  local retcode, tvalue = self:checkvalue(option, value)
  if retcode then
    varstuff.default = tvalue
  end
end


function Phelpobject:plugin_header(header)
  local header = header or ""
  ColourNote("", "", "")
  ColourNote(RGBColourToName(var.plugin_colour), "black", GetPluginInfo(GetPluginID (),1) .. " ",
             RGBColourToName(var.plugin_colour), "black", "v" .. tostring(self.bastmushversion).. " " .. self.cname .. " ",
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
  return self.set_options[setting]
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
      if not (type(gvalue) == 'table') then
        local tvalue = loadstring('return ' .. gvalue or "")()
        gvalue = tvalue
      end
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
  self:processevent('enabled', {})
end

function Phelpobject:disable()
  self:savestate()
  self.disabled = true
  self:processevent('disabled', {})
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
  local tvalue = verify(value, varstuff.type, ttable)
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
  local retcode, tvalue = self:checkvalue(option, value, args)
  local varstuff = self.set_options[option]
  if retcode == true then
    self[option] = tvalue
    local afterf = varstuff.after
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
    return true, tvalue
  end
  return false
end

function Phelpobject:set_external(option, value, args)
  local varstuff = self.set_options[option]
  if varstuff.readonly and not self.classinit and value ~= 'default' then
    self:plugin_header()
    ColourNote(RGBColourToName(var.plugin_colour), "", "That is a read-only var")
    ColourNote("", "", "")
    return 1, nil
  end
  local args = args or {}
  local function changedsetting(toption, tvarstuff, cvalue)
      self:plugin_header()
      if tvarstuff.type == "colour" then
        local colourname = RGBColourToName(self:get_colour(cvalue))
        ColourNote("orange", "black", toption .. " set to : ",
              colourname, "black", colourname)
      else
        local colourname = RGBColourToName(var.plugin_colour)
        --local cvalue = value
        if tvarstuff.formatfunc then
          cvalue = formatfunc(cvalue)
        elseif tvarstuff.istable then
          cvalue = serialize.save_simple(cvalue)
        end
        ColourNote("orange", "black", toption .. " set to : ",
              colourname, "black", tostring(cvalue))
      end
      ColourNote("", "", "")
  end
  local retcode, rvalue = self:set(option, value, args)
  if retcode == true then
    changedsetting(option, varstuff, rvalue)
    return true
  end
  return false
end

function Phelpobject:print_settings_helper(ttype)
  --[[
    this function goes through the setoptions table and the window and prints each setting
  --]]
  self:plugin_header("Settings")

  if tableCountKeys(self.set_options, 'sortlev', 99, true) > 0 then
    ColourNote(RGBColourToName(var.plugin_colour), "black", "")
    ColourNote(RGBColourToName(var.plugin_colour), "black", "Specific settings for this plugin")
  end

  local defhelp = false
  for v,t in tableSort(self.set_options, 'sortlev', 50) do

    if t.sortlev == 99 and not defhelp then
      defhelp = true
      ColourNote("", "", "")
      ColourNote(RGBColourToName(var.plugin_colour), "black", "Generic settings for this plugin")
    end
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
  local value = ""
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
    if not stuff.sortgroup then
      stuff.sortgroup = 'Plugin'
    end
    if not stuff.prio then
      stuff.prio = 50
    end
    self.cmds_table[name] = stuff
    if not self.cmds_groups_sequence_lookup[stuff.sortgroup] then
      if stuff.sortgroup == 'Default' then
        self.cmds_groups_sequence[99] = 'Default'
        self.cmds_groups_sequence_lookup['Default'] = 99
      else
        table.insert(self.cmds_groups_sequence, stuff.sortgroup)
        self.cmds_groups_sequence_lookup[stuff.sortgroup] = #self.cmds_groups_sequence
      end
    end
    if not self.cmds_groups[stuff.sortgroup] then
      self.cmds_groups[stuff.sortgroup] = {}
    end
    self.cmds_groups[stuff.sortgroup][name] = {group=stuff.sortgroup, prio=stuff.prio}
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
  local fcmd = "^" .. cmd .. ".*$"
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
    local func = self[tfunc]
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
  if silent == nil then
    silent = false
  end
  if (cmddict.action == nil or cmddict.action == '') and silent == false then
    self:cmd_help(cmddict)
    return false
  end
  local fullcmd, cmd = self:find_cmd(cmddict.action)
--  if fullcmd ~= 'help' and fullcmd ~= 'set' then
--    if self.disabled then
--      self:init(true)
--      self:enable()
--    end
--  end
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
  self:mdebug('enabletriggroup ' .. group .. " - " .. tostring(flag))
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

function Phelpobject:OnPluginBroadcast (msg, id, name, text)

end

function Phelpobject:OnPluginInstall ()
  --OnPluginEnable is automatically called by pluginhelper

end -- OnPluginInstall

function Phelpobject:OnPluginClose ()

end -- OnPluginClose

function Phelpobject:OnPluginEnable ()
  if self.disabled == false then
    self:init(true)
  end
end -- OnPluginEnable

function Phelpobject:OnPluginDisable ()

  if not self.disabled then
    self:shutdown(true)
  end
end -- OnPluginDisable

function Phelpobject:OnPluginConnect ()

end -- function OnPluginConnect

function Phelpobject:OnPluginDisconnect ()

end -- function OnPluginConnect

function Phelpobject:OnPluginSaveState ()
    if not self.disabled then
      self:savestate(true)
    end
end -- function OnPluginSaveState

