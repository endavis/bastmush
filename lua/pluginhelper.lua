-- $Id$

require "tprint"
require "stringfuncs"
require "verify"
require "utils"


function set_plugin_alias()
  --match="^(shortcmd|longcmd)(:|\\s+|$)((?<action>[+\\-A-za-z0-9]*)\\s*)?(?<list>[\\+\\-A-Za-z0-9, :_#]+)?$"
  match="^(shortcmd|longcmd)(:|\\s+|$)((?<action>[+\\-A-za-z0-9]*)\\s*)?(?<list>.+)?$"
  match, n = string.gsub (match, "shortcmd", var.shortcmd or "")
  match, n = string.gsub (match, "longcmd", var.longcmd or "")
  SetAliasOption ("plugin_parse", "match", match)
end

function plugin_help_helper(name, line, wildcards, plugin_options, set_options, window)
  ColourNote("", "", "")
  ColourNote( RGBColourToName(var.plugin_colour),  "black", GetPluginName() .. " ",
              RGBColourToName(var.plugin_colour),  "black", tostring(GetPluginInfo (GetPluginID(), 19)),
              "white", "black", " Options" )
  ColourNote( RGBColourToName(var.plugin_colour),  "black", var.longcmd .. " may be abbreviated as " .. var.shortcmd )
  ColourNote("white", "black", "-----------------------------------------------")
             
  for i,v in pairs(plugin_options) do
     ColourNote( "white", "black", string.format("%-15s", i),
              RGBColourToName(var.plugin_colour),  "black", ": " .. v.help )
  end
  for i,v in pairs(default_options) do
     ColourNote( "white", "black", string.format("%-15s", i),
              RGBColourToName(var.plugin_colour),  "black", ": " .. v.help )
  end
  ColourNote( "", "", "")
end

function print_setting_helper(setting, value, help, ttype)
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

function print_settings_helper(ttype, setoptions, window)
  ColourNote("", "", "")    
  ColourNote(RGBColourToName(var.plugin_colour), "black", GetPluginInfo(GetPluginID (),1) .. " ",
             RGBColourToName(var.plugin_colour), "black", GetPluginInfo(GetPluginID (),19) ,
             "white", "black", " Settings")    
  ColourNote("white", "black", "-----------------------------------------------")
  if ttype == "plugin" or ttype == "all" then
    for i,v in pairs(setoptions) do  
      if v.get then
        value = v.get(i)
      else
        value = var[i]
      end
      print_setting_helper(i, value, v.help, v.type)
    end
  end
  if ttype == "window" or ttype == "all" then
    if window then
      window:print_settings()
    end  
  end
  ColourNote("", "", "")
end

function plugin_set_helper(name, line, wildcards, plugin_options, set_options, window)
  local function nooption()
    ColourNote("", "", "")
    ColourNote("white", "black", "That is not a valid setting")
    print_settings_helper("all", set_options, window)
  end
  
  if not wildcards.list then
    print_settings_helper("plugin", set_options, window)
    return
  end
  local tvar = utils.split(wildcards.list, " ")
  local option = tvar[1]
  if option ~= nil then
    option = strip(option)
  end
  if option == "all" or option == "window" then
    print_settings_helper(option, set_options, window)
    return
  end  
  table.remove(tvar, 1)
  local value = table.concat(tvar, " ")
  --local value = tvar[2]
  if value ~= nil then
    value = strip(value)
  end
  if not option then
    nooption()
    return false
  else
    local soption = set_options[option]
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
    f(value, option, set_options[option].type, {low=set_options[option].low, high=set_options[option].high})  
    afterf = set_options[option].after
    if afterf then
      afterf()
    end
    return true
  end
end

default_options = {
  help      = {func=plugin_help_helper, help="show help"},
  set       = {func=plugin_set_helper, help="set script and window vars, show plugin vars when called with no arguments, 'window': show window vars, 'all': show all vars"},
}

function plugin_parse_helper(name, line, wildcards, plugin_options, set_options, window)
  if wildcards.action == "" then
    plugin_help_helper(name, line, wildcards, plugin_options, set_options)    
  else
    option = wildcards.action
    if not plugin_options[option] and not default_options[option] then 
      ColourNote("", "", "") 
      ColourNote("white", "black", "That is not a valid option")
      plugin_help_helper(name, line, wildcards, plugin_options, set_options, window)
      return
    end

    local f = nil
    if default_options[option] then
       f = default_options [option].func
    else
       f = plugin_options [option].func
    end
    
    if f (name, line, wildcards, plugin_options, set_options, window) then
      return
    end -- all done
  end

end


function set_var(value, option, type, args)
  local tvalue = verify(value, type, args)    
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

function init_plugin_vars(options)
  for i,v in pairs(options) do
    local tvalue = GetVariable(i) or v.default
    tvalue = verify(tvalue, v.type, {low=v.low, high=v.high, silent=true}) 
    var[i] = tvalue
    afterf = v.after
    if afterf then
      afterf()
    end    
  end
end

function plugin_save_vars(options)
  for i,v in pairs(options) do
    SetVariable (i, tostring(var[i]))
  end
end

function sort_settings(settable)

  local function sortfunc (a, b) 
    asortlev = settable[a].sortlev or 50
    bsortlev = settable[b].sortlev or 50
    return (asortlev < bsortlev)
  end   


  local t2 = {}
  for i,v in pairs(settable) do
    table.insert(t2, i)
  end
  table.sort(t2, sortfunc)
  
  return t2

end
