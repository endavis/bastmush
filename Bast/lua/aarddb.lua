-- $Id$
require 'tprint'
require 'verify'
require 'pluginhelper'
require 'sqlitedb'
require 'aardutils'

Aarddb = Sqlitedb:subclass()

function Aarddb:initialize(args)
  super(self, args)   -- notice call to superclass's constructor
  self.dbname = "/aardinfo.db"
  self.version = 3
  self.versionfuncs[2] = self.resetplanestable
  self.versionfuncs[3] = self.convertroomnotes

  self:addtable('planespools',[[CREATE TABLE planespools(
      pool_id INTEGER NOT NULL PRIMARY KEY autoincrement,
      poollayer TEXT NOT NULL,
      poolnum INT NOT NULL
        )]], nil, self.createplanespoolstable, 'pool_id')

  self:addtable('planesmobs', [[CREATE TABLE planesmobs(
      mob_id INTEGER NOT NULL PRIMARY KEY autoincrement,
      mobname TEXT NOT NULL,
      poolnum INT NOT NULL
        )]], nil, self.createplanesmobstable, 'mob_id')


  self:addtable('areas', [[CREATE TABLE areas(
      area_id INTEGER NOT NULL PRIMARY KEY autoincrement,
      keyword TEXT UNIQUE NOT NULL,
      name TEXT UNIQUE NOT NULL,
      afrom INT default 1,
      ato INT default 1,
      alock INT default 0,
      builder TEXT,
      speedwalk TEXT
        )]], nil, nil, 'area_id')

  self:addtable('helplookup', [[CREATE TABLE helplookup(
      lookup_id INTEGER NOT NULL PRIMARY KEY autoincrement,
      lookup TEXT UNIQUE NOT NULL,
      topic TEXT
        )]], nil, nil, 'lookup_id')

  self:addtable('helps', [[CREATE TABLE helps(
      help_id INTEGER NOT NULL PRIMARY KEY autoincrement,
      keyword TEXT UNIQUE NOT NULL,
      helptext TEXT,
      added INT
        )]], nil, nil, 'help_id')

  self:addtable('notes', [[CREATE TABLE notes(
      note_id INTEGER NOT NULL PRIMARY KEY autoincrement,
      area TEXT NOT NULL,
      keywords TEXT NOT NULL,
      note TEXT NOT NULL
        )]], nil, nil, 'note_id')

  self:addtable('roomnotes', [[CREATE TABLE roomnotes(
      rnote_id INTEGER NOT NULL PRIMARY KEY autoincrement,
      room INT default -1,
      notenum INT
        )]], nil, nil, 'rnote_id')

  self:postinit() -- this is defined in sqlitedb.lua, it checks for upgrades and creates all tables
end

function Aarddb:addnote(note)
  if self:open('addnote') then
    local stmt = self.db:prepare(self:converttoinsert('notes'))
    stmt:bind_names( note )
    stmt:step()
    local retval = stmt:finalize()
    local rowid = self.db:last_insert_rowid()
    phelper:mdebug('added note', rowid)
    self:close('addnote')
    return rowid
  end
end

function Aarddb:removenote(notenum)
  timer_start('Aarddb:removenote')
  --tprint(item)
  local tchanges = 0
  if self:open('removenote') then
    tchanges = self.db:total_changes()
    self.db:exec("DELETE FROM notes WHERE note_id= " .. tostring(notenum))
    tchanges = self.db:total_changes() - tchanges
    self.db:exec("DELETE FROM roomnotes WHERE notenum = " .. tostring(notenum))
    self:close('removenote')
  end
  timer_end('Aarddb:removenote')
  return tchanges
end

function Aarddb:getallnotes()
  local results = {}
  local sqlcmd = 'SELECT * FROM notes'
  if self:open('getallnotes') then
    local stmt = self.db:prepare(sqlcmd)
    if not stmt then
      phelper:plugin_header('Note Lookup')
      print('Get All Notes: The lookup arguments do not create a valid sql statement to get notes')
    else
      for a in stmt:nrows() do
        table.insert(results, a)
      end
    end
    self:close('getallnotes')
  end
  return results
