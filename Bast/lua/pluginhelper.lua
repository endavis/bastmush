-- $Id$
--[[
http://code.google.com/p/bastmush
 - Documentation and examples

this module will help with setting up plugin commands and variables

requires the verify module

adding an option looks like this
phelper:add_option('plotlength' , {help="set the length of the moon plot", type="number", high=80, low=0, after=styleplotdata, default=66})

valid values in the table are:
  help     -- the help for this option
  type     -- the type of this option, valid are string, bool, colour, number
  default  -- the default value
  high,low -- valid for numbers only, the lowest and highest values for this option
  after    -- the function to run after this option has been set
  sortlev  -- you can group options by setting this, all options with the same number will be printed together
  readonly -- this is a read only variable
  split    -- char to use to split arguments, default is a space

options already included (these do not need to be manually added)
cmd - the cmd for this plugin
plugin_colour - the colour for this plugin
tdebug - the debug variable

to change the defaults for these options
phelper:option_set_default('cmd', 'regen')
phelper:option_set_default('plugin_colour', 'orange')

adding a command looks like this
phelper:add_cmd('plot', {func=plotdata, help="plot moons"})

valid values -
  func     -- the function to call
              the arguments are sent in this order (name, line, wildcards)
              this can be set to nofunc to have this command just be a placeholder
  help     -- the help for this command
              if this is set to "", will not show when the help prints all valid commands
  default  -- set this true and this will be the default cmd
  send_to_world -- set this to pass this to the world

commands already included (these do not need to be manually added)
  help
  set
  reset
  debug
  save

--]]

require "var"
require "tprint"
require "commas"
require "verify"
require "utils"
require "tablefuncs"
require "phelpobject"
require "addxml"
require "stringfuncs"

Pluginhelper = Phelpobject:subclass()

function Pluginhelper:initialize(args)
  super(self, args)

  self.send_to_world = false
  self.cmdstuff = {}

  self.pobjects = {}
  self.pobjects_by_id = {}

  self:add_cmd('objects', {func="cmd_objects", help="list objects associated with this plugin"})

  self:add_setting('plugin_colour', {help="set the plugin colour", type="colour", default="lime", sortlev=1})
  self:add_setting('cmd', {help="the command to type for this plugin", type="string", after="set_plugin_alias", default="mb"})

end

function Pluginhelper:cmd_objects()
  self:plugin_header("Objects associated with this plugin")
  for i,v in pairs(self.pobjects) do
    ColourNote(RGBColourToName(var.plugin_colour), "black", i)
  end
  ColourNote("", "", "")
end

function Pluginhelper:run_cmd(cmddict)
  if (cmddict.action == nil or cmddict.action == '') then
    local tcmd = self:find_default_cmd()
    if tcmd == "" then
      self:cmd_help(cmddict)
      return false
    end
    cmddict.action = tcmd
  end

  local splitstr = " "
  tcmddict = parse_cmdline(cmddict.list or '')
  tcmddict.line = cmddict.line
  tcmddict.action = cmddict.action

  self:mdebug('tcmddict after parse_cmdline', tcmddict)
  retcode = super(self, tcmddict, true)

  if not retcode then

    local pobj = self.pobjects[cmddict.action]
    if pobj ~= nil then
      tcmddict.action = tcmddict[1]
      table.remove(tcmddict, 1)
      pobj:run_cmd(tcmddict)
    else
      ColourNote("", "", "")
      ColourNote("white", "black", "That is not a valid command")
      self:cmd_help(cmddict)
      return false
    end
  else
--  if cmd.send_to_world then
--    SendNoEcho(self.cmdstuff.line)
--  end
    return true
  end

  return false
end

function Pluginhelper:plugin_header(header)
  header = header or ""
  ColourNote("", "", "")
  ColourNote(RGBColourToName(var.plugin_colour), "black", GetPluginInfo(GetPluginID (),1) .. " ",
             RGBColourToName(var.plugin_colour), "black", "v" .. GetPluginInfo(GetPluginID (),19) .. " ",
             "white", "black", header)
  ColourNote("white", "black", "-----------------------------------------------")
end

function Pluginhelper:enable()
  super(self)
  addxml.alias {    match = "nothing",
                    script = "plugin_parse_helper",
                    name = "plugin_parse",
                    regexp = true,
                    enabled = true,
                    ignore_case = true,
                    sequence = 110,
                    expand_variables = true
               }
  self:init_vars()
end

