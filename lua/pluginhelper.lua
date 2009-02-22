-- $Id$
--[[
http://code.google.com/p/bastmush
 - Documentation and examples
 
this module will help with setting up plugin commands and variables

requires the verify module

an option table looks like this
options_table  = {
  plotlength = {help="set the length of the moon plot", type="number", high=80, low=0, after=styleplotdata, default=66},
  plugin_colour = {help="set the plugin colour", type="colour", default="lime"},
  tickgag = {help="toggle gagging the tick", type="bool", after=check_tickgag,default=false},
  shortcmd = {help="the short command for this plugin", type="string", after=set_plugin_alias, default="mb"},
  longcmd = {help="the long command for this plugin", type="string", after=set_plugin_alias, default="moonbot"},
  three_colour = {help="the colour for the when three moons are up", type="colour", default=verify_colour("gold"), sortlev=2}  
}
valid values:
  help     -- the help for this option
  type     -- the type of this option, valid are string, bool, colour, number
  default  -- the default value
  high,low -- valid for numbers only, the lowest and highest values for this option
  after    -- the function to run after this option has been set
  sortlev  -- you can group options by setting this, all options with the same number will be printed together
NOTE: the plugin_colour, shortcmd, and longcmd options are required!!  
  
a command table looks like this
cmds_table = {
  plot      = {func=plotdata, help="plot moons"},
  union     = {func=moonbot_union, help="show next moons union"}, 
  print     = {func=printmoons, help="print the current moon phase #s"},
  toggle    = {func=togglewindow, help="toggle the moons miniwindow"}, 
  reset     = {func=moonbot_reset, help="reset the moons"},
}
valid values -
  func     -- the function to call 
              the arguments are sent in this order (name, line, wildcards, cmds_table, options_table, window)
  help     -- the help for this command

--]]

require "tprint"
require "commas"
require "verify"
require "utils"


function set_plugin_alias()
  --[[
    this will change the command used for your plugin in the plugin_parse alias
    the first word will be the action to take, the rest will be arguments to that action
  --]]
  --match="^(shortcmd|longcmd)(:|\\s+|$)((?<action>[+\\-A-za-z0-9]*)\\s*)?(?<list>[\\+\\-A-Za-z0-9, :_#]+)?$"
  match="^(shortcmd|longcmd)(:|\\s+|$)((?<action>[+\\-A-za-z0-9]*)\\s*)?(?<list>.+)?$"
  match, n = string.gsub (match, "shortcmd", var.shortcmd or "")
  match, n = string.gsub (match, "longcmd", var.longcmd or "")
  SetAliasOption ("plugin_parse", "match", match)
  if var.shortcmd and var.longcmd then
    BroadcastPlugin(1001)  
  end
end

function plugin_help_helper(name, line, wildcards, cmds_table, options_table, window, send_to_world)
  --[[
    this function prints a help table for cmds_table
  --]]
  ColourNote("", "", "")
  ColourNote( RGBColourToName(var.plugin_colour),  "black", GetPluginName() .. " ",
              RGBColourToName(var.plugin_colour),  "black", tostring(GetPluginInfo (GetPluginID(), 19)),
              "white", "black", " Options" )
  ColourNote( RGBColourToName(var.plugin_colour),  "black", var.longcmd .. " may be abbreviated as " .. var.shortcmd )
  ColourNote("white", "black", "-----------------------------------------------")
             
  for i,v in pairs(cmds_table) do
    if v.help ~= '' then
      ColourNote( "white", "black", string.format("%-15s", i),
              RGBColourToName(var.plugin_colour),  "black", ": " .. v.help )
    end
  end
  for i,v in pairs(default_cmds_table) do
    if v.help ~= '' then
      ColourNote( "white", "black", string.format("%-15s", i),
             RGBColourToName(var.plugin_colour),  "black", ": " .. v.help )
    end
  end
  ColourNote( "", "", "")
  if send_to_world then
    SendNoEcho(line)
  end
  
end

function print_setting_helper(setting, value, help, ttype)
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
  ColourNote( "white", "black", string.format("%-20s : ", setting),
              RGBColourToName(colour), "black", string.format("%-20s", value),
              "white", "black", " - " .. help)
end

function print_settings_helper(ttype, options_table, window)
  --[[
    this function goes through the setoptions table and the window and prints each setting
  --]]
  ColourNote("", "", "")    
  ColourNote(RGBColourToName(var.plugin_colour), "black", GetPluginInfo(GetPluginID (),1) .. " ",
             RGBColourToName(var.plugin_colour), "black", GetPluginInfo(GetPluginID (),19) ,
             "white", "black", " Settings")    
  ColourNote("white", "black", "-----------------------------------------------")
  if ttype == "plugin" or ttype == "all" then
    skeys = sort_settings(options_table)  
    for _,v in ipairs(skeys) do  
      if options_table[v].get then
        value = options_table[v].get(v)
      else
        value = var[v]
      end    
      print_setting_helper(v, value, options_table[v].help, options_table[v].type)
    end
  end
  if ttype == "window" or ttype == "all" then
    if window then
      window:print_settings()
    end  
  end
  ColourNote("", "", "")
