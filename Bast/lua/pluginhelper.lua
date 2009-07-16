-- $Id$
--[[
http://code.google.com/p/bastmush
 - Documentation and examples

this module will help with setting up plugin commands and variables

requires the verify module

adding an option looks like this
add_option('plotlength' , {help="set the length of the moon plot", type="number", high=80, low=0, after=styleplotdata, default=66})

valid values in the table are:
  help     -- the help for this option
  type     -- the type of this option, valid are string, bool, colour, number
  default  -- the default value
  high,low -- valid for numbers only, the lowest and highest values for this option
  after    -- the function to run after this option has been set
  sortlev  -- you can group options by setting this, all options with the same number will be printed together
  readonly -- this is a read only variable

options already included (these do not need to be manually added)
cmd - the cmd for this plugin
plugin_colour - the colour for this plugin
tdebug - the debug variable

to change the defaults for these options
option_set_default('cmd', 'regen')
option_set_default('plugin_colour', 'orange')

adding a command looks like this
add_cmd('plot', {func=plotdata, help="plot moons"})

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

require "tprint"
require "commas"
require "verify"
require "utils"

window = nil
send_to_world = false

function set_plugin_alias()
  --[[
    this will change the command used for your plugin in the plugin_parse alias
    the first word will be the action to take, the rest will be arguments to that action
  --]]
  --match="^(shortcmd|longcmd)(:|\\s+|$)((?<action>[+\\-A-za-z0-9]*)\\s*)?(?<list>[\\+\\-A-Za-z0-9, :_#]+)?$"
  match="^(cmdstring)(:|\\s+|$)((?<action>[+\\-A-za-z0-9]*)\\s*)?(?<list>.+)?$"
  match, n = string.gsub (match, "cmdstring", var.cmd or "")
  SetAliasOption ("plugin_parse", "match", match)
  DoAfterSpecial (10, 'BroadcastPlugin (1001)', sendto.script)
end

function plugin_header(header)
  header = header or ""
  ColourNote("", "", "")
  ColourNote(RGBColourToName(var.plugin_colour), "black", GetPluginInfo(GetPluginID (),1) .. " ",
             RGBColourToName(var.plugin_colour), "black", GetPluginInfo(GetPluginID (),19) .. " ",
             "white", "black", header)
  ColourNote("white", "black", "-----------------------------------------------")
end

function plugin_help_helper(name, line, wildcards)
  --[[
    this function prints a help table for cmds_table
  --]]
  plugin_header("Commands")

  for i,v in pairs(cmds_table) do
    if v.help ~= '' then
      ColourNote( "white", "black", string.format("%-15s", i),
              RGBColourToName(var.plugin_colour),  "black", ": " .. v.help )
    end
  end
  ColourNote( "", "", "")

end

function print_setting_helper(setting, value, help, ttype, readonly)
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
  ColourNote( "white", "black", string.format("%-20s : ", setting),
              RGBColourToName(colour), "black", string.format("%-20s", tostring(value)),
              "white", "black", " - " .. help)
end

function print_settings_helper(ttype)
  --[[
    this function goes through the setoptions table and the window and prints each setting
  --]]
  plugin_header("Settings")
  if ttype == "plugin" or ttype == "all" then
    skeys = sort_settings(options_table)
    for _,v in ipairs(skeys) do
      local soption = find_option(v)
      if soption.get then
        value = soption.get(v)
      else
        value = var[v]
      end
      print_setting_helper(v, value, soption.help, soption.type, soption.readonly)
    end
  end
  if ttype == "window" or ttype == "all" then
    if window then
      window:print_settings()
    end
  end
  ColourNote("", "", "")
end

function plugin_reset(name, line, wildcards)
  if not wildcards.list then
    print_settings_helper("plugin")
    return
  end
  plugin_header()
  local tvar = utils.split(wildcards.list, " ")
  local ttype = tvar[1]
  if ttype == "plugin" or ttype == "all" then
    init_plugin_vars(true)
    ColourNote(RGBColourToName(var.plugin_colour), "black", "Plugin options reset ")
  end
  if ttype == "window" or ttype == "all" then
    if window then
      window:reset()
    end
    ColourNote(RGBColourToName(var.plugin_colour), "black", "Window options reset ")
  end
  ColourNote("", "", "")
end


function plugin_toggle_debug(name, line, wildcards)
  toption = options_table["tdebug"]
  if var.tdebug == "true" then
    set_var("false", "tdebug", toption.type, {low=toption.low, high=toption.high})
  else
    set_var("true", "tdebug", toption.type, {low=toption.low, high=toption.high})
  end
end

function plugin_set_helper(name, line, wildcards)
  --[[
    this function will attempt to set an item in the options_table table or in a window
  --]]
  local function nooption()
    ColourNote("", "", "")
    ColourNote("white", "black", "That is not a valid setting")
    print_settings_helper("all")
  end

  if not wildcards.list then
    print_settings_helper("plugin")
    return
  end
  local tvar = utils.split(wildcards.list, " ")
  local option = tvar[1]
  if option ~= nil then
    option = trim(option)
  end
  if option == "all" or option == "window" then
    print_settings_helper(option)
    return
  end
  table.remove(tvar, 1)
  local value = table.concat(tvar, " ")
  if value ~= nil then
    value = trim(value)
  end
  if not option then
    nooption()
    return false
  else
    local soption = find_option(option)
    if soption and soption.readonly then
      plugin_header()
      ColourNote(RGBColourToName(var.plugin_colour), "", "That is a read-only var")
      return true
    end
    if not soption then
      if window and window:set(option, value, false) then
         return true
      else
         nooption()
         return false
      end
    end
    if value == 'default' then
      value = soption.default
    end
    f = soption.func
    if not f then
      f = set_var
    end
    test = f(value, option, soption.type, {low=soption.low, high=soption.high})
    if test == nil then
      return false
    end
    afterf = soption.after
    if afterf then
      afterf()
    end
    SaveState()
    return true
  end
end


function find_option(option)
  soption = options_table[option]
  return soption
end

function add_cmd(name, stuff)
  if not cmds_table[name] then
    cmds_table[name] = stuff
  else
    print("cmd", name, "already exists")
  end
end

function find_cmd(cmd)
  --[[
    find the cmd in the cmds and default_cmds tables
  --]]
  cmd = string.lower(cmd)
  if cmds_table[cmd] then
    return cmd, cmds_table[cmd]
  end
  fcmd = "^" .. cmd .. ".*$"
  for tcmd,cmditem in pairs(cmds_table) do
    tstart, tend =  string.find(string.lower(tcmd), fcmd)
    if tstart and tstart > 0 then
      return tcmd, cmds_table[tcmd]
    end
  end

  return nil, nil

end

function do_cmd(tcmd, name, line, wildcards)
  local ran = false
  fullcmd, cmd = find_cmd(tcmd)
  if cmd == nil then
    if send_to_world then
      SendNoEcho(line)
      return true
    else
      ColourNote("", "", "")
      ColourNote("white", "black", "That is not a valid command")
      do_cmd("help", name, line, wildcards)
    end
    return false
  end

  if not cmd.func then
    ColourNote("red", "", "The function for command " .. fullcmd .. " is invalid, please check plugin")
    return false
  end
  if cmd.func (name, line, wildcards) then
    ran = true
  end -- all done
  if cmd.send_to_world then
    SendNoEcho(line)
  end
  return ran
end

function plugin_parse_helper(name, line, wildcards)
  --[[
    find the command that was specified and pass arguments to it
  --]]
  if wildcards.action == "" then
    for tcmd,cmditem in pairs(cmds_table) do
      if cmditem.default then
        wildcards.action = tcmd
        break
      end
    end
    if wildcards.action == "" then
      do_cmd("help", name, line, wildcards)
      return true
    end
  end

  return do_cmd(wildcards.action, name, line, wildcards)
end

function set_var(value, option, type, args)
  --[[
     set a variable in a plugin, requires the "var" module
  --]]
  local tvalue = verify(value, type, args)
  if tvalue == nil then
    ColourNote("red", "black", "That is not a valid value.")
    return nil
  end
  plugin_header("Settings")
  if type == "colour" then
    colourname = RGBColourToName(tvalue)
    ColourNote("orange", "black", option .. " set to : ",
             colourname, "black", colourname)
  else
    colourname = RGBColourToName(var.plugin_colour)
    ColourNote("orange", "black", option .. " set to : ",
             colourname, "black", tostring(tvalue))
  end
  ColourNote("", "", "")
  var[option]= tvalue
  return true
end

function add_option(name, stuff)
  if not options_table[name] then
    options_table[name] = stuff
  else
    print("option", name, "already exists")
  end
end

function init_plugin_vars(reset)
  --[[
    initialize all variables in the options_table, requires "var" module
  --]]
  for i,v in pairs(options_table) do
    local tvalue = nil
    if reset then
      tvalue = v.default
    else
      tvalue = GetVariable(i) or v.default
    end
    tvalue = verify(tvalue, v.type, {low=v.low, high=v.high, silent=true})
    var[i] = tvalue
    afterf = v.after
    if afterf then
      afterf()
    end
  end
end

function sort_settings(toptions_table)
  --[[
     sort the keys of the options table
  --]]
  local function sortfunc (a, b)
    asortlev = toptions_table[a].sortlev or 50
    bsortlev = toptions_table[b].sortlev or 50
    return (asortlev < bsortlev)
  end


  local t2 = {}
  if toptions_table then
    for i,v in pairs(toptions_table) do
      table.insert(t2, i)
    end
  end
  table.sort(t2, sortfunc)

  return t2

end

function send_cmd_world(name, line, wildcards)
   SendNoEcho(line)
end

function togglewindow(name, line, wildcards)
  if window ~= nil then
    window:toggle(window)
  end
end

function nofunc(name, line, wildcards)
  return true
end

function broadcast(num, data, broadcastdata)
  if var.tdebug == "true" then
    print(GetPluginInfo (GetPluginID (), 1), ": Broadcast", num)
    if data then
      print(data)
    end
    print("")
  end
  BroadcastPlugin(tonumber(num), broadcastdata)
end

function enabletriggroup(group, flag)
  if EnableTriggerGroup (group, flag) == 0 then
    if flag then
      print("no triggers to enable for group", group)
    else
      print("no triggers to disable for group", group)
    end
    print("")
  end
end

function mdebug(...)
  if var.tdebug == "true" then
    print(GetPluginInfo (GetPluginID (), 1), ": Debug")
    local tstring = {}
    for n=1,select('#',...) do
      local e = select(n,...)
      if type(e) == 'table' then
        if #tstring > 0 then
          print(unpack(tstring))
          tstring = nil
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


function SecondsToDHMS(sSeconds)
  local nSeconds = tonumber(sSeconds)
  if nSeconds == 0 then
    return "00:00:00"
  else
    nDays = math.floor(nSeconds/(3600 * 24))
    nHours = math.floor(nSeconds/3600 - (nDays * 24))
    nMins = math.floor(nSeconds/60 - (nHours * 60) - (nDays * 24 * 60))
    nSecs = sSeconds % 60
    return nDays, nHours, nMins, nSecs
  end
end

function window_set(twindow)
  window = twindow
  add_cmd('toggle', {func=togglewindow, help="toggle the miniwindow"})
end

function option_set_default(opname, opdef)
  options_table[opname].default = opdef
end

function cmd_update(cmd, key, value)
  cmds_table[cmd][key] = value
end

function set_send_to_world(tf)
  send_to_world = tf
end

function mousedown(flags, hotspotid)
  window:mousedown(flags, hotspotid)
end

function dragmove(flags, hotspot_id)
  window:dragmove(flags, hotspot_id)
end -- dragmove

function dragrelease(flags, hotspot_id)
  window:dragrelease(flags, hotspot_id)
end

function PluginhelperOnPluginBroadcast(msg, id, name, text)
--  mdebug('OnPluginBroadcast')
  if id == "eee96e233d11e6910f1d9e8e" and msg == -2 then
    if window then
      window:tabbroadcast(true)
    end
  end
end

function PluginhelperOnPluginInstall()
  mdebug('OnPluginInstall')
  if GetVariable ("enabled") == "false" then
    ColourNote ("yellow", "", "Warning: Plugin " .. GetPluginName ().. " is currently disabled.")
    check (EnablePlugin(GetPluginID (), false))
    return
  end -- they didn't enable us last time

  OnPluginEnable ()  -- do initialization stuff
end

function PluginhelperOnPluginClose()
  mdebug('OnPluginClose')

  OnPluginDisable()
end

function PluginhelperOnPluginEnable()
  mdebug('OnPluginEnable')
  -- if we are connected when the plugin loads, it must have been reloaded whilst playing
  if IsConnected () then
    OnPluginConnect ()
  end -- if already connected
  if window then
    window:init()
  end
  broadcast(-2)
end

function PluginhelperOnPluginDisable()
  mdebug('OnPluginDisable')
  if IsConnected() then
    OnPluginDisconnect()
  end
  if window then
    window:shutdown()
  end
  broadcast(-1)
end

function PluginhelperOnPluginConnect()
  mdebug('OnPluginConnect')

end

function PluginhelperOnPluginDisconnect()
  mdebug('OnPluginDisConnect')

end

function PluginhelperOnPluginSaveState()
  mdebug('OnPluginSaveState')
  --[[
     save all the vars in the options table, requires the "var" module
  --]]
  for i,v in pairs(options_table) do
    SetVariable (i, tostring(var[i]))
  end
  SetVariable ("enabled", tostring (GetPluginInfo (GetPluginID (), 17)))
  if window then
    window:savestate()
  end
end

cmds_table = {
  help      = {func=plugin_help_helper, help="show help"},
  debug      = {func=plugin_toggle_debug, help="toggle debugging"},
  set       = {func=plugin_set_helper, help="set script and window vars, show plugin vars when called with no arguments, 'window': show window vars, 'all': show all vars"},
  reset     = {func=plugin_reset, help="reset plugin to default values, 'all': both miniwin and plugin, 'win': just miniwin, 'plugin': just plugin"},
  save     = {func=PluginhelperOnPluginSaveState, help="save plugin variables"},
}

options_table = {
  plugin_colour = {help="set the plugin colour", type="colour", default="lime"},
  tdebug = {help="toggle this for debugging info", type="bool", default=false},
  cmd = {help="the command to type for this plugin", type="string", after=set_plugin_alias, default="mb"},
}