function Pluginhelper:set_plugin_alias()
  --[[
    this will change the command used for your plugin in the plugin_parse alias
    the first word will be the action to take, the rest will be arguments to that action
  --]]
  --match="^(shortcmd|longcmd)(:|\\s+|$)((?<action>[+\\-A-za-z0-9]*)\\s*)?(?<list>[\\+\\-A-Za-z0-9, :_#]+)?$"
  match="^(cmdstring)(:|\\s+|$)((?<action>[+\\-A-za-z0-9]*)\\s*)?(?<list>.+)?$"
  match, n = string.gsub (match, "cmdstring", self.cmd or "")
  SetAliasOption ("plugin_parse", "match", match)
  DoAfterSpecial (10, 'BroadcastPlugin (1001)', sendto.script)
end

function Pluginhelper:reset(cmddict)
  super(cmddict)
  for i,v in pairs(self.pobjects) do
    v:init_vars(true)
  end
  self:plugin_header()
  ColourNote(RGBColourToName(var.plugin_colour), "black", "Plugin options reset ")
  ColourNote("", "", "")
end

function Pluginhelper:find_default_cmd()
  for tcmd,cmditem in pairs(self.cmds_table) do
    if cmditem.default then
      return tcmd
    end
  end
  return ""
end

function Pluginhelper:set(option, value, args)
  if args == nil then
    args = {}
  end
  args.putvar = true
  retcode = super(self, option, value, args)
  return retcode
end

function Pluginhelper:find_pobject(object)
-- Function to find a pobject by name or id
  if self.pobjects[object] then
    return self.pobjects[object]
  elseif self.pobjects_by_id[object] then
    return self.pobjects_by_id[object]
  end
  return nil
end

function Pluginhelper:add_pobject(name, object)
 if object == nil then
   print(name, "is nil in add_pobject")
   return
 end
 self.pobjects[object.cname] = object
 self.pobjects_by_id[object.id] = object
end

function Pluginhelper:set_send_to_world(tf)
  self.send_to_world = tf
end

function Pluginhelper:mousedown(flags, hotspotid)
  object_id, hotspotid = fix_hotspotid(hotspotid)
  self.pobjects_by_id[object_id]:mousedown(flags, hotspotid)
end

function Pluginhelper:cancelmousedown(flags, hotspotid)
  object_id, hotspotid = fix_hotspotid(hotspotid)
  self.pobjects_by_id[object_id]:cancelmousedown(flags, hotspotid)
end

function Pluginhelper:mouseover(flags, hotspotid)
  object_id, hotspotid = fix_hotspotid(hotspotid)
  self.pobjects_by_id[object_id]:mouseover(flags, hotspotid)
end

function Pluginhelper:cancelmouseover(flags, hotspotid)
  object_id, hotspotid = fix_hotspotid(hotspotid)
  self.pobjects_by_id[object_id]:cancelmouseover(flags, hotspotid)
end

function Pluginhelper:mouseup(flags, hotspotid)
  object_id, hotspotid = fix_hotspotid(hotspotid)
  self.pobjects_by_id[object_id]:mouseup(flags, hotspotid)
end

function Pluginhelper:dragmove(flags, hotspotid)
  object_id, hotspotid = fix_hotspotid(hotspotid)
  self.pobjects_by_id[object_id]:dragmove(flags, hotspotid)
end -- dragmove

function Pluginhelper:dragrelease(flags, hotspotid)
  object_id, hotspotid = fix_hotspotid(hotspotid)
  self.pobjects_by_id[object_id]:dragrelease(flags, hotspotid)
end

function Pluginhelper:OnPluginBroadcast(msg, id, name, text)
--  mdebug('OnPluginBroadcast')
  if id == "eee96e233d11e6910f1d9e8e" and msg == -2 then
    for i,v in pairs(self.pobjects) do
      if not v.disabled then
        v:tabbroadcast(true)
      end
    end
  end
end

--function Pluginhelper:__newindex(name, val)
--  super(self, name, val)
--end

function Pluginhelper:OnPluginInstall()
  self:mdebug('OnPluginInstall')
  if GetVariable ("enabled") == "false" then
    ColourNote ("yellow", "", "Warning: Plugin " .. GetPluginName ().. " is currently disabled.")
    check (EnablePlugin(GetPluginID (), false))
    return
  end -- they didn't enable us last time

  OnPluginEnable ()  -- do initialization stuff
end

function Pluginhelper:OnPluginClose()
  self:mdebug('OnPluginClose')

  OnPluginDisable()
end

function Pluginhelper:OnPluginEnable()
  self:mdebug('OnPluginEnable')
  -- if we are connected when the plugin loads, it must have been reloaded whilst playing
  for i,v in pairs(self.pobjects) do
    if not v.disabled then
      v:init(true)
    end
  end
  if IsConnected () then
    OnPluginConnect ()
  end -- if already connected
  self:broadcast(-2)
end

function Pluginhelper:OnPluginDisable()
  self:mdebug('OnPluginDisable')
  if IsConnected() then
    OnPluginDisconnect()
  end
    for i,v in pairs(self.pobjects) do
      if not v.disabled then
        v:shutdown(true)
      end
    end
  self:broadcast(-1)
end

function Pluginhelper:OnPluginConnect()
  self:mdebug('OnPluginConnect')

end

function Pluginhelper:OnPluginDisconnect()
  self:mdebug('OnPluginDisConnect')

end

function Pluginhelper:OnPluginSaveState()
  self:mdebug('OnPluginSaveState')
  --[[
     save all the vars in the options table, requires the "var" module
  --]]
  self:savestate(true)
  SetVariable ("enabled", tostring (GetPluginInfo (GetPluginID (), 17)))
  for i,v in pairs(self.pobjects) do
    if not v.disabled then
      v:savestate(true)
    end
  end

end

function do_cmd()
  phelper:run_cmd(phelper.cmdstuff)
end

function parse_cmdline(cmdline)
  re = rex.new ("[^\\s\"']+|\"([^\"]*)\"|'([^']*)'")

  rtable = {}

  function f (m, t)
    newstring, found = string.gsub(m, "^['\"](.-)['\"]$", "%1")
    table.insert(rtable, newstring)
  end

  -- match regular expression to a string

  re:gmatch (cmdline, f)

  return rtable
end

function plugin_parse_helper(name, line, wildcards)
  --[[
    find the command that was specified and pass arguments to it
  --]]

  phelper.cmdstuff.action = wildcards.action
  phelper.cmdstuff.line = line
  phelper.cmdstuff.list = wildcards.list
  DoAfterSpecial (.1, 'do_cmd()', sendto.script)

end

function nofunc(name, line, wildcards)
  return true
end

function SecondsToDHMS(sSeconds)
  local nSeconds = tonumber(sSeconds)
  if nSeconds == 0 then
    return 0, 0, 0, 0
  else
    nDays = math.floor(nSeconds/(3600 * 24))
    nHours = math.floor(nSeconds/3600 - (nDays * 24))
    nMins = math.floor(nSeconds/60 - (nHours * 60) - (nDays * 24 * 60))
    nSecs = sSeconds % 60
    return nDays, nHours, nMins, nSecs
  end
end

function convert_ticks(ticks)
  --string.format ("Time to go: %sd %sh %sm ", cptimer.days, cptimer.hours, cptimer.mins)
  tout = {}
  seconds = (ticks / 2) * 60
  tout.days, tout.hours, tout.mins, tout.secs = SecondsToDHMS(seconds)
  tstring = {}
  if tout.days ~= 0 then
    table.insert(tstring, string.format('%sd', tostring(tout.days)))
    table.insert(tstring, string.format('%sh', tostring(tout.hours)))
    table.insert(tstring, string.format('%sm', tostring(tout.mins)))
    if tout.secs ~= 0 then
      table.insert(tstring, string.format('%ss', tostring(tout.secs)))
    end
  elseif tout.hours ~= 0 then
    table.insert(tstring, string.format('%sh', tostring(tout.hours)))
    table.insert(tstring, string.format('%sm', tostring(tout.mins)))
    if tout.secs ~= 0 then
      table.insert(tstring, string.format('%ss', tostring(tout.secs)))
    end
  elseif tout.mins ~= 0 then
    table.insert(tstring, string.format('%sm', tostring(tout.mins)))
    if tout.secs ~= 0 then
      table.insert(tstring, string.format('%ss', tostring(tout.secs)))
    end
  elseif tout.secs ~= 0 then
    table.insert(tstring, string.format('%ss', tostring(tout.secs)))
  end
  tout.string = strjoin(':', tstring)
  return tout
end

function mousedown(flags, hotspotid)
  phelper:mousedown(flags, hotspotid)
end

function cancelmousedown(flags, hotspotid)
  phelper:cancelmousedown(flags, hotspotid)
end

function mouseover(flags, hotspotid)
  phelper:mouseover(flags, hotspotid)
end

function cancelmouseover(flags, hotspotid)
  phelper:cancelmouseover(flags, hotspotid)
end

function mouseup(flags, hotspotid)
  phelper:mouseup(flags, hotspotid)
end

function dragmove(flags, hotspotid)
  phelper:dragmove(flags, hotspotid)
end -- dragmove

function dragrelease(flags, hotspotid)
  phelper:dragrelease(flags, hotspotid)
end

function fix_hotspotid(hotspotid)
  _place = string.find(hotspotid, ':')
  return string.sub(hotspotid, 0, _place - 1), string.sub(hotspotid, _place + 1)
end

phelper = Pluginhelper:new{name='phelp'}