end

function Aarddb:lookupnotes(notestr)
  local results = {}
  local sqlcmd = 'SELECT * FROM notes WHERE ' .. notestr
  if self:open('lookupnotes') then
    local stmt = self.db:prepare(sqlcmd)
    if not stmt then
      phelper:plugin_header('Note Lookup')
      print('The lookup arguments do not create a valid sql statement to get notes')
    else
      for a in stmt:nrows() do
        table.insert(results, a)
      end
    end
    self:close('lookupnotes')
  end
  return results
end

function Aarddb:getnotesforroom(ruid)
  local results = {}
  local sqlcmd = [[SELECT *
                    FROM roomnotes r
                    INNER JOIN notes n ON n.note_id = r.notenum
                    WHERE r.room = %s
                    ORDER BY r.notenum ASC
                    ]]
  if self:open('getnotesforroom') then
    local stmt = self.db:prepare(string.format(sqlcmd, ruid))
    if not stmt then
      phelper:plugin_header('getnotesforroom')
      print('The lookup arguments do not create a valid sql statement to get notes')
    else
      for a in stmt:nrows() do
        table.insert(results, a)
      end
    end
    self:close('getnotesforroom')
  end
  return results
end

function Aarddb:getroomsfornote(note_id)
  local results = {}
  local sqlcmd = [[SELECT *
                    FROM roomnotes
                    WHERE notenum = %s
                    ]]
  if self:open('getroomsfornotes') then
    local stmt = self.db:prepare(string.format(sqlcmd, note_id))
    if not stmt then
      phelper:plugin_header('getroomsfornotes')
      print('The lookup arguments do not create a valid sql statement to get notes')
    else
      for a in stmt:nrows() do
        table.insert(results, a)
      end
    end
    self:close('getroomsfornotes')
  end
  return results
end

function Aarddb:addnotetoroom(roomnum, note_id)
  if self:open('addnotetoroom') then
    local sqls = 'INSERT INTO roomnotes VALUES (NULL, %s, %s)'
    local sqlp = string.format(sqls, roomnum, note_id)
    self.db:exec(sqlp)
    self:close('addnotetoroom')
  end
end

function Aarddb:removenotefromroom(roomnum, note_id)
  if self:open('removenotefromroom') then
    local sqls = 'DELETE FROM roomnotes WHERE room = %s and notenum = %s '
    local sqlp = string.format(sqls, roomnum, note_id)
    self.db:exec(sqlp)
    self:close('removenotefromroom')
  end
end

function Aarddb:resetplanestable()
  self:close(true)
  if self:open() then
    self.db:exec([[DROP TABLE IF EXISTS planespools;]])
    self.db:exec([[DROP TABLE IF EXISTS planesmobs;]])
    self:close(true)
    self:open()
    self:checktable('planespools')
    self:checktable('planesmobs')
  end
end

function Aarddb:createplanespoolstable()
  if self:open() then
    self.db:exec([[BEGIN TRANSACTION]])
    local stmt = self.db:prepare(self:converttoinsert('planespools'))
    for _,item in pairs(planespools) do
      stmt:bind_names(  item  )
      stmt:step()
      stmt:reset()
    end
    stmt:finalize()
    self.db:exec([[COMMIT]])
    self:close()
  end
end

function Aarddb:createplanesmobstable()
  if self:open() then
    self.db:exec([[BEGIN TRANSACTION]])
    local stmt = self.db:prepare(self:converttoinsert('planesmobs'))
    for _,item in pairs(planesmobs) do
      stmt:bind_names(  item  )
      stmt:step()
      stmt:reset()
    end
    stmt:finalize()
    self.db:exec([[COMMIT]])
    self:close()
  end

end

