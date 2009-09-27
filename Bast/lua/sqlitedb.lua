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

function Sqlitedb:open()
  --phelper:mdebug('open - conns:', self.conns)
  if self.db == nil then
    --phelper:mdebug("opening db")
    print('db dir', self.dbloc)
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
  --phelper:mdebug('close - conns:', self.conns)
  if self.db ~= nil and self.conns == 0 then
    --phelper:mdebug("closing db")
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