end

function plugin_set_helper(name, line, wildcards, cmds_table, options_table, window)
  --[[
    this function will attempt to set an item in the options_table table or in a window
  --]]
  local function nooption()
    ColourNote("", "", "")
    ColourNote("white", "black", "That is not a valid setting")
    print_settings_helper("all", options_table, window)
  end
  
  if not wildcards.list then
    print_settings_helper("plugin", options_table, window)
    return
  end
  local tvar = utils.split(wildcards.list, " ")
  local option = tvar[1]
  if option ~= nil then
    option = trim(option)
  end
  if option == "all" or option == "window" then
    print_settings_helper(option, options_table, window)
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
    local soption = options_table[option]
    if not soption then
      if window and window:set(option, value) then
         return true
      else
         nooption()
         return false 
      end
    end
    f = soption.func
    if not f then
      f = set_var
    end
    test = f(value, option, options_table[option].type, {low=options_table[option].low, high=options_table[option].high})  
    if test == nil then
      return false
    end    
    afterf = options_table[option].after
    if afterf then
      afterf()
    end
    return true
  end
end

default_cmds_table = {
  help      = {func=plugin_help_helper, help="show help"},
  set       = {func=plugin_set_helper, help="set script and window vars, show plugin vars when called with no arguments, 'window': show window vars, 'all': show all vars"},
}

function find_cmd(cmd, cmds_table)
  --[[
    find the cmd in the cmds and default_cmds tables
  --]]
  cmd = string.lower(cmd)
  if cmds_table[cmd] then
    return cmd, cmds_table[cmd]
  end
  if default_cmds_table[cmd] then
    return cmd, default_cmds_table[cmd]
  end
  fcmd = "^" .. cmd .. ".*$"
  for tcmd,cmditem in pairs(cmds_table) do
    tstart, tend =  string.find(string.lower(tcmd), fcmd)
    if tstart and tstart > 0 then
      return tcmd, cmds_table[tcmd]
    end
  end
  for tcmd,cmditem in pairs(default_cmds_table) do
    tstart, tend =  string.find(string.lower(tcmd), fcmd)
    if tstart and tstart > 0 then
      return tcmd, default_cmds_table[tcmd]
    end
  end
  
  return nil, nil

end

function plugin_parse_helper(name, line, wildcards, cmds_table, options_table, window, send_to_world)
  --[[
    find the command that was specified and pass arguments to it
  --]]
  if wildcards.action == "" then
    plugin_help_helper(name, line, wildcards, cmds_table, options_table, window, send_to_world) 
    return true
  else
    fullcmd, cmd = find_cmd(wildcards.action, cmds_table)
    if cmd == nil then
      if send_to_world then
        SendNoEcho(line)
        return false
      end
      ColourNote("", "", "") 
      ColourNote("white", "black", "That is not a valid option")
      plugin_help_helper(name, line, wildcards, cmds_table, options_table, window, send_to_world)
      return
    end


    if not cmd.func then
      ColourNote("red", "", "The function for command " .. fullcmd .. " is invalid, please check plugin")
      return false
    end
    if cmd.func (name, line, wildcards, cmds_table, options_table, window, send_to_world) then
      return true
    end -- all done
  end
  return false
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
  if type == "colour" then
    colourname = RGBColourToName(tvalue)
    ColourNote("orange", "black", option .. " set to : ",
             colourname, "black", colourname)    
  else
    colourname = RGBColourToName(var.plugin_colour)
    ColourNote("orange", "black", option .. " set to : ",
             colourname, "black", tostring(tvalue))
  end
  var[option]= tvalue
end

function init_plugin_vars(options_table)
  --[[
    initialize all variables in the options table, requires "var" module
  --]]
  for i,v in pairs(options_table) do
    local tvalue = GetVariable(i) or v.default
    tvalue = verify(tvalue, v.type, {low=v.low, high=v.high, silent=true}) 
    var[i] = tvalue
    afterf = v.after
    if afterf then
      afterf()
    end    
  end
end

function plugin_save_vars(options_table)
  --[[
     save all the vars in the options table, requires the "var" module
  --]]
  for i,v in pairs(options_table) do
    SetVariable (i, tostring(var[i]))
  end
end

function sort_settings(options_table)
  --[[
     sort the keys of the options table
  --]]  
  local function sortfunc (a, b) 
    asortlev = options_table[a].sortlev or 50
    bsortlev = options_table[b].sortlev or 50
    return (asortlev < bsortlev)
  end   


  local t2 = {}
  for i,v in pairs(options_table) do
    table.insert(t2, i)
  end
  table.sort(t2, sortfunc)
  
  return t2

end

function send_cmd_world(name, line, wildcards, cmds_table, options_table, window)
   SendNoEcho(line)
end

function togglewindow(name, line, wildcards, cmds_table, options_table, window)
  if window ~= nil then 
    window:togglewindow(window)
  end
end

function nofunc(name, line, wildcards, cmds_table, options_table, window)
  return true
end
