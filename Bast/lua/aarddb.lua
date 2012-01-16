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
  self.version = 2
  self.versionfuncs[2] = self.resetplanestable
  if not self:checkplanespoolstable() then
    self:createplanespoolstable(planespools)
  end
  if not self:checkplanesmobstable() then
    self:createplanesmobstable(planesmobs)
  end
  self:checkversion()
end

function Aarddb:resetplanestable()
  if self:open() then
    self.db:exec([[DROP TABLE IF EXISTS planespools;]])
    self.db:exec([[DROP TABLE IF EXISTS planesmobs;]])
    self:createplanespoolstable(planespools)
    self:createplanesmobstable(planesmobs)
    self:close()
  end
end

function Aarddb:checkplanespoolstable()
  if not self:checkfortable('planespools') then
    self:open()
    self.db:exec([[CREATE TABLE planespools(
      pool_id INTEGER NOT NULL PRIMARY KEY autoincrement,
      poollayer TEXT NOT NULL,
      poolnum INT NOT NULL
     )]])
    self:close()
    return false
  end
  return true
end

function Aarddb:checkplanesmobstable()
  if not self:checkfortable('planesmobs') then
    self:open()
    self.db:exec([[CREATE TABLE planesmobs(
      mob_id INTEGER NOT NULL PRIMARY KEY autoincrement,
      mobname TEXT NOT NULL,
      poolnum INT NOT NULL
     )]])
    self:close()
    return false
  end
  return true
end

function Aarddb:createplanespoolstable(pools)
  self:checkplanespoolstable()
  self:open()
  self.db:exec([[BEGIN TRANSACTION;]])
  local stmt = self.db:prepare[[ INSERT INTO planespools VALUES (NULL, :poolname,
                                                          :poolnum) ]]
  for _,item in pairs(pools) do
    stmt:bind_names(  item  )
    stmt:step()
    stmt:reset()
  end
  stmt:finalize()
  self.db:exec([[COMMIT;]])
  self:close()

end

function Aarddb:createplanesmobstable(mobs)
  self:checkplanesmobstable()
  self:open()
  self.db:exec([[BEGIN TRANSACTION;]])
  local stmt = self.db:prepare[[ INSERT INTO planesmobs VALUES (NULL, :name,
                                                          :pool) ]]
  for _,item in pairs(mobs) do
    stmt:bind_names(  item  )
    stmt:step()
    stmt:reset()
  end
  stmt:finalize()
  self.db:exec([[COMMIT;]])
  self:close()

end

function Aarddb:planeslookup(mob)
  local tmobs = {}
  if self:open() then
    for a in self.db:nrows( "SELECT DISTINCT(planesmobs.mobname), planespools.poollayer, planespools.poolnum FROM planesmobs, planespools  WHERE planesmobs.mobname LIKE '%" .. mob .. "%' and planesmobs.poolnum == planespools.poolnum" ) do
      table.insert(tmobs, a)
    end
    self:close()
  end
  return tmobs
end

function Aarddb:checkareastable()
  self:open()
  if not self:checkfortable('areas') then
    self.db:exec([[CREATE TABLE areas(
      area_id INTEGER NOT NULL PRIMARY KEY autoincrement,
      keyword TEXT UNIQUE NOT NULL,
      name TEXT UNIQUE NOT NULL,
      afrom INT default 1,
      ato INT default 1,
      alock INT default 0,
      builder TEXT,
      speedwalk TEXT
     )]])
  end
  self:close()
end

function Aarddb:getallareas()
  local areasbykeyword = {}
  self:checkareastable()
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
  self:checkareastable()
  if self:open() then
    for a in self.db:nrows( "SELECT * FROM areas" ) do
      areas[a.name] = a
    end
    self:close()
  end
  return areas
end

function Aarddb:lookupareasbyname(area)
  local areas = {}
  local area = fixsql(area, true)
  if self:open() and self:checkfortable('areas')  then
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
  if self:open() and self:checkfortable('areas')  then
    for a in self.db:nrows( "SELECT * FROM areas WHERE LOWER(name) = LOWER(" .. area ..  ")") do
      table.insert(areas, a)
    end
    self:close()
  end
  return areas
end

function Aarddb:lookupareasbykeyword(keyword)
  local areas = {}
  local keyword = fixsql(keyword, true)
  if self:open() and self:checkfortable('areas')  then
    for a in self.db:nrows( "SELECT * FROM areas WHERE keyword LIKE " .. keyword ) do
      table.insert(areas, a)
    end
    self:close()
  end
  return areas
end

function Aarddb:lookupareasbylevel(level)
  local areas = {}
  if self:open() and self:checkfortable('areas') then
    for a in self.db:nrows( "SELECT * FROM areas WHERE afrom < " .. level .. " and ato > " .. level .. ";" ) do
      table.insert(areas, a)
    end
    self:close()
  end
  return areas
end

function Aarddb:addareas(area_list)
  self:checkareastable()
  if self:open() then
    local allareas = self:getallareas()

    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare[[ INSERT INTO areas VALUES (NULL, :keyword, :name, :afrom,
                                                          :ato, :alock, :builder, :speedwalk) ]]
    local stmtupd = self.db:prepare[[ UPDATE areas set name = :name, afrom = :afrom,
                                                          ato = :ato, alock = :alock, builder = :builder,
                                                          speedwalk = :speedwalk where keyword = :keyword]]

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
  self:checkareastable()
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
  self:checkareastable()
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

function Aarddb:checkhelpstable()
  self:open()
  if not self:checkfortable('helps') then
    self.db:exec([[CREATE TABLE helps(
      help_id INTEGER NOT NULL PRIMARY KEY autoincrement,
      keyword TEXT UNIQUE NOT NULL,
      helptext TEXT,
      added INT
     )]])
  end
  self:close()
end

function Aarddb:checkhelplookuptable()
  self:open()
  if not self:checkfortable('helplookup') then

    self.db:exec([[CREATE TABLE helplookup(
      lookup_id INTEGER NOT NULL PRIMARY KEY autoincrement,
      lookup TEXT UNIQUE NOT NULL,
      topic TEXT
     )]])
  end
  self:close()
end

function Aarddb:addhelplookup(lookup)
  self:checkhelplookuptable()
  if self:open() then
    local stmt = self.db:prepare[[ INSERT INTO helplookup VALUES (NULL, :lookup,
                                                          :topic) ]]

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
  self:checkhelpstable()
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
  self:checkhelpstable()
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
  if not self:checkfortable('helplookup') then
     return false
  end
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
  if self:checkfortable('helplookup') then
    if self:open() then
      self.db:exec([[DROP TABLE IF EXISTS helplookup;]])
      self:close()
    end
  end
  if self:checkfortable('helps') then
    if self:open() then
      self.db:exec([[DROP TABLE IF EXISTS helps;]])
      self:close()
    end
  end
end

planespools = {
  {poolname = 'Gladsheim', poolnum = 1},
  {poolname = 'Pandemonium', poolnum = 2},
  {poolname = 'Hades', poolnum = 3},
  {poolname = 'Gehenna', poolnum = 4},
  {poolname = 'Acheron', poolnum = 5},
  {poolname = 'Twin Paradises', poolnum = 6},
  {poolname = 'Arcadia', poolnum = 7},
  {poolname = 'Seven Heavens', poolnum = 8},
  {poolname = 'Elysium', poolnum = 10},
  {poolname = 'Beastlands', poolnum = 11},
}

planesmobs = {
  {name='A paladin einheriar', pool=1},
  {name='A psionic einheriar', pool=1},
  {name='A cleric einheriar', pool=1},
  {name='A ranger einheriar', pool=1},
  {name='A warrior einheriar', pool=1},
  {name='A thief einheriar', pool=1},
  {name='A mage einheriar', pool=1},
  {name='A titan', pool=1},
  {name='A per', pool=1},
  {name='A bariaur', pool=1},
  {name='A malelephant', pool=2},
  {name='A nightmare', pool=2},
  {name='A larva', pool=2},
  {name='A hordling', pool=3},
  {name='A yagnoloth', pool=3},
  {name='A night hag', pool=3},
  {name='An ultroloth', pool=4},
  {name='An arcanaloth', pool=4},
  {name='A dergholoth', pool=4},
  {name='A hydroloth', pool=4},
  {name='A mezzoloth', pool=4},
  {name='A psicloth', pool=4},
  {name='A nycaloth', pool=4},
  {name='A vaporighu', pool=4},
  {name='General of Gehenna', pool=4},
  {name='An ultroloth', pool=5},
  {name='A dergholoth', pool=5},
  {name='A hydroloth', pool=5},
  {name='A mezzoloth', pool=5},
  {name='A psicloth', pool=5},
  {name='A nycaloth', pool=5},
  {name='An adamantite dragon', pool=6},
  {name='An air sentinel', pool=6},
  {name='A monadic deva', pool=6},
  {name='An agathinon aasimon', pool=7},
  {name='An astral deva', pool=7},
  {name='A translator', pool=7},
  {name="A t'uen-rin", pool=7},
  {name='A lantern archon', pool=8},
  {name='A tome archon', pool=8},
  {name='A noctral', pool=8},
  {name='A planetar aasimon', pool=8},
  {name='A warden archon', pool=8},
  {name='A hound archon', pool=8},
  {name='A sword archon', pool=8},
  {name='A zoveri', pool=8},
  {name='A light aasimon', pool=10},
  {name='A solar aasimon', pool=10},
  {name='A movanic deva', pool=10},
  {name='A balanea', pool=10},
  {name='A phoenix', pool=10},
  {name='A moon dog', pool=10},
  {name='A mortai', pool=11},
  {name='An animal spirit', pool=11},
  {name='An animal lord', pool=11},
  {name='A warden beast', pool=11},
}
