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

Statdb = Sqlitedb:subclass()

tableids = {
  levels = 'level_id',
  stats = 'stat_id',
  quests = 'quest_id',
  campaigns = 'campaigns_id',
  gquests = 'gq_id',
  mobkills = 'mk_id'
}

function Statdb:initialize(args)
  super(self, args)   -- notice call to superclass's constructor
  self.dbname = "/stats.db"
end

function Statdb:open()
  if self.db == nil then
    self.db = assert(sqlite3.open(self.dbloc .. self.dbname))
    --self.db:exec(string.format('ATTACH ' .. self.dbloc .. 'aardinfo.db AS aarddb'))
  end
  self.conns = self.conns + 1
  return true
end

function Statdb:getstat(stat)
  self:checkstatstable()
  local tstat = nil
  if self:open() then
    for a in self.db:nrows('SELECT * FROM stats WHERE milestone = "current"') do
      tstat = a[stat]
    end
    self:close()
  end
  return tstat
end

function Statdb:addtostat(stat, add)
  self:checkstatstable()
  if tonumber(add) == 0 then
    return true
  end
  if self:open() then
    local tstat = nil
    for a in self.db:nrows('SELECT * FROM stats WHERE milestone = "current"') do
      tstat = a[stat]
    end
    if tstat == nil then
      self:close()
      return false
    else
      tstat = tonumber(tstat) + tonumber(add)
      self.db:exec(string.format('update stats set %s=%s where milestone = "current"', stat, tstat))
      self:close()
      return true
    end
    self:close()
  end
  return false
end

function Statdb:checkstatstable()
  if self:open() then
    if not self:checkfortable('stats') then
      self.db:exec([[CREATE TABLE stats(
        stat_id INTEGER NOT NULL PRIMARY KEY autoincrement,
        name TEXT NOT NULL,
        level INT default 1,
        totallevels INT default 1,
        remorts INT default 1,
        tiers INT default 0,
        race TEXT,
        sex TEXT,
        subclass TEXT,
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
      )]])
    end
    self:close()
  end
end

function Statdb:savewhois(whoisinfo)
  self:checkstatstable()
  local name = self:getstat('name')
  local oldtlevel = self:getstat('totallevels')
  local oldlevel = self:getstat('level')
  if self:open() then
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
      phelper:mdebug("updated stats")
    end
    self:addclasses(whoisinfo['classes'])
    self:close()
  end
end

function Statdb:addmilestone(milestone)
  self:checkstatstable()
  if self:open() then
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
    rowid = self.db:last_insert_rowid()
    phelper:mdebug("inserted milestone:", milestone, "with rowid:", rowid)
    self:close()
    return rowid
  end
  return -1
end

function Statdb:checkquesttable()
  if self:open() then
    if not self:checkfortable('quests') then
      self.db:exec([[CREATE TABLE quests(
        quest_id INTEGER NOT NULL PRIMARY KEY autoincrement,
        starttime INT default 0,
        finishtime INT default 0,
        mobname TEXT,
        mobarea TEXT,
        mobroom TEXT,
        qp INT default 0,
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
    end
    self:close()
  end
end

function Statdb:savequest( questinfo )
  self:checkquesttable()
  if self:open() then
    questinfo['level'] = db:getstat('totallevels')
    totalqp = tonumber(questinfo.qp) + tonumber(questinfo.tier) + tonumber(questinfo.mccp) + tonumber(questinfo.lucky)
    self:addtostat('questpoints', totalqp)
    self:addtostat('qpearned', totalqp)
    self:addtostat('triviapoints', questinfo.tp)
    self:addtostat('totaltrivia', questinfo.tp)
    if questinfo.failed == 1 then
      self:addtostat('questsfailed', 1)
    else
      self:addtostat('questscomplete', 1)
    end

    local stmt = self.db:prepare[[ INSERT INTO quests VALUES (NULL, :starttime, :finishtime,
                                                          :mobname, :mobarea, :mobroom, :qp, :gold,
                                                          :tier, :mccp, :lucky,
                                                          :tp, :trains, :pracs, :level, :failed) ]]
    stmt:bind_names(  questinfo  )
    stmt:step()
    stmt:finalize()
    rowid = self.db:last_insert_rowid()
    phelper:mdebug("inserted quest:", rowid)
    self:close()
    return rowid
  end
  return -1
end

function Statdb:checkcptable()
  if self:open() then
    if not self:checkfortable('campaigns') then
      self.db:exec([[CREATE TABLE campaigns(
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
      )]])
    end
    self:close()
  end
end

function Statdb:checkcpmobstable()
  if self:open() then
    if not self:checkfortable('cpmobs') then
      self.db:exec([[CREATE TABLE cpmobs(
        cpmob_id INTEGER NOT NULL PRIMARY KEY autoincrement,
        cp_id INT NOT NULL,
        mobname TEXT,
        mobarea TEXT
      )]])
    end
    self:close()
  end
end

function Statdb:savecp( cpinfo )
  self:checkcptable()
  self:checkcpmobstable()
  if self:open() then
    self:addtostat('questpoints', cpinfo.qp)
    self:addtostat('qpearned', cpinfo.qp)
    self:addtostat('triviapoints', cpinfo.tp)
    self:addtostat('totaltrivia', cpinfo.tp)
    if cpinfo.failed == 1 then
      self:addtostat('campaignsfld', 1)
    else
      self:addtostat('campaignsdone', 1)
    end

    newlevel = getactuallevel(cpinfo.level, db:getstat('remorts'), db:getstat('tiers'))
    cpinfo.level = newlevel
    local stmt = self.db:prepare[[ INSERT INTO campaigns VALUES (NULL, :starttime, :finishtime,
                                                          :qp, :gold, :tp, :trains, :pracs, :level,
                                                          :failed) ]]
    stmt:bind_names(  cpinfo  )
    stmt:step()
    stmt:finalize()
    rowid = self.db:last_insert_rowid()
    phelper:mdebug("inserted cp:", rowid)
    local stmt2 = self.db:prepare[[ INSERT INTO cpmobs VALUES
                                      (NULL, :cp_id, :name, :room) ]]
    for i,v in ipairs(cpinfo['mobs']) do
      v['cp_id'] = rowid
      stmt2:bind_names (v)
      stmt2:step()
      stmt2:reset()
    end
    stmt2:finalize()
    self:close()
    return rowid
  end
  return -1
end

function Statdb:checklevelstable()
  if self:open() then
    if not self:checkfortable('levels') then
      self.db:exec([[CREATE TABLE levels(
        level_id INTEGER NOT NULL PRIMARY KEY autoincrement,
        type TEXT,
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
        bonustrains INT default 0
      )]])
    end
    self:close()
  end
end

function Statdb:savelevel( levelinfo )
  self:checklevelstable()
  if self:open() then
    if levelinfo['type'] == 'level' then
      self:addtostat('totallevels', 1)
      self:addtostat('level', 1)
    elseif levelinfo['type'] == 'pup' then
      self:addtostat('powerupsall', 1)
    end
    levelinfo['newlevel'] = tonumber(db:getstat('totallevels'))
    local stmt = self.db:prepare[[ INSERT INTO levels VALUES (NULL, :type, :newlevel, :str,
                                                          :int, :wis, :dex, :con,  :luc,
                                                          :time, -1, :hp, :mp, :mv, :pracs, :trains,
                                                          :bonustrains) ]]
    stmt:bind_names(  levelinfo  )
    stmt:step()
    stmt:finalize()
    rowid = self.db:last_insert_rowid()
    phelper:mdebug("inserted", levelinfo['type'], ":", rowid)
    stmt2 = self.db:exec(string.format("UPDATE levels SET finishtime = %d WHERE level_id = %d;" ,
                                          levelinfo.time, rowid - 1))
    rowid = self.db:last_insert_rowid()
    self:close()
    if levelinfo['type'] == 'level' then
      self:addmilestone(tostring(levelinfo['newlevel']))
    end
    return rowid
  end
  return -1
end

function Statdb:checkmobkillstable()
  if self:open() then
    if not self:checkfortable('mobkills') then
      self.db:exec([[CREATE TABLE mobkills(
        mk_id INTEGER NOT NULL PRIMARY KEY autoincrement,
        name TEXT,
        xp INT default 0,
        bonusxp INT default 0,
        gold INT default 0,
        tp INT default 0,
        time INT default -1,
        wielded_weapon TEXT default '',
        second_weapon TEXT default '',
        level INT default -1
      )]])
    end
    self:close()
  end
end

function Statdb:savemobkill( killinfo )
  self:checkmobkillstable()
  if self:open() then
    self:addtostat('totaltrivia', killinfo.tp)
    self:addtostat('monsterskilled', 1)
    killinfo['level'] = tonumber(db:getstat('totallevels'))
    local stmt = self.db:prepare[[ INSERT INTO mobkills VALUES (NULL, :mob, :xp, :bonusxp,
                                                          :gold, :tp, :time, :wielded_weapon, :second_weapon, :level) ]]
    stmt:bind_names(  killinfo  )
    stmt:step()
    stmt:finalize()
    rowid = self.db:last_insert_rowid()
    phelper:mdebug("inserted mobkill:", rowid)
    self:close()
  end
end

function Statdb:checkgqtable()
  if self:open() then
    if not self:checkfortable('gquests') then
      self.db:exec([[CREATE TABLE gquests(
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
      )]])
    end
    self:close()
  end
end

function Statdb:checkgqmobstable()
  if self:open() then
    if not self:checkfortable('gqmobs') then
      self.db:exec([[CREATE TABLE gqmobs(
        gqmob_id INTEGER NOT NULL PRIMARY KEY autoincrement,
        gq_id INT NOT NULL,
        num INT,
        mobname TEXT,
        mobarea TEXT
      )]])
    end
    self:close()
  end
end

function Statdb:savegq( gqinfo )
  self:checkgqtable()
  self:checkgqmobstable()
  if self:open() then
    self:addtostat('questpoints', gqinfo.qp)
    self:addtostat('qpearned', gqinfo.qp)
    self:addtostat('triviapoints', gqinfo.tp)
    self:addtostat('totaltrivia', gqinfo.tp)
    if gqinfo.won == 1 then
      self:addtostat('gquestswon', 1)
    end
    newlevel = getactuallevel(gqinfo.level, db:getstat('remorts'), db:getstat('tiers'))
    gqinfo.level = newlevel
    local stmt = self.db:prepare[[ INSERT INTO gquests VALUES (NULL, :starttime, :finishtime,
                                                          :qp, :qpmobs, :gold, :tp, :trains, :pracs, :level,
                                                          :won) ]]
    stmt:bind_names(  gqinfo  )
    stmt:step()
    stmt:finalize()
    rowid = self.db:last_insert_rowid()
    phelper:mdebug("inserted gq:", rowid)
    local stmt2 = self.db:prepare[[ INSERT INTO gqmobs VALUES
                                      (NULL, :gq_id, :num, :name, :room) ]]
    tprint(gqinfo['mobs'])
    for i,v in ipairs(gqinfo['mobs']) do
      v['gq_id'] = rowid
      stmt2:bind_names (v)
      stmt2:step()
      stmt2:reset()
    end
    stmt2:finalize()
    self:close()
    return rowid
  end
  return -1
end

function Statdb:checkclassestable()
  if self:open() then
    if not self:checkfortable('classes') then
      self.db:exec([[CREATE TABLE classes(
        class TEXT NOT NULL PRIMARY KEY,
        remort INTEGER
      )]])
      self:resetclasses()
    end
    self:close()
  end
end

function Statdb:resetclasses()
  local stmt2 = nil
  if self:open() then
    stmt2 = self.db:prepare("INSERT INTO classes VALUES (:name, -1)")
    for i,v in pairs(classabb) do
      stmt2:bind_names ({name = i})
      stmt2:step()
      stmt2:reset()
    end
    stmt2:finalize()
    self:close()
  end
end

function Statdb:hasclass(class)
  local remortn = -1
  class = string.sub(class, 0, 3)
  if self:open() then
    for a in self.db:nrows('SELECT * FROM classes WHERE class = "' .. class .. '"') do
      remortn = a['remort']
    end
    self:close()
  end
  return remortn
end

function Statdb:getprimaryclass()
  local remortn = -1
  if self:open() then
    for a in self.db:nrows('SELECT * FROM classes WHERE remort = 1') do
      remortn = a['class']
    end
    self:close()
  end
  return remortn
end

function Statdb:getclasses()
  local classes = {}
  if self:open() then
    for a in self.db:nrows('SELECT * FROM classes') do
      if a['remort'] ~= -1 then
        table.insert(classes, a['class'])
      end
    end
    self:close()
  end
  return classes
end

function Statdb:addclasses(classes)
  self:checkclassestable()
  if self:open() then
    local stmt2 = self.db:prepare[[ UPDATE classes SET remort = :remort
                                            WHERE class = :class ]]
    for i,v in ipairs(classes) do
      stmt2:bind_names ({remort = i, class = string.sub(v, 0, 3)})
      stmt2:step()
      stmt2:reset()
    end
    stmt2:finalize()
    self:close()
  end
end

function Statdb:checkitemtable()
  if self:open() then
    if not self:checkfortable('items') then
      self.db:exec([[CREATE TABLE items(
        sn INTEGER NOT NULL PRIMARY KEY,
        name TEXT,
        cleanname TEXT,
        slot INT default -1,
        flags TEXT,
      )]])
    end
    self:close()
  end
end


function Statdb:getlastrow(ttable)
  local colid = tableids[ttable]
  local lastid = nil
  if self:open() then
    if colid then
      tstring = 'SELECT MAX(' .. colid .. ') AS MAX FROM ' .. ttable
      for a in self.db:nrows(tstring) do
        lastid = a['MAX']
      end
    end
    self:close()
  end
  return lastid
end
