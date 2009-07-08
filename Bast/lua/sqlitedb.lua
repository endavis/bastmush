-- $Id$
require 'class'
require 'tprint'
require 'verify'
require 'pluginhelper'
require 'var'

class "Sqlitedb"

function Sqlitedb:initialize(args)
  self.dbloc = GetPluginVariable ("", "dblocation") or GetInfo(58)
  self.db = nil
  self.dbname = "/stats.db"
  self.conns = 0
end

function Sqlitedb:checkdir()
  if self.dbloc == nil and verify_bool(var.warned) ~= true and GetInfo(227) == 8 then
      var.warned = true
      SaveState()
      ColourNote("red", "black", "---------------------- " .. GetPluginInfo (GetPluginID (), 1) .. " ----------------------")
      ColourNote("red", "black", " please set the dblocation variable in the world")
      ColourNote("red", "black", " to the directory that you would like the db to be saved")
      ColourNote("red", "black", " If this is not changed, then the db will be saved in")
      ColourNote("red", "black", " the log directory which is:")
      ColourNote("red", "black", self.dbloc)
      ColourNote("red", "black", " You will only see this message once per plugin.")
      ColourNote("red", "black", "---------------------- " .. GetPluginInfo (GetPluginID (), 1) .. " ----------------------")
  end
end

function Sqlitedb:open()
  self:checkdir()
  --mdebug('open - conns:', self.conns)
  if self.db == nil then
    --mdebug("opening db")
    self.db = assert(sqlite3.open(self.dbloc .. self.dbname))
  end
  self.conns = self.conns + 1
  return true
end

function Sqlitedb:close()
  self.conns = self.conns - 1
  if self.conns < 0 then
    print("BUG: conns < 0 for db", self.dbname)
  end
  --mdebug('close - conns:', self.conns)
  if self.db ~= nil and self.conns == 0 then
    --mdebug("closing db")
    self.db:close()
    self.db = nil
  end
end

function Sqlitedb:checkfortable(tablename)
  if self:open() then
    for a in self.db:nrows('SELECT * FROM sqlite_master WHERE name = "' .. tablename .. '" AND type = "table"') do
      if a['name'] == tablename then
        self:close()
        return true
      end
    end
    self:close()
  end
  return false
end
