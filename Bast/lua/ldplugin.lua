-- $Id: pluginhelper.lua 418 2009-06-25 17:53:00Z endavis $
--[[
http://code.google.com/p/bastmush
 - Documentation and examples

this module will load certain plugins

--]]
require "check"

function getcolour(id)
  local colour = GetPluginVariable(id, 'plugin_colour') or var.plugin_colour or "red"
  return RGBColourToName(colour)
end

function reloadplugin(id)
    if id ~= GetPluginID () then
      local status = ReloadPlugin (id)
      if status ~= error_code.eOK then
        ColourNote ("red", "", "Could not reload plugin ID: " ..
                    (id or "unknown") .. ", name: " .. (GetPluginInfo (id, 1) or "unknown"))
        check (status)
        return false
      else
         ColourNote (getcolour(id), "black", "Reloaded plugin " .. GetPluginInfo (id, 1))
      end -- no good
      return true
    end -- not us (we can't be reloadeed)
    return false
end

function reloadallplugins()
  local plugins = GetPluginList() or {}
  for _, p in ipairs (plugins) do
    reloadplugin(p)
  end -- each plugin file
end

function enableplugin(id)
  if id ~=  GetPluginID () then
    if not GetPluginInfo (id, 17) then
      check (EnablePlugin (id, true))
      ColourNote (getcolour(id), "black", "Enabled plugin " .. GetPluginInfo (id, 1))
      return true
    end
    ColourNote (getcolour(id), "black", "Plugin " .. GetPluginInfo (id, 1) .. " already enabled")
    return false
  end -- not us (we must be enabled)
  return false
end -- each plugin file

function enableallplugins()
  local plugins = GetPluginList() or {}
  for _, p in ipairs (plugins) do
    enableplugin(p)
  end -- each plugin file
end

function disableplugin(id)
  if id ~=  GetPluginID () then
    if GetPluginInfo (id, 17) then
      check (EnablePlugin (id, false))
      ColourNote (getcolour(id), "black", "Disabled plugin " .. GetPluginInfo (id, 1))
      return true
    end
    ColourNote (getcolour(id), "black", "Plugin " .. GetPluginInfo (id, 1) .. " already disabled")
    return false
  end -- not us (we must be enabled)
  return false
end -- each plugin file

function disableallplugins()
  local plugins = GetPluginList() or {}
  for _, p in ipairs (plugins) do
    disableplugin(p)
  end -- each plugin file
end

function getidbyfile(file)
  local loadedplugins = GetPluginList() or {}
  for _, p in ipairs (loadedplugins) do
    tfile = GetPluginInfo(p, 6)
    llist = utils.split(tfile, "\\")
    tfile = llist[#llist]
    if string.lower(tfile) == string.lower(file) then
      return p
    end
  end
  return nil
end

function loadfromfile(file)
  if string.find(file, ".xml") == nil then
    file = file .. ".xml"
  end
  id = getidbyfile(file)
  if id ~= nil then
    return id
  else
    LoadPlugin(file)
    id = getidbyfile(file)
    if id ~= nil then
      return id
    else
      return false
    end
  end
end

function ldplugin_helper(plugin, silent)
  silent = silent or false
  local loaded = false
  loaded = loadfromfile(plugin)
  if loaded == false then
    if not silent then
      ColourNote("yellow", "black", "-----------------------------------------------------------------------")
      ColourNote("yellow", "black", GetPluginInfo (GetPluginID (), 1) .. " will not work correctly without " .. plugin)
      ColourNote("yellow", "black", "-----------------------------------------------------------------------")
    else
      ColourNote("yellow", "black", "-----------------------------------------------------------------------")
      ColourNote("yellow", "black", " Could not load " .. plugin)
      ColourNote("yellow", "black", "-----------------------------------------------------------------------")
    end
  end
  penable = GetPluginInfo(loaded, 17)
  if not penable then
    EnablePlugin(loaded, true)
  end
  return loaded
end

function ldplugin(plugin, silent)
  DoAfterSpecial(1, "ldplugin_helper('" .. plugin .. "', " .. tostring(silent) .. ")", 12)
end
