-- $Id$
require 'class'
require 'tprint'
require 'verify'
require 'pluginhelper'

class "Sqlitedb"

function Sqlitedb:initialize(args)
  self.dbloc = GetPluginVariable ("", "dblocation")
  self.db = nil
  self.dbname = "/stats.db"
  self.conns = 0
end

function Sqlitedb:open()
  self.conns = self.conns + 1
  --mdebug('open - conns:', self.conns)
  if self.db == nil then
    --mdebug("opening db")
    self.db = assert(sqlite3.open(self.dbloc .. self.dbname))
  end
end

function Sqlitedb:close()
  self.conns = self.conns - 1
  --mdebug('close - conns:', self.conns)  
  if self.db ~= nil and self.conns == 0 then
    --mdebug("closing db")
    self.db:close()
    self.db = nil
  end
end

function Sqlitedb:checkfortable(tablename)
  for a in self.db:nrows('SELECT name FROM sqlite_master') do
    if a['name'] == tablename then
      return true
    end
  end  
  return false  
end