function Aarddb:planeslookup(mob)
  local tmobs = {}
  if self:open() then
    for a in self.db:nrows( [[SELECT DISTINCT(planesmobs.mobname), planespools.poollayer, planespools.poolnum
                              FROM planesmobs, planespools  WHERE planesmobs.mobname LIKE '%]] .. mob .. [[%'
                              and planesmobs.poolnum == planespools.poolnum]] ) do
      table.insert(tmobs, a)
    end
    self:close()
  end
  return tmobs
end

function Aarddb:getallareas()
  local areasbykeyword = {}
  if self:open() then
    for a in self.db:nrows( "SELECT * FROM areas" ) do
      areasbykeyword[a.keyword] = a
    end
    self:close()
  end
  return areasbykeyword
end

function Aarddb:getallareasbyname()
  local areas = {}
  if self:open() then
    for a in self.db:nrows( "SELECT * FROM areas" ) do
      areas[a.name] = a
    end
    self:close()
  end
  return areas
end


function Aarddb:lookupareas(areastr)
  local results = {}
  local sqlcmd = 'SELECT * FROM areas WHERE ' .. areastr
  if self:open('lookupareas') then
    local stmt = self.db:prepare(sqlcmd)
    if not stmt then
      phelper:plugin_header('Area Lookup')
      print('The lookup arguments do not create a valid sql statement to get areas')
    else
      for a in stmt:nrows() do
        table.insert(results, a)
      end
    end
    self:close('lookupareas')
  end
  return results
end

function Aarddb:lookupareasbyname(area)
  local areas = {}
  local area = fixsql(area, true)
  if self:open() and self:checktable('areas')  then
    for a in self.db:nrows( "SELECT * FROM areas WHERE name LIKE " .. area ) do
      table.insert(areas, a)
    end
    self:close()
  end
  return areas
end

function Aarddb:lookupareasbyexactname(area)
  local areas = {}
  local area = fixsql(area)
  if self:open() and self:checktable('areas')  then
    for a in self.db:nrows( "SELECT * FROM areas WHERE LOWER(name) = LOWER(" .. area ..  ")") do
      table.insert(areas, a)
    end
    self:close()
  end
  return areas
end

function Aarddb:lookupareasbykeyword(keyword, exact)

  local areas = {}
  local tkeyword = fixsql(keyword, true)
  local sqlstmt = "SELECT * FROM areas WHERE keyword LIKE " .. tkeyword
  if exact ~= nil then
    tkeyword = fixsql(keyword)
    sqlstmt = "SELECT * FROM areas WHERE LOWER(keyword) = LOWER(" .. tkeyword ..")"
  end

  if self:open() and self:checktable('areas')  then
    for a in self.db:nrows(sqlstmt) do
      table.insert(areas, a)
    end
    self:close()
  end
  return areas
end

function Aarddb:lookupareasbylevel(level)
  local areas = {}
  if self:open() then
    for a in self.db:nrows( "SELECT * FROM areas WHERE afrom < " .. level .. " and ato > " .. level .. ";" ) do
      table.insert(areas, a)
    end
    self:close()
  end
  return areas
end

function Aarddb:addareas(area_list)
  if self:open() then
    local allareas = self:getallareas()

    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare(self:converttoinsert('areas'))
    local stmtupd = self.db:prepare(self:converttoupdate('areas', 'keyword'))

    for i,v in pairs(area_list) do
      if v.keyword ~= nil and allareas[v.keyword] == nil then
        stmt:bind_names (v)
        stmt:step()
        stmt:reset()
      elseif v.keyword ~= nil then
        stmtupd:bind_names(v)
        stmtupd:step()
        stmtupd:reset()
      end
    end
    stmt:finalize()
    stmtupd:finalize()
    assert (self.db:exec("COMMIT"))
    self:close()
  end
end

function Aarddb:updatebuilders(area_list)
  if self:open() then
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare[['update areas set author=:author where keyword=:keyword;']]
    for i,v in ipairs(area_list) do
      stmt:bind_names (v)
      stmt:step()
      stmt:reset()
    end
    stmt:finalize()
    assert (self.db:exec("COMMIT"))
    self:close()
  end
end

