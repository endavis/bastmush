-- $Id$

require 'tprint'
require 'verify'
require 'pluginhelper'
require 'var'
require 'stringfuncs'

local Object = require 'objectlua.Object'

Sqlitedb = Object:subclass()

function Sqlitedb:initialize(args)
  local path, throw = GetInfo(58):gsub("^.\\",GetInfo(56))
  self.dbloc = GetPluginVariable ("", "dblocation") or path
  self.db = nil
  self.dbname = "\\stats.db"
  self.conns = 0
  self.version = 1
  self.versionfuncs = {}
end

function Sqlitedb:checkversion(args)
  self:checkversiontable()
  local dbversion = self:getversion()
  if self.version < dbversion then
    return
  end
  if self.version > dbversion then
    self:updateversion(dbversion, self.version)
  end
end

function Sqlitedb:checkversiontable()
  if self:open('checkversiontable') then
    if not self:checkfortable('version') then
      self.db:exec([[CREATE TABLE version(
        version_id INTEGER NOT NULL PRIMARY KEY autoincrement,
        version INT default 1
      )]])
      assert (self.db:exec("BEGIN TRANSACTION"))
      local stmt = self.db:exec[[ INSERT INTO version VALUES (NULL, 1) ]]
      assert (self.db:exec("COMMIT"))
    end
    self:close('checkversiontable')
  end
end

function Sqlitedb:getversion()
  local version = -1
  if self:open('getversion') then
    for a in self.db:nrows('SELECT * FROM version WHERE version_id = 1') do
      version = a['version']
    end
    self:close('getversion')
  end
  return version
end

function Sqlitedb:updateversion(oldversion, newversion)
  print(self.dbloc .. self.dbname, ': upgrading database from', oldversion, 'to', newversion)
  self:backupdb('v' .. oldversion)
  if self:open('updateversion') then
    for i=oldversion+1,newversion do
      self.versionfuncs[i](self)
    end
    if self:checkfortable('version') then
      self.db:exec(string.format('update version set version=%s where version_id = 1', newversion))
    end
    self:close('updateversion')
  end
  print('Done upgrading!')
end

function Sqlitedb:open(from)
  --phelper:mdebug('open - conns:', self.conns, from)
  if self.db == nil then
    --phelper:mdebug("opening db")
    --print('db dir', self.dbloc)
    self.db = assert(sqlite3.open(self.dbloc .. self.dbname))
  end
  self.conns = self.conns + 1
  return true
end

function Sqlitedb:close(from, force)
  self.conns = self.conns - 1
  if self.conns < 0 then
    print("BUG: conns < 0 for db", self.dbname)
  end
  phelper:mdebug('close - conns:', self.conns, from)
  if self.db ~= nil and (self.conns == 0 or force) then
    --phelper:mdebug("closing db")
    self.db:close()
    self.db = nil
  end
end

function Sqlitedb:checkfortable(tablename)
  if self:open('checkfortable') then
    for a in self.db:nrows('SELECT * FROM sqlite_master WHERE name = "' .. tablename .. '" AND type = "table"') do
      if a['name'] == tablename then
        self:close('checkfortable')
        return true
      end
    end
    self:close('checkfortable')
  end
  return false
end

function Sqlitedb:dbcheck (code)
  if code ~= sqlite3.OK and    -- no error
    code ~= sqlite3.ROW and   -- completed OK with another row of data
    code ~= sqlite3.DONE then -- completed OK, no more rows
    local err = self.db:errmsg ()  -- the rollback will change the error message
    self.db:exec ("ROLLBACK")      -- rollback any transaction to unlock the database
    error (err, 2)            -- show error in caller's context
  end -- if
end -- dbcheck

function Sqlitedb:backupdb(extension)
  --in_backup = true
  local dbpath = self.dbloc .. self.dbname
  Note("PERFORMING DATABASE BACKUP. DON'T TOUCH ANYTHING!")
  Note("db: " .. dbpath)
  Note("CHECKING INTEGRITY")
  BroadcastPlugin (999, "repaint")
  -- If needed, force wal_checkpoint databases to make sure everything gets written out
  -- this is a harmless no-op if not using journal_mode=WAL
  self:open('backupdb')
  self.db:exec("PRAGMA wal_checkpoint;")
  local integrityCheck = true
  for row in self.db:nrows("PRAGMA integrity_check;") do
     tprint(row)
     if row.integrity_check ~= "ok" then
        integrityCheck = false
     end
  end
  if not integrityCheck then
    Note("FAILED INTEGRITY CHECK. CLOSE MUSHCLIENT AND RESTORE A KNOWN GOOD DATABASE.")
    Note("for " .. dbpath)
    Note("ABORTING CURRENT BACKUP")
    --in_backup = false
    return
  end
  Note("INTEGRITY CHECK PASSED")
  Note("BACKING UP DATABASES")
  BroadcastPlugin (999, "repaint")



  n = GetInfo(66).."bastmush_temp_file.txt" -- temp file for catching os.execute output

  backupdir = self.dbloc .. "\\db_backups\\"

  ChangeDir("C:")

  mdcmd = "md " .. quote(backupdir) .. " >" .. quote(n) .. " 2>&1"
  Note(mdcmd)
  os.execute(mdcmd)
  local lines = {}
  for line in io.lines (n) do
    Note(line)
  end

  self:close('backupdb')

  -- make new backup
  local copycmd = "copy /Y " .. quote(dbpath) .. " " .. quote(backupdir .. self.dbname .. "." .. extension) .. " >" .. quote(n) .. " 2>&1"
  Note('copying db to ', backupdir .. self.dbname .. "." .. extension)
  Note(copycmd)
  os.execute(copycmd)

  for line in io.lines (n) do
    Note(line)
  end

  ChangeDir(GetInfo(66)) -- Go back to default directory
  Note("FINISHED DATABASE BACKUP. YOU MAY NOW GO BACK TO MUDDING.")
  --in_backup = false
end
