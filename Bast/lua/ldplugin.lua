-- ldplugin.lua
-- $Id$
-- this will manipulate mushclient plugins

-- Author: Eric Davis - 1st July 2009

--[[
http://code.google.com/p/bastmush
 - Documentation and examples

this module will load certain plugins

--]]
require "check"
require "findfile"

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

function unloadplugin(id)
    if id ~= GetPluginID () then
      local pname = GetPluginInfo (id, 1)
      local status = UnloadPlugin (id)
      if status ~= error_code.eOK then
        ColourNote ("red", "", "Could not unload plugin ID: " ..
                    (id or "unknown") .. ", name: " .. pname)
        check (status)
        return false
      else
         ColourNote (getcolour(id), "black", "Unloaded plugin " .. tostring(id) .. " (" .. pname .. ")")
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
    local tfile = GetPluginInfo(p, 6)
    local llist = utils.split(tfile, "\\")
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
  local id = getidbyfile(file)
  if id ~= nil then
    return id
  else
    local nfile = scan_dir_for_file (GetInfo(60), file)
    if nfile then
      local retcode = LoadPlugin(nfile)
      if retcode == 0 then
        local id = getidbyfile(file)
        return id
      elseif retcode == ePluginFileNotFound then
        return "Not Found"
      elseif retcode == eProblemsLoadingPlugin then
        return "Problem"
      else
        return false
      end
    else
      return "Not Found"
    end
  end
end

function ldplugin_helper(plugin, id, silent)
  silent = silent or false
  local loaded = false
  if id ~= "" and id ~= nil and id ~= "nil" and IsPluginInstalled(id) then
    return
  end
  loaded = loadfromfile(plugin)
  if loaded == false then
    ColourNote("yellow", "black", "-----------------------------------------------------------------------")
    ColourNote("yellow", "black", " Could not load " .. plugin .. "(" .. id .. ")" )
    ColourNote("yellow", "black", "-----------------------------------------------------------------------")
    return false
  elseif loaded == "Not Found" then
    ColourNote("yellow", "black", "-----------------------------------------------------------------------")
    ColourNote("yellow", "black", " Could not load " .. plugin .. "(" .. id .. ")" .. " because the file was not found")
    ColourNote("yellow", "black", "-----------------------------------------------------------------------")
    return false
  elseif loaded == "Problem" then
    ColourNote("yellow", "black", "-----------------------------------------------------------------------")
    ColourNote("yellow", "black", " Could not load " .. plugin .. "(" .. id .. ")" .. " because of loading problems" )
    ColourNote("yellow", "black", "-----------------------------------------------------------------------")
    return false
  end
  local penable = GetPluginInfo(loaded, 17)
  if not penable then
    EnablePlugin(loaded, true)
  end
  if silent then
    ColourNote("yellow", "black", "-----------------------------------------------------------------------")
    ColourNote("yellow", "black", " Loaded " .. plugin .. "(" .. loaded .. ")" )
    ColourNote("yellow", "black", "-----------------------------------------------------------------------")
  end
  return loaded
end

function ldplugin(plugin, id, silent)
  DoAfterSpecial(.1, "ldplugin_helper('" .. plugin .. "', '" .. tostring(id) .."', " .. tostring(silent) .. ")", 12)
end