function Aarddb:updatespeedwalks(area_list)
  if self:open() then
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare[['update areas set speedwalk=:speedwalk where keyword=:keyword;']]
    for i,v in ipairs(area_list) do
      stmt:bind_names (v)
      stmt:step()
      stmt:reset()
    end
    stmt:finalize()
    assert (self.db:exec("COMMIT"))
    self:close()
  end
end


function Aarddb:addhelplookup(lookup)
  if self:open() then
    local stmt = self.db:prepare(self:converttoinsert('helplookup'))
    stmt:bind_names(  lookup  )
    stmt:step()
    stmt:finalize()
    local rowid = self.db:last_insert_rowid()
    phelper:mdebug("inserted helplookup :", rowid)
    self:close()
    return rowid
  end
  return nil
end


function Aarddb:addhelp(help)
  if self:open() then
    help.helptext = serialize.save("thelptext", help.helptext)
    local hashelp = self:hashelp(help.keyword)
    local message = 'inserted help:'
    local stmt
    if hashelp then
      stmt = self.db:prepare[[ UPDATE helps SET helptext=:helptext, added=:added WHERE keyword=:keyword ]]
      message = 'updated help:'
    else
      stmt = self.db:prepare[[ INSERT INTO helps VALUES (NULL, :keyword,
                                                            :helptext, :added) ]]
    end
    stmt:bind_names(  help  )
    stmt:step()
    stmt:finalize()
    local rowid = self.db:last_insert_rowid()
    phelper:mdebug(message, rowid)
    self:close()
    return rowid
  end
end

function Aarddb:hashelp(keyword)
  local thelp = nil
  if self:open() then
    for a in self.db:nrows('SELECT * FROM helps WHERE keyword = "' .. keyword .. '"' ) do
      if a['keyword'] == keyword then
        self:close()
        return true
      end
    end
    self:close()
  end
  return false
end

function Aarddb:gethelp(thelp)
  local help = {}
  if self:open() then
    for a in self.db:nrows('SELECT * FROM helplookup where lookup == "' .. thelp ..'"') do
      table.insert(help, a['topic'])
    end
    self:close()
  end
  if #help > 1 or #help == 0 then
    return false
  else
    if self:open() then
      local thelp = {}
      for a in self.db:nrows('SELECT * FROM helps where keyword == "' .. help[1] ..'"') do
        thelp = a
        loadstring (a.helptext) ()
        thelp.helptext = thelptext
      end
      self:close()
      return thelp
    end
  end
  return false

end

function Aarddb:clearhelptable()
  if self:open() then
    self.db:exec([[DROP TABLE IF EXISTS helplookup;]])
    self:close(true)
  end
  if self:open() then
    self.db:exec([[DROP TABLE IF EXISTS helps;]])
    self:close(true)
  end
  self:checktable('helps')
  self:checktable('helplookup')
end

function Aarddb:convertroomnotes()
  local oldnotes = self:getallnotes()
  self:open('convertroomnotes')
  self.db:exec([[DROP TABLE IF EXISTS notes;]])
  self.db:exec([[DROP TABLE IF EXISTS roomnotes;]])
  self:close('convertroomnotes', true)
  self:open('convertroomnotes2')
  self.db:exec([[CREATE TABLE notes(
    note_id INTEGER NOT NULL PRIMARY KEY autoincrement,
    area TEXT NOT NULL,
    keywords TEXT NOT NULL,
    note TEXT NOT NULL
      )]])
  self.db:exec([[CREATE TABLE roomnotes(
    rnote_id INTEGER NOT NULL PRIMARY KEY autoincrement,
    room INT default -1,
    notenum INT
      )]])
  self:close('convertroomnotes2', true)

  if oldnotes and next(oldnotes) then
    self:open('convertroomnotes3')
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare[[ INSERT INTO notes VALUES (:note_id, :area, :keywords,
                                                              :note) ]]

    for i,v in tableSort(oldnotes, 'note_id') do
      stmt:bind_names(v)
      stmt:step()
      stmt:reset()
    end
    stmt:finalize()
    local stmt2 = self.db:prepare[[ INSERT INTO roomnotes VALUES (NULL, :room,
                                                                  :note_id) ]]
    for i,v in tableSort(oldnotes, 'note_id') do
      if v['room'] and tonumber(v['room']) then
        stmt2:bind_names(v)
        stmt2:step()
        stmt2:reset()
      end
    end
    stmt2:finalize()
    assert (self.db:exec("COMMIT"))
    self:close('convertroomnotes3', true)
  end
