plugin_path = string.match(world.GetPluginInfo(world.GetPluginID(), 6), "(.*)\\.*$") .. "\\lua\\"
package.path = plugin_path .. "?;" .. plugin_path .. "?.lua;" .. package.path