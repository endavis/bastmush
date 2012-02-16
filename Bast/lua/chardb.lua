-- $Id$
--[[



QP/TP per level
SELECT AVG(qp + mccp + lucky + tier), AVG(tp) FROM quests GROUP BY level;
SELECT AVG(qp), AVG(tp) FROM campaigns GROUP BY level;

QP/TP/XP Hourly stats
SELECT SUM(qp + mccp + lucky + tier), SUM(tp) FROM quests WHERE finishtime > now - 1 hour;
SELECT SUM(qp), SUM(tp) FROM campaigns WHERE finishtime > now - 1 hour;
SELECT SUM(xp + bonusxp) FROM mobkils WHERE time > now - 1 hour;

QP/CP/GQ AVE TIME
SELECT AVG(finishtime - starttime) FROM quests where failed = 0
SELECT AVG(finishtime - starttime) FROM campaigns where failed = 0
SELECT AVG(finishtime - starttime) FROM gquests where won = 1

--]]

require 'tprint'
require 'verify'
require 'pluginhelper'
require 'sqlitedb'
require 'aardutils'
require 'tablefuncs'

Statdb = Sqlitedb:subclass()

function Statdb:initialize(args)
  super(self, args)   -- notice call to superclass's constructor
  self.dbname = "\\stats.db"
  self.version = 9
  self.versionfuncs[2] = self.updatedblqp -- update double qp flag
  self.versionfuncs[3] = self.updatemobkills -- slit, assassinate, etc..
  self.versionfuncs[4] = self.addmobsblessing
  self.versionfuncs[5] = self.addquestblessing
  self.versionfuncs[6] = self.addleveltrainblessing
  self.versionfuncs[7] = self.addclanskill
  self.versionfuncs[8] = self.updatecpmobfields
  self.versionfuncs[9] = self.updategqmobfields
  self:checkversion()

  self.tableids = {
    levels = 'level_id',
    stats = 'stat_id',
    quests = 'quest_id',
    campaigns = 'cp_id',
    gquests = 'gq_id',
    mobkills = 'mk_id',
    skills = 'sn',
  }

  self.createtablesql['stats'] = [[CREATE TABLE stats(
          stat_id INTEGER NOT NULL PRIMARY KEY autoincrement,
          name TEXT NOT NULL,
          level INT default 1,
          totallevels INT default 1,
          remorts INT default 1,
          tiers INT default 0,
          race TEXT default "",
          sex TEXT default "",
          subclass TEXT default "",
          qpearned INT default 0,
          questscomplete INT default 0 ,
          questsfailed INT default 0,
          campaignsdone INT default 0,
          campaignsfld INT default 0,
          gquestswon INT default 0,
          duelswon INT default 0,
          duelslost INT default 0,
          timeskilled INT default 0,
          monsterskilled INT default 0,
          combatmazewins INT default 0,
          combatmazedeaths INT default 0,
          powerupsall INT default 0,
          totaltrivia INT default 0,
          time INT default 0,
          milestone TEXT
        )]]

  self.createtablesql['quests'] = [[CREATE TABLE quests(
          quest_id INTEGER NOT NULL PRIMARY KEY autoincrement,
          starttime INT default 0,
          finishtime INT default 0,
          mobname TEXT default "Unknown",
          mobarea TEXT default "Unknown",
          mobroom TEXT default "Unknown",
          qp INT default 0,
          double INT default 0,
          daily INT default 0,
          totqp INT default 0,
          gold INT default 0,
          tier INT default 0,
          mccp INT default 0,
          lucky INT default 0,
          tp INT default 0,
          trains INT default 0,
          pracs INT default 0,
          level INT default -1,
          failed INT default 0
        )]]

  self.createtablesql['campaigns'] = [[CREATE TABLE campaigns(
          cp_id INTEGER NOT NULL PRIMARY KEY autoincrement,
          starttime INT default 0,
          finishtime INT default 0,
          qp INT default 0,
          gold INT default 0,
          tp INT default 0,
          trains INT default 0,
          pracs INT default 0,
          level INT default -1,
          failed INT default 0
        )]]

  self.createtablesql['cpmobs'] = [[CREATE TABLE cpmobs(
          cpmob_id INTEGER NOT NULL PRIMARY KEY autoincrement,
          cp_id INT NOT NULL,
          name TEXT default "Unknown",
          location TEXT default "Unknown"
        )]]

  self.createtablesql['levels'] = [[CREATE TABLE levels(
          level_id INTEGER NOT NULL PRIMARY KEY autoincrement,
          type TEXT default "level",
          level INT default -1,
          str INT default 0,
          int INT default 0,
          wis INT default 0,
          dex INT default 0,
          con INT default 0,
          luc INT default 0,
          starttime INT default -1,
          finishtime INT default -1,
          hp INT default 0,
          mp INT default 0,
          mv INT default 0,
          pracs INT default 0,
          trains INT default 0,
          bonustrains INT default 0,
          blessingtrains INT default 0
        )]]

  self.createtablesql['mobkills'] = [[CREATE TABLE mobkills(
          mk_id INTEGER NOT NULL PRIMARY KEY autoincrement,
          name TEXT default "Unknown",
          xp INT default 0,
          bonusxp INT default 0,
          blessingxp INT default 0,
          totalxp INT default 0,
          gold INT default 0,
          tp INT default 0,
          time INT default -1,
          vorpal INT default 0,
          banishment INT default 0,
          assassinate INT default 0,
          slit INT default 0,
          disintegrate INT default 0,
          deathblow INT default 0,
          wielded_weapon TEXT default '',
          second_weapon TEXT default '',
          room_id INT default 0,
          level INT default -1
        )]]

  self.createtablesql['gquests'] = [[CREATE TABLE gquests(
          gq_id INTEGER NOT NULL PRIMARY KEY autoincrement,
          starttime INT default 0,
          finishtime INT default 0,
          qp INT default 0,
          qpmobs INT default 0,
          gold INT default 0,
          tp INT default 0,
          trains INT default 0,
          pracs INT default 0,
          level INT default -1,
          won INT default 0
        )]]


  self.createtablesql['gqmobs'] = [[CREATE TABLE gqmobs(
          gqmob_id INTEGER NOT NULL PRIMARY KEY autoincrement,
          gq_id INT NOT NULL,
          num INT,
          name TEXT default "Unknown",
          location TEXT default "Unknown"
        )]]

  self.createtablesql['classes'] = [[CREATE TABLE classes(
          class TEXT NOT NULL PRIMARY KEY,
          remort INTEGER
        )]]

  self.createtablesql['skills'] = [[CREATE TABLE skills(
          sn INTEGER NOT NULL PRIMARY KEY,
          name TEXT default "Unknown",
          percent INT default 0,
          target INT default 0,
          type INT default 0,
          recovery INT default -1,
          spellup INT default 0,
          clientspellup INT default 0,
          clanskill INT default 0,
          mag INT default -1,
          thi INT default -1,
          war INT default -1,
          cle INT default -1,
          psi INT default -1,
          ran INT default -1,
          pal INT default -1
        )]]

  self.createtablesql['recoveries'] = [[CREATE TABLE recoveries(
          sn INTEGER NOT NULL PRIMARY KEY,
          name TEXT default "Unknown"
        )]]
end

function Statdb:getstat(stat)
  self:checktable('stats')
  local tstat = nil
  if self:open('getstat') then
    for a in self.db:nrows('SELECT * FROM stats WHERE milestone = "current"') do
      tstat = a[stat]
    end
    self:close('getstat')
  end
  return tstat
end

function Statdb:setstat(stat, value)
  self:checktable('stats')
  if self:open('setstat') then
    self.db:exec(string.format('update stats set %s=%s where milestone = "current"', stat, value))
    self:close('setstat')
  end
  return false
end

function Statdb:addtostat(stat, add)
  self:checktable('stats')
  if tonumber(add) == 0 then
    return true
  end
  if self:open('addtostat') then
    local tstat = nil
    for a in self.db:nrows('SELECT * FROM stats WHERE milestone = "current"') do
      tstat = a[stat]
    end
    if tstat == nil then
      self:close('addtostat')
      return false
    else
      tstat = tonumber(tstat) + tonumber(add)
      self.db:exec(string.format('update stats set %s=%s where milestone = "current"', stat, tstat))
      self:close('addtostat')
      return true
    end
    self:close('addtostat')
  end
  return false
end

function Statdb:savewhois(whoisinfo)
  self:checktable('stats')
  local name = self:getstat('name')
  local oldtlevel = self:getstat('totallevels')
  local oldlevel = self:getstat('level')
  if self:open('savewhois') then
    if name == nil then
      local stmt = self.db:prepare[[ INSERT INTO stats VALUES (NULL, :name, :level, :totallevels,
                                                          :remorts, :tiers,:race, :sex,
                                                          :subclass, :qpearned, :questscomplete,
                                                          :questsfailed, :campaignsdone, :campaignsfld,
                                                          :gquestswon, :duelswon, :duelslost,
                                                          :timeskilled, :monsterskilled,
                                                          :combatmazewins, :combatmazedeaths,
                                                          :powerupsall, :totaltrivia, 0, 'current') ]]

      stmt:bind_names(  whoisinfo  )
      stmt:step()
      stmt:finalize()
      self:addmilestone('start')
      phelper:mdebug("no previous stats, created new")
    else
      assert (self.db:exec("BEGIN TRANSACTION"))
      local stmt = self.db:prepare[[ UPDATE stats set level = :level, totallevels = :totallevels,
                                            remorts = :remorts, tiers = :tiers, race = :race,
                                            sex = :sex, subclass = :subclass, qpearned = :qpearned,
                                            questscomplete = :questscomplete,
                                            questsfailed = :questsfailed,
                                            campaignsdone = :campaignsdone,
                                            campaignsfld = :campaignsfld,
                                            gquestswon = :gquestswon, duelswon = :duelswon,
                                            duelslost = :duelslost, timeskilled = :timeskilled,
                                            monsterskilled = :monsterskilled,
                                            combatmazewins = :combatmazewins,
                                            combatmazedeaths = :combatmazedeaths,
                                            powerupsall = :powerupsall WHERE milestone = 'current';]]

      stmt:bind_names(  whoisinfo  )
      stmt:step()
      stmt:finalize()
      assert (self.db:exec("COMMIT"))
      phelper:mdebug("updated stats")
    end
    self:addclasses(whoisinfo['classes'])
    self:close('savewhois')
  end
end

function Statdb:addmilestone(milestone)
  self:checktable('stats')
  if not milestone or milestone == '' or milestone == 'nil' then
    return
  end
  if self:open('addmilestone') then
    local found = false
    for a in self.db:nrows('SELECT * FROM stats WHERE milestone = "' .. milestone .. '"') do
      found = true
    end
    if found then
      print("Milestone", milestone, "already exists!")
      return -1
    end
    local stats = {}
    for a in self.db:nrows('SELECT * FROM stats WHERE milestone = "current"') do
      stats = a
    end
    stats['milestone'] = milestone
    stats['time'] = GetInfo(304)
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare[[ INSERT INTO stats VALUES (NULL, :name, :level, :totallevels,
                                                          :remorts, :tiers,:race, :sex,
                                                          :subclass, :qpearned, :questscomplete,
                                                          :questsfailed, :campaignsdone, :campaignsfld,
                                                          :gquestswon, :duelswon, :duelslost,
                                                          :timeskilled, :monsterskilled,
                                                          :combatmazewins, :combatmazedeaths,
                                                          :powerupsall, :totaltrivia, :time, :milestone) ]]

    stmt:bind_names(  stats  )
    stmt:step()
    stmt:finalize()
    assert (self.db:exec("COMMIT"))
    rowid = self.db:last_insert_rowid()
    phelper:mdebug("inserted milestone:", milestone, "with rowid:", rowid)
    self:close('addmilestone')
    return rowid
  end
  return -1
end

function Statdb:savequest( questinfo )
  self:checktable('quests')
  if self:open('savequest') then
    questinfo['level'] = db:getstat('totallevels')
    if questinfo.failed == 1 then
      self:addtostat('questsfailed', 1)
    else
      self:addtostat('questscomplete', 1)
      self:addtostat('questpoints', questinfo.totqp)
      self:addtostat('qpearned', questinfo.totqp)
      self:addtostat('triviapoints', questinfo.tp)
      self:addtostat('totaltrivia', questinfo.tp)
    end

    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare(self:converttoinsert('quests'))
    stmt:bind_names(  questinfo  )
    stmt:step()
    stmt:finalize()
    assert (self.db:exec("COMMIT"))
    local rowid = self.db:last_insert_rowid()
    phelper:mdebug("inserted quest:", rowid)
    self:close('savequest')
    return rowid
  end
  return -1
end

function Statdb:savecp( cpinfo )
  self:checktable('campaigns')
  self:checktable('cpmobs')
  if self:open('savecp') then
    if cpinfo.failed == 1 then
      self:addtostat('campaignsfld', 1)
    else
      self:addtostat('campaignsdone', 1)
      self:addtostat('questpoints', cpinfo.qp)
      self:addtostat('qpearned', cpinfo.qp)
      self:addtostat('triviapoints', cpinfo.tp)
      self:addtostat('totaltrivia', cpinfo.tp)
    end

    local newlevel = getactuallevel(cpinfo.level, db:getstat('remorts'), db:getstat('tiers'))
    cpinfo.level = newlevel
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare(self:converttoinsert('campaigns'))
    stmt:bind_names(  cpinfo  )
    stmt:step()
    stmt:finalize()
    assert (self.db:exec("COMMIT"))
    local rowid = self.db:last_insert_rowid()
    phelper:mdebug("inserted cp:", rowid)
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt2 = self.db:prepare(self:converttoinsert('cpmobs'))
    for i,v in ipairs(cpinfo['mobs']) do
      v['cp_id'] = rowid
      stmt2:bind_names (v)
      stmt2:step()
      stmt2:reset()
    end
    stmt2:finalize()
    assert (self.db:exec("COMMIT"))
    self:close('savecp')
    return rowid
  end
  return -1
end

function Statdb:countlevels()
  self:checktable('levels')
  local numlevels = -1
  if self:open('countlevels') then
    for a in db.db:rows("SELECT COUNT(*) FROM levels where type = 'level'") do
      numlevels = a[1]
    end
    self:close('countlevels')
  end
  return numlevels
end

function Statdb:savelevel( levelinfo, first )
  local first = first or false
  self:checktable('levels')
  if self:open('savelevel') then
    if not first then
      if levelinfo['type'] == 'level' then
        if levelinfo['totallevels'] ~= 0 and levelinfo['totallevels'] ~= nil then
          self:setstat('totallevels', levelinfo['totallevels'])
          self:setstat('level', levelinfo['level'])
        else
          self:addtostat('totallevels', 1)
          self:addtostat('level', 1)
        end
      elseif levelinfo['type'] == 'pup' then
        self:addtostat('powerupsall', 1)
      end
      if levelinfo['totallevels'] ~= 0 and levelinfo['totallevels'] ~= nil then
        levelinfo['level'] = levelinfo['totallevels']
      else
        levelinfo['level'] = tonumber(db:getstat('totallevels'))
      end
    end
    levelinfo.finishtime = -1
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare(self:converttoinsert('levels'))
    stmt:bind_names(  levelinfo  )
    stmt:step()
    stmt:finalize()
    assert (self.db:exec("COMMIT"))
    local rowid = self.db:last_insert_rowid()
    phelper:mdebug("inserted", levelinfo['type'], ":", rowid)
    local stmt2 = self.db:exec(string.format("UPDATE levels SET finishtime = %d WHERE level_id = %d;" ,
                                          levelinfo.starttime, rowid - 1))
    rowid = self.db:last_insert_rowid()
    self:close('savelevel')
    if levelinfo['type'] == 'level' then
      self:addmilestone(tostring(levelinfo['totallevels']))
    end
    return rowid
  end
  return -1
end

function Statdb:getmobstime(starttime, finishtime)
  local mobs = {}
  local mobskilled = -1
  local mobsavexp = -1
  self:checktable('mobkills')
  if self:open('getmobstime') then
    for a in self.db:rows(string.format("SELECT count(*), AVG(xp + bonusxp) FROM mobkills where time > %d and time < %d and xp > 0", starttime, finishtime)) do
      mobskilled = a[1]
      mobsavexp = a[2]
    end
    self:close('getmobstime')
  end
  return mobskilled, mobsavexp
end

function Statdb:getmobs(etype, eid)
  local mobs = {}
  if self.createtablesql[etype] then
    self:checktable(etype)
    if self:open('getmobs') then
      for a in self.db:nrows("SELECT * FROM " .. etype ..  " WHERE " .. self.tableids[etype] .. " = " .. eid) do
        table.insert(mobs, a)
      end
      self:close('getmobs')
    end
  end
  return mobs
end

function Statdb:savemobkill( killinfo )
  self:checktable('mobkills')
  if self:open('savemobkill') then
    self:addtostat('totaltrivia', killinfo.tp)
    self:addtostat('monsterskilled', 1)
    killinfo['level'] = tonumber(db:getstat('totallevels'))
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare(self:converttoinsert('mobkills'))
    stmt:bind_names(  killinfo  )
    stmt:step()
    stmt:finalize()
    assert (self.db:exec("COMMIT"))
    local rowid = self.db:last_insert_rowid()
    phelper:mdebug("inserted mobkill:", rowid)
    self:close('savemobkill')
  end
end

function Statdb:savegq( gqinfo )
  self:checktable('gquests')
  self:checktable('gqmobs')
  if self:open('savegq') then
    self:addtostat('questpoints', gqinfo.qp)
    self:addtostat('questpoints', gqinfo.qpmobs)
    self:addtostat('qpearned', gqinfo.qp)
    self:addtostat('qpearned', gqinfo.qpmobs)
    self:addtostat('triviapoints', gqinfo.tp)
    self:addtostat('totaltrivia', gqinfo.tp)
    if gqinfo.won == 1 then
      self:addtostat('gquestswon', 1)
    end
    local newlevel = getactuallevel(gqinfo.level, db:getstat('remorts'), db:getstat('tiers'))
    gqinfo.level = newlevel
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare(self:converttoinsert('gquests'))
    stmt:bind_names(  gqinfo  )
    stmt:step()
    stmt:finalize()
    assert (self.db:exec("COMMIT"))
    local rowid = self.db:last_insert_rowid()
    phelper:mdebug("inserted gq:", rowid)
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt2 = self.db:prepare(self:converttoinsert('gqmobs'))
    for i,v in ipairs(gqinfo['mobs']) do
      v['gq_id'] = rowid
      stmt2:bind_names (v)
      stmt2:step()
      stmt2:reset()
    end
    stmt2:finalize()
    assert (self.db:exec("COMMIT"))
    self:close('savegq')
    return rowid
  end
  return -1
end

function Statdb:resetclasses()
  local stmt2 = nil
  if self:open('resetclasses') then
    assert (self.db:exec("BEGIN TRANSACTION"))
    stmt2 = self.db:prepare("INSERT INTO classes VALUES (:name, -1)")
    for i,v in pairs(classabb) do
      stmt2:bind_names ({name = i})
      stmt2:step()
      stmt2:reset()
    end
    stmt2:finalize()
    assert (self.db:exec("COMMIT"))
    self:close('resetclasses')
  end
end

function Statdb:hasclass(class)
  local remortn = -1
  local class = string.sub(class, 0, 3)
  if self:open('hasclass') then
    for a in self.db:nrows('SELECT * FROM classes WHERE class = "' .. class .. '"') do
      remortn = a['remort']
    end
    self:close('hasclass')
  end
  return remortn
end

function Statdb:getprimaryclass()
  local remortn = -1
  if self:open('getprimaryclass') then
    for a in self.db:nrows('SELECT * FROM classes WHERE remort = 1') do
      remortn = a['class']
    end
    self:close('getprimaryclass')
  end
  return remortn
end

function Statdb:getclasses()
  local classes = {}
  if self:open('getclasses') then
    for a in self.db:nrows('SELECT * FROM classes') do
      if a['remort'] ~= -1 then
        table.insert(classes, a['class'])
      end
    end
    self:close('getclasses')
  end
  return classes
end

function Statdb:addclasses(classes)
  self:checktable('classes')
  if self:open('addclasses') then
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt2 = self.db:prepare[[ UPDATE classes SET remort = :remort
                                            WHERE class = :class ]]
    for i,v in ipairs(classes) do
      stmt2:bind_names ({remort = i, class = string.sub(v, 0, 3)})
      stmt2:step()
      stmt2:reset()
    end
    stmt2:finalize()
    assert (self.db:exec("COMMIT"))
    self:close('addclasses')
  end
end

function Statdb:getlast(ttable, num, where)
  local colid = self.tableids[ttable]
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

function Statdb:getlastrow(ttable)
  local colid = self.tableids[ttable]
  local lastid = nil
  if self:open('getlastrow') then
    if colid then
      local tstring = 'SELECT MAX(' .. colid .. ') AS MAX FROM ' .. ttable
      for a in self.db:nrows(tstring) do
        lastid = a['MAX']
      end
    end
    self:close('getlastrow')
  end
  return lastid
end

function Statdb:updateskills(skills)
  self:checktable('skills')
  if self:open('updateskills') then
    local numskills = 0
    for a in db.db:rows("SELECT COUNT(*) FROM skills") do
      numskills = a[1]
    end
    local oldskills = self:getallskills()
--    if numskills == 0 or numskills ~= tableCountItems(skills) then
      --print('updating table')
      assert (self.db:exec("BEGIN TRANSACTION"))
      local stmt = self.db:prepare[[ INSERT INTO skills(sn, name, percent, target, type, recovery) VALUES (:sn, :name, :percent,
                                                            :target, :type, :recovery) ]]
      local stmtupd = self.db:prepare[[ UPDATE skills SET name = :name, percent = :percent,
                                                            target = :target, type = :type, recovery = :recovery WHERE sn = :sn]]
      --print('stmt', stmt)
      --print('stmtupd', stmtupd)
      if stmt ~= nil and stmtupd ~= nil then
        for i,v in pairs(skills) do
          if oldskills[v.sn] then
            --print('updating', v.sn)
            stmtupd:bind_names( v )
            stmtupd:step()
            stmtupd:reset()
          else
            --print('inserting', v.sn)
            stmt:bind_names(  v  )
            stmt:step()
            stmt:reset()
          end
        end
        stmt:finalize()
        stmtupd:finalize()
      end
      assert (self.db:exec("COMMIT"))
--    else
--      print('spells in db == spells in table')
--    end
    self:close('updateskills')
  end
end

function Statdb:countskills()
  self:checktable('skills')
  local numskills = 0
  if self:open('countskills') then
    for a in self.db:rows("SELECT COUNT(*) FROM skills") do
      numskills = a[1]
    end
    self:close('countskills')
  end
  return numskills
end

function Statdb:updatespellup(spellups)
  self:checktable('skills')
  if self:open('updatespellup') then
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare[[ UPDATE skills set spellup = 1 where sn = :sn ]]
    if stmt ~= nil then
      for i,v in pairs(spellups) do
        local tt = {sn=i}
        stmt:bind_names(  tt  )
        stmt:step()
        stmt:reset()
      end
      stmt:finalize()
    end
  assert (self.db:exec("COMMIT"))

  self:close('updatespellup')
  end
end

function Statdb:updateclientspellups(spellups)
  self:checktable('skills')
  if self:open('updateclientspellups') then
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare[[ UPDATE skills set clientspellup = :clientspellup where sn = :sn ]]
    if stmt ~= nil then
      for i,v in pairs(spellups) do
        --local tt = {sn=i}
        stmt:bind_names(  v  )
        stmt:step()
        stmt:reset()
      end
      stmt:finalize()
    end
    assert (self.db:exec("COMMIT"))

    self:close('updateclientspellups')
  end
end

function Statdb:updateclanskills(spellups)
  self:checktable('skills')
  if self:open('updateclanskills') then
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare[[ UPDATE skills set clanskill = :clanskill where sn = :sn ]]
    if stmt ~= nil then
      for i,v in pairs(spellups) do
        --local tt = {sn=i}
        stmt:bind_names(  v  )
        stmt:step()
        stmt:reset()
      end
      stmt:finalize()
    end
    assert (self.db:exec("COMMIT"))

    self:close('updateclanskills')
  end
end

function Statdb:lookupskillbysn(sn)
  self:checktable('skills')
  local spell = {}
  if self:open('lookupskillbysn') then
    for a in self.db:nrows('SELECT * FROM skills WHERE sn = ' .. tostring(sn)) do
      spell = a
    end
    self:close('lookupskillbysn')
    if next(spell) then
      return spell
    end
  end
  return false
end

function Statdb:lookupskillbyname(name)
  self:checktable('skills')
  local spells = {}
  if self:open('lookupskillbyname') then
    for a in self.db:nrows("SELECT * FROM skills WHERE name LIKE '%" .. tostring(name) .. "%'") do
      spells[a.name] = a
    end
    self:close('lookupskillbyname')
    if spells[tostring(name)] then
      return spells[name]
    else
      if tableCountItems(spells) > 0 then
        for i,v in pairs(spells) do
          return v
        end
      end
    end
  end
  return false
end

function Statdb:getlearnedskills()
  self:checktable('skills')
  local spells = {}
  if self:open('getlearnedskills') then
    for a in self.db:nrows("SELECT * FROM skills WHERE percent > 1 or clanskill == 1") do
      spells[a.sn] = a
    end
    self:close('getlearnedskills')
  end
  return spells
end

function Statdb:getnotlearnedskills()
  self:checktable('skills')
  local spells = {}
  if self:open('getnotlearnedskills') then
    for a in self.db:nrows("SELECT * FROM skills WHERE percent == 0 and clanskill != 1") do
      spells[a.sn] = a
    end
    self:close('getnotlearnedskills')
  end
  return spells
end

function Statdb:getnotpracticedskills()
  self:checktable('skills')
  local spells = {}
  if self:open('getnotpracticedskills') then
    for a in self.db:nrows("SELECT * FROM skills WHERE percent == 1 and clanskill != 1") do
      spells[a.sn] = a
    end
    self:close('getnotpracticedskills')
  end
  return spells
end


function Statdb:getcombatskills()
  self:checktable('skills')
  local spells = {}
  if self:open('getcombatskills') then
    for a in self.db:nrows("SELECT * FROM skills WHERE target = 2") do
      spells[a.sn] = a
    end
    self:close('getcombatskills')
  end
  return spells

end

function Statdb:getspellupskills(client)
  self:checktable('skills')
  local spells = {}
  if self:open('getspellupskills') then
    local tstring = "SELECT * FROM skills WHERE spellup = 1"
    if client then
      tstring = "SELECT * FROM skills WHERE spellup = 1 or clientspellup = 1"
    end
    for a in self.db:nrows(tstring) do
      spells[a.sn] = a
    end
    self:close('getspellupskills')
  end
  return spells
end

function Statdb:getallskills()
  self:checktable('skills')
  local spells = {}
  if self:open('getallskills') then
    for a in self.db:nrows("SELECT * FROM skills") do
      spells[a.sn] = a
    end
    self:close('getallskills')
  end
  return spells
end

function Statdb:updaterecoveries(recoveries)
  self:checktable('recoveries')
  if self:open('updaterecoveries') then
    local numrecs = 0
    for a in db.db:rows("SELECT COUNT(*) FROM recoveries") do
      numrecs = a[1]
    end
    if numrecs == 0 or numrecs ~= tableCountItems(recoveries) then
      --print('updating recoveries table')
      assert (self.db:exec("BEGIN TRANSACTION"))
      local stmt = self.db:prepare[[ REPLACE INTO recoveries(sn, name) VALUES (:sn, :name) ]]
      if stmt ~= nil then
        for i,v in pairs(recoveries) do
          stmt:bind_names(  v  )
          stmt:step()
          stmt:reset()
        end
        stmt:finalize()
      end
      assert (self.db:exec("COMMIT"))
    else
      --print('recoveries in db == recoveries in table')
    end
    self:close('updaterecoveries')
  end
end

function Statdb:countrecoveries()
  self:checktable('recoveries')
  local numskills = 0
  if self:open('countrecoveries') then
    for a in db.db:rows("SELECT COUNT(*) FROM recoveries") do
      numskills = a[1]
    end
    self:close('countrecoveries')
  end
  return numskills
end

function Statdb:getallrecoveries()
  self:checktable('recoveries')
  local spells = {}
  if self:open('getallrecoveries') then
    for a in self.db:nrows("SELECT * FROM recoveries") do
      spells[a.sn] = a
    end
    self:close('getallrecoveries')
  end
  return spells
end

function Statdb:lookuprecoverybysn(sn)
  self:checktable('recoveries')
  local recovery = {}
  if self:open('lookuprecoverybysn') then
    for a in self.db:nrows('SELECT * FROM recoveries WHERE sn = ' .. tostring(sn)) do
      recovery = a
    end
    self:close('lookuprecoverybysn')
    if next(recovery) then
      return recovery
    end
  end
  return false
end

function Statdb:lookuprecoverybyname(name)
  self:checktable('recoveries')
  local recoveries = {}
  if self:open('lookuprecoverybyname') then
    for a in self.db:nrows("SELECT * FROM recoveries WHERE name LIKE %'" .. tostring(name) .. "'%") do
      recoveries[a.name] = a
    end
    self:close('lookuprecoverybyname')
    if recoveries[tostring(name)] then
      return recoveries[name]
    else
      if tableCountItems(recoveries) > 0 then
        for i,v in pairs(recoveries) do
          return v
        end
      end
    end
  end
  return false
end

function Statdb:fixtable(tablename)
  self:backupdb('fix' .. tablename)
  if self:checkfortable(tablename) and self:open('fixtable1:' .. tablename) then
    local insertstr = self:converttoinsert(tablename)
    local oldstuff = {}
    for a in self.db:rows(string.format("SELECT * FROM %s", tablename)) do
      table.insert(oldstuff, a)
    end
    self:close('fixtable1:' .. tablename)
    self:open('fixtable2:' .. tablename)
    --self.db:exec(string.format('DROP TABLE IF EXISTS %s;', tablename))
    self:close('fixtable2:' .. tablename, true)
    self.checktable(tablename)
    if self:checkfortable(tablename) then
      self:open('fixtable3:' .. tablename)
      --check for = '' and set key to nil
    end
    self:close()
  end
end

function Statdb:updatedblqp()
  if not self:checkfortable('quests') then
    return
  end
  if self:open('updatedblqp') then
    local oldquests = {}
    for a in self.db:nrows("SELECT * FROM quests") do
      oldquests[a.quest_id] = a
    end
    self:close('updatedblqp', true)
    self:open('updatedblqp2')
    self.db:exec([[DROP TABLE IF EXISTS quests;]])
    self:close('updatedblqp2', true)
    self:open('updatedblqp3')
    self.db:exec([[CREATE TABLE quests(
      quest_id INTEGER NOT NULL PRIMARY KEY autoincrement,
      starttime INT default 0,
      finishtime INT default 0,
      mobname TEXT default "",
      mobarea TEXT default "",
      mobroom TEXT default "",
      qp INT default 0,
      double INT default 0,
      gold INT default 0,
      tier INT default 0,
      mccp INT default 0,
      lucky INT default 0,
      tp INT default 0,
      trains INT default 0,
      pracs INT default 0,
      level INT default -1,
      failed INT default 0
    )]])
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare[[ INSERT INTO quests VALUES (:quest_id, :starttime, :finishtime,
                                                          :mobname, :mobarea, :mobroom, :qp, :double,
                                                          :gold, :tier, :mccp, :lucky,
                                                          :tp, :trains, :pracs, :level, :failed) ]]

    for i,v in tableSort(oldquests, 'quest_id') do
      v['double'] = 0
      stmt:bind_names(v)
      stmt:step()
      stmt:reset()
    end
    stmt:finalize()
    assert (self.db:exec("COMMIT"))
    self:close('updatedblqp3')
  end
end

function Statdb:updatemobkills()
  if not self:checkfortable('mobkills') then
    return
  end
  if self:open('updatemobkills') then
    local oldkills = {}
    for a in self.db:nrows("SELECT * FROM mobkills") do
      oldkills[a.mk_id] = a
    end
    self:close('updatemobkills', true)
    self:open('updatemobkills2')
    self.db:exec([[DROP TABLE IF EXISTS mobkills;]])
    self:close('updatemobkills2', true)
    self:open('updatemobkills3')
    self.db:exec([[CREATE TABLE mobkills(
        mk_id INTEGER NOT NULL PRIMARY KEY autoincrement,
        name TEXT,
        xp INT default 0,
        bonusxp INT default 0,
        gold INT default 0,
        tp INT default 0,
        time INT default -1,
        vorpal INT default 0,
        banishment INT default 0,
        assassinate INT default 0,
        slit INT default 0,
        disintegrate INT default 0,
        deathblow INT default 0,
        wielded_weapon TEXT default '',
        second_weapon TEXT default '',
        room_id INT default 0,
        level INT default -1
      )]])

    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare[[ INSERT INTO mobkills VALUES (:mk_id, :name, :xp, :bonusxp,
                                                          :gold, :tp, :time, :vorpal, :banishment,
                                                          :assassinate, :slit, :disintegrate, :deathblow,
                                                          :wielded_weapon, :second_weapon, :room_id, :level) ]]
    for i,v in tableSort(oldkills, 'mk_id') do
      if v.gold == nil or v.gold == "" or type(v.gold) == 'string' then
        v.gold = 0
      end
      v['vorpal'] = 0
      v['room_id'] = -2
      if v.wielded_weapon == nil then
        v.wielded_weapon = ""
      end
      if v.wielded_weapon ~= "" then
        v['vorpal'] = 1
      end
      v['banishment'] = v['banishment'] or 0
      v['assassinate'] = v['assassinate'] or 0
      v['slit'] = v['slit'] or 0
      v['disintegrate'] = v['disintegrate'] or 0
      v['deathblow'] = v['deathblow'] or 0
      stmt:bind_names(v)
      stmt:step()
      stmt:reset()
    end
    stmt:finalize()
    assert (self.db:exec("COMMIT"))
    self:close('updatemobkills3')
  end
end

function Statdb:addmobsblessing()
  if not self:checkfortable('mobkills') then
    return
  end
  if self:open('addmobsblessing') then
    local oldkills = {}
    for a in self.db:nrows("SELECT * FROM mobkills") do
      oldkills[a.mk_id] = a
      oldkills[a.mk_id]['blessingxp'] = 0
    end
    self:close('addmobsblessing1', true)
    self:open('addmobsblessing2')
    self.db:exec([[DROP TABLE IF EXISTS mobkills;]])
    self:close('addmobsblessing2', true)
    self:open('addmobsblessing3')
    self.db:exec([[CREATE TABLE mobkills(
      mk_id INTEGER NOT NULL PRIMARY KEY autoincrement,
      name TEXT,
      xp INT default 0,
      bonusxp INT default 0,
      blessingxp INT default 0,
      totalxp INT default 0,
      gold INT default 0,
      tp INT default 0,
      time INT default -1,
      vorpal INT default 0,
      banishment INT default 0,
      assassinate INT default 0,
      slit INT default 0,
      disintegrate INT default 0,
      deathblow INT default 0,
      wielded_weapon TEXT default '',
      second_weapon TEXT default '',
      room_id INT default 0,
      level INT default -1
    )]])
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare[[ INSERT INTO mobkills VALUES (:mk_id, :name, :xp, :bonusxp, :blessingxp,
                                                          :totalxp, :gold, :tp, :time, :vorpal, :banishment,
                                                          :assassinate, :slit, :disintegrate, :deathblow,
                                                          :wielded_weapon, :second_weapon, :room_id, :level) ]]
    for i,v in tableSort(oldkills, 'mk_id') do
      if v.gold == nil or v.gold == "" or type(v.gold) == 'string' then
        v.gold = 0
      end
      if type(v.xp) == 'string' and string.find(v.xp, '+') then
        local tlist = utils.split(v.xp, '+')
        local newxp = 0
        for i,v in ipairs(tlist) do
          newxp = newxp + tonumber(v)
        end
        v.xp = newxp
      end
      if v.xp == nil or v.xp == "" or type(v.xp) == 'string' then
        v.xp = 0
      end
      if v.bonusxp == nil or v.bonusxp == "" or type(v.bonusxp) == 'string' then
        v.bonusxp = 0
      end
      v['totalxp'] = v.xp + v.bonusxp + v.blessingxp
      stmt:bind_names(v)
      stmt:step()
      stmt:reset()
    end
    stmt:finalize()
    assert (self.db:exec("COMMIT"))
    self:close('addmobsblessing3')
  end
end

function Statdb:addquestblessing()
  if not self:checkfortable('quests') then
    return
  end
  if self:open('addquestblessing1') then
    local oldquests = {}
    for a in self.db:nrows("SELECT * FROM quests") do
      oldquests[a.quest_id] = a
    end
    self:close('addquestblessing1', true)
    self:open('addquestblessing2')
    self.db:exec([[DROP TABLE IF EXISTS quests;]])
    self:close('addquestblessing2', true)
    self:open('addquestblessing3')
    self.db:exec([[CREATE TABLE quests(
      quest_id INTEGER NOT NULL PRIMARY KEY autoincrement,
      starttime INT default 0,
      finishtime INT default 0,
      mobname TEXT,
      mobarea TEXT,
      mobroom TEXT,
      qp INT default 0,
      double INT default 0,
      daily INT default 0,
      totqp INT default 0,
      gold INT default 0,
      tier INT default 0,
      mccp INT default 0,
      lucky INT default 0,
      tp INT default 0,
      trains INT default 0,
      pracs INT default 0,
      level INT default -1,
      failed INT default 0
    )]])
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare[[ INSERT INTO quests VALUES (:quest_id, :starttime, :finishtime,
                                                          :mobname, :mobarea, :mobroom, :qp, :double, :daily,
                                                          :totqp, :gold, :tier, :mccp, :lucky,
                                                          :tp, :trains, :pracs, :level, :failed) ]]

    for i,v in tableSort(oldquests, 'quest_id') do
      local totqp = v['qp'] + v['tier'] + v['mccp'] + v['lucky']
      if v['double'] == 1 then
        totqp = totqp * 2
      end
      v['daily'] = 0
      v['totqp'] = totqp
      stmt:bind_names(v)
      stmt:step()
      stmt:reset()
    end
    stmt:finalize()
    assert (self.db:exec("COMMIT"))
    self:close('addquestblessing3')
  end
end

function Statdb:addleveltrainblessing()
  if not self:checkfortable('levels') then
    return
  end
  if self:open('addleveltrainblessing') then
    self.db:exec([[ALTER TABLE levels ADD COLUMN blessingtrains INT DEFAULT 0;]])
    self.db:exec([[UPDATE levels SET blessingtrains = 0;]])
    --assert (self.db:exec("BEGIN TRANSACTION"))
    self:close('addleveltrainblessing', true)
  end
end

function Statdb:addclanskill()
  if not self:checkfortable('skills') then
    return
  end
  if self:open('addclanskill') then
    local oldskills = {}
    for a in self.db:nrows("SELECT * FROM skills") do
      oldskills[a.sn] = a
    end
    self:close('addclanskill', true)
    self:open('addqclanspellup2')
    self.db:exec([[DROP TABLE IF EXISTS skills;]])
    self:close('addaclanspellup2', true)
    self:open('addclanskill3')
    local retcode = self.db:exec([[CREATE TABLE skills(
      sn INTEGER NOT NULL PRIMARY KEY,
      name TEXT,
      percent INT default 0,
      target INT default 0,
      type INT default 0,
      recovery INT default -1,
      spellup INT default 0,
      clientspellup INT default 0,
      clanskill INT default 0,
      mag INT default -1,
      thi INT default -1,
      war INT default -1,
      cle INT default -1,
      psi INT default -1,
      ran INT default -1,
      pal INT default -1
    )]])

    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare[[ INSERT INTO skills VALUES (:sn, :name, :percent,
                                                          :target, :type, :recovery, :spellup,
                                                          :clientspellup, :clanskill,
                                                          :mag, :thi, :war, :cle, :psi,
                                                          :ran, :pal) ]]
    for i,v in tableSort(oldskills, 'sn') do
      v['clanskill'] = 0
      stmt:bind_names(v)
      stmt:step()
      stmt:reset()
    end
    stmt:finalize()
    assert (self.db:exec("COMMIT"))
    self:close('addclanskill3')

  end
end

function Statdb:updatecpmobfields()
  if not self:checkfortable('cpmobs') then
    return
  end
  if self:open('updatecpmobfields') then
    local oldcpmobs = {}
    for a in self.db:nrows("SELECT * FROM cpmobs") do
      oldcpmobs[a.cpmob_id] = a
    end
    self:close('updatecpmobfields', true)
    self:open('updatecpmobfields2')
    self.db:exec([[DROP TABLE IF EXISTS cpmobs;]])
    self:close('updatecpmobfields2', true)
    self:open('updatecpmobfields3')
    self.db:exec([[CREATE TABLE cpmobs(
          cpmob_id INTEGER NOT NULL PRIMARY KEY autoincrement,
          cp_id INT NOT NULL,
          name TEXT,
          location TEXT
        )]])
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare[[ INSERT INTO cpmobs VALUES (:cpmob_id, :cp_id,
                                                              :mobname, :mobarea) ]]

    for i,v in tableSort(oldcpmobs, 'cpmob_id') do
      stmt:bind_names(v)
      stmt:step()
      stmt:reset()
    end
    stmt:finalize()
    assert (self.db:exec("COMMIT"))
    self:close('updatecpmobfields3')
  end
end

function Statdb:updategqmobfields()
  if not self:checkfortable('gqmobs') then
    return
  end
  if self:open('updategqmobfields') then
    local oldgqmobs = {}
    for a in self.db:nrows("SELECT * FROM gqmobs") do
      oldgqmobs[a.gqmob_id] = a
    end
    self:close('updategqmobfields', true)
    self:open('updategqmobfields2')
    self.db:exec([[DROP TABLE IF EXISTS gqmobs;]])
    self:close('updategqmobfields2', true)
    self:open('updategqmobfields3')
    self.db:exec([[CREATE TABLE gqmobs(
          gqmob_id INTEGER NOT NULL PRIMARY KEY autoincrement,
          gq_id INT NOT NULL,
          num INT,
          name TEXT,
          location TEXT
        )]])
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare[[ INSERT INTO gqmobs VALUES (:gqmob_id, :gq_id, :num,
                                                              :mobname, :mobarea) ]]

    for i,v in tableSort(oldgqmobs, 'gqmob_id') do
      stmt:bind_names(v)
      stmt:step()
      stmt:reset()
    end
    stmt:finalize()
    assert (self.db:exec("COMMIT"))
    self:close('updategqmobfields3')
  end
end