end

planespools = {
  {poollayer = 'Gladsheim', poolnum = 1},
  {poollayer = 'Pandemonium', poolnum = 2},
  {poollayer = 'Hades', poolnum = 3},
  {poollayer = 'Gehenna', poolnum = 4},
  {poollayer = 'Acheron', poolnum = 5},
  {poollayer = 'Twin Paradises', poolnum = 6},
  {poollayer = 'Arcadia', poolnum = 7},
  {poollayer = 'Seven Heavens', poolnum = 8},
  {poollayer = 'Elysium', poolnum = 10},
  {poollayer = 'Beastlands', poolnum = 11},
}

planesmobs = {
  {mobname='A paladin einheriar', poolnum=1},
  {mobname='A psionic einheriar', poolnum=1},
  {mobname='A cleric einheriar', poolnum=1},
  {mobname='A ranger einheriar', poolnum=1},
  {mobname='A warrior einheriar', poolnum=1},
  {mobname='A thief einheriar', poolnum=1},
  {mobname='A mage einheriar', poolnum=1},
  {mobname='A titan', poolnum=1},
  {mobname='A per', poolnum=1},
  {mobname='A bariaur', poolnum=1},
  {mobname='A malelephant', poolnum=2},
  {mobname='A nightmare', poolnum=2},
  {mobname='A larva', poolnum=2},
  {mobname='A hordling', poolnum=3},
  {mobname='A yagnoloth', poolnum=3},
  {mobname='A night hag', poolnum=3},
  {mobname='An ultroloth', poolnum=4},
  {mobname='An arcanaloth', poolnum=4},
  {mobname='A dergholoth', poolnum=4},
  {mobname='A hydroloth', poolnum=4},
  {mobname='A mezzoloth', poolnum=4},
  {mobname='A psicloth', poolnum=4},
  {mobname='A nycaloth', poolnum=4},
  {mobname='A vaporighu', poolnum=4},
  {mobname='General of Gehenna', poolnum=4},
  {mobname='An ultroloth', poolnum=5},
  {mobname='A dergholoth', poolnum=5},
  {mobname='A hydroloth', poolnum=5},
  {mobname='A mezzoloth', poolnum=5},
  {mobname='A psicloth', poolnum=5},
  {mobname='A nycaloth', poolnum=5},
  {mobname='An adamantite dragon', poolnum=6},
  {mobname='An air sentinel', poolnum=6},
  {mobname='A monadic deva', poolnum=6},
  {mobname='An agathinon aasimon', poolnum=7},
  {mobname='An astral deva', poolnum=7},
  {mobname='A translator', poolnum=7},
  {mobname="A t'uen-rin", poolnum=7},
  {mobname='A lantern archon', poolnum=8},
  {mobname='A tome archon', poolnum=8},
  {mobname='A noctral', poolnum=8},
  {mobname='A planetar aasimon', poolnum=8},
  {mobname='A warden archon', poolnum=8},
  {mobname='A hound archon', poolnum=8},
  {mobname='A sword archon', poolnum=8},
  {mobname='A zoveri', poolnum=8},
  {mobname='A light aasimon', poolnum=10},
  {mobname='A solar aasimon', poolnum=10},
  {mobname='A movanic deva', poolnum=10},
  {mobname='A balanea', poolnum=10},
  {mobname='A phoenix', poolnum=10},
  {mobname='A moon dog', poolnum=10},
  {mobname='A mortai', poolnum=11},
  {mobname='An animal spirit', poolnum=11},
  {mobname='An animal lord', poolnum=11},
  {mobname='A warden beast', poolnum=11},
}
