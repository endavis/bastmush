plugin_path = string.match(GetPluginInfo(GetPluginID(), 6), "(.*)\\.*$") .. "\\lua\\"
package.path = plugin_path .. "?;" .. plugin_path .. "?.lua;" .. package.path