-- $Id$

require 'tprint'
require 'verify'
require 'pluginhelper'
require 'var'
require 'stringfuncs'

local Object = require 'objectlua.Object'

Sqlitedb = Object:subclass()

function fixsql (s, like)
   if s then
      if like then
        return "'%" .. (string.gsub (s, "'", "''")) .. "%'" -- replace single quotes with two lots of single quotes
      else
        return "'" .. (string.gsub (s, "'", "''")) .. "'" -- replace single quotes with two lots of single quotes
      end
   else
      return "NULL"
   end -- if
end -- fixsql

function Sqlitedb:initialize(args)
  local path, throw = GetInfo(58):gsub("^.\\",GetInfo(56))
  self.dbloc = GetPluginVariable ("", "dblocation") or path
  self.db = nil
  self.dbname = "\\sqlite.db"
  self.conns = 0
  self.version = 1
  self.versionfuncs = {}
  self.tableids = {}
  self.tables = {}
end

function Sqlitedb:addtable(tablename, sql, prefunc, postfunc, keyfield)
 self.tables[tablename] = {}
 self.tables[tablename]['createsql'] = sql
 self.tables[tablename]['precreate'] = prefunc
 self.tables[tablename]['postcreate'] = postfunc
 self.tables[tablename]['keyfield'] = keyfield
 local columns, columnsbykeys = self:getcolumnsfromsql(tablename)
 self.tables[tablename]['columns'] = columns
 self.tables[tablename]['columnsbykeys'] = columnsbykeys
end

function Sqlitedb:turnonpragmas()

end

function Sqlitedb:postinit()
  self:checkversion()

  for i,v in pairs(self.tables) do
    self:checktable(i)
  end

end

function Sqlitedb:checktable(tablename)
  if self.tables[tablename] and  self:open('checktable:' .. tablename) then
    if not self:checktableexists(tablename) then
      if self.tables[tablename]['precreate'] then
        self.tables[tablename]['precreate'](self)
      end
      self.db:exec(self.tables[tablename]['createsql'])
      if self.tables[tablename]['postcreate'] then
        self.tables[tablename]['postcreate'](self)
      end
    end
    self:close('checktable:' .. tablename)
  end
  return true
end

function Sqlitedb:checkversion(args)
  if self:checktableexists('version') then
    if self:open('getversion') then
      for a in self.db:nrows('SELECT * FROM version WHERE version_id = 1') do
        version = a['version']
      end
      self:setversion(version)
      self:close('getversion', true)
      self:open('getversion2')
      self.db:exec([[DROP TABLE IF EXISTS version;]])
      self:close('getversion2', true)    
    end
  end
  local dbversion = self:getversion()
  if self.version < dbversion then
    return
  end
  if dbversion == 0 then
    self:setversion(self.version)
  elseif self.version > dbversion then
    self:updateversion(dbversion, self.version)
  end
end

function Sqlitedb:setversion(version)
  stmt = string.format('PRAGMA user_version=%s;', version)
  if self:open('setversion') then
    assert(self.db:exec(stmt))
    self:close('setversion')
  end
end

function Sqlitedb:checkversiontable()
  if self:open('checkversiontable') then
    if not self:checktableexists('version') then
      self.db:exec(self.tables['version']['createsql'])
      assert (self.db:exec("BEGIN TRANSACTION"))
      local stmt = self.db:exec(string.format('INSERT INTO version VALUES (NULL, %d)', self.version))
      assert (self.db:exec("COMMIT"))
    end
    self:close('checkversiontable')
  end
end

function Sqlitedb:getversion()
  if self:open('getversion') then
    for a in self.db:nrows('PRAGMA user_version;') do
      version=a['user_version']
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
      print('finished updating to version', i)
    end
    self:setversion(newversion)
  end
  print('Done upgrading!')
end

function Sqlitedb:open(from)
  phelper:mdebug('open - conns:', self.conns, from, '->', self.conns + 1)
  if self.db == nil then
    --phelper:mdebug("opening db")
    --print('db dir', self.dbloc)
    self.db = assert(sqlite3.open(self.dbloc .. self.dbname))
    self:turnonpragmas()
  end
  if self.db then
    self.conns = self.conns + 1
    return true
  else
    self.db = nil
    return false
  end
end

function Sqlitedb:close(from, force)
  phelper:mdebug('close - conns:', self.conns, from, '->', self.conns - 1)
  self.conns = self.conns - 1
  if self.conns < 0 and not force then
    phelper:mdebug("BUG: conns < 0 for db", self.dbname)
  end
  if self.db ~= nil and (self.conns == 0 or force) then
--  if self.db ~= nil and force then
    --phelper:mdebug("closing db")
    self.conns = 0
    self.db:close()
    self.db = nil
  end
end

function Sqlitedb:checktableexists(tablename)
  local rv = false
  if self:open('checktableexists') then
    for a in self.db:nrows('SELECT * FROM sqlite_master WHERE name = "' .. tablename .. '" AND type = "table"') do
      if a['name'] == tablename then
        rv = true
      end
    end
    self:close('checktableexists')
  end
  return rv
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

function Sqlitedb:getcolumnsfromsql(tablename)
  local columns = {}
  local columnsbykeys = {}
  if self.tables[tablename] then
    local tlist = utils.split(self.tables[tablename]['createsql'], '\n')
    for i,v in ipairs(tlist) do
      v = trim(v)
      if v:find('CREATE') == nil and v:find(')') == nil then
        local ilist = utils.split(v, ' ')
        table.insert(columns, ilist[1])
        columnsbykeys[ilist[1]] = true
      end
    end
  end
  return columns, columnsbykeys
end

function Sqlitedb:converttoinsert(tablename, keynull, replace)
  local execstr = nil
  local columns = {}
  if self.tables[tablename] then
    local columns = self.tables[tablename].columns
    local columnsbykeys = self.tables[tablename].columnsbykeys
    local colstring = strjoin(', :', columns)
    colstring = ':' .. colstring
    if replace then
      execstr = string.format("INSERT OR REPLACE INTO %s VALUES (%s)", tablename, colstring)
    else
      execstr = string.format("INSERT INTO %s VALUES (%s)", tablename, colstring)
    end
    if keynull and self.tables[tablename]['keyfield'] then
      execstr = string.gsub(execstr, ':' .. self.tables[tablename]['keyfield'], 'NULL')
    end
  end
  return execstr
end

function Sqlitedb:converttoupdate(tablename, wherekey, nokey)
  local execstr = nil
  local columns = {}
  if self.tables[tablename] then
    local columns = self.tables[tablename].columns
    local columnsbykeys = self.tables[tablename].columnsbykeys
    local sqlstr = {}
    for i,v in pairs(columns) do
      if v == wherekey or (nokey and nokey[v]) then
        -- don't put anything into the table
      else
        table.insert(sqlstr, v .. ' = :' .. v)
      end
    end
    colstring = strjoin(',', sqlstr)
    execstr = string.format("UPDATE %s SET %s WHERE %s = :%s;", tablename, colstring, wherekey, wherekey)
  end
  return execstr
end

function Sqlitedb:runselect(selectstmt, keyword)
  local result = {}
  if self:open('runselect') then
    local stmt = self.db:prepare(selectstmt)
    if stmt then
      for row in stmt:nrows() do
        if keyword then
          result[row[keyword]] = row
        else
          table.insert(result, row)
        end
      end
    else
      print('not valid', selectstmt)
    end
    self:close('runselect')
  end
  return result
end

function Sqlitedb:getlastrowid(ttable)
  local colid = self.tables[ttable].keyfield
  local lastid = 0
  if self:open('getlastrow') then
    if colid then
      local tstring = 'SELECT MAX(' .. colid .. ') AS MAX FROM ' .. ttable
      for a in self.db:nrows(tstring) do
        lastid = a['MAX']
      end
    end
    self:close('getlastrow')
  end
  if lastid == nil then
    lastid = 0
  end
  return lastid
end

function Sqlitedb:getlast(ttable, num, where)
  local colid = self.tables[ttable].keyfield
  local tstring = ''
  if where then
    tstring = string.format("SELECT * FROM %s WHERE %s ORDER by %s desc limit %d", ttable, where, colid, num)
  else
    tstring = string.format("SELECT * FROM %s ORDER by %s desc limit %d", ttable, colid, num)
  end

  local items = {}
  if self:open('getlast') then
    if colid then
      for a in self.db:nrows(tstring) do
        items[a[colid]] = a
      end
    end
    self:close('getlast')
  end
  return items
end
