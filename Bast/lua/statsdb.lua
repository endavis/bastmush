-- $Id$
--[[



QP/TP per level
SELECT AVG(qp + mccp + lucky + tier), AVG(tp) FROM quests GROUP BY level;
SELECT AVG(qp), AVG(tp) FROM campaigns GROUP BY level;

QP/TP/XP Hourly stats
SELECT SUM(qp + mccp + lucky + tier), SUM(tp) FROM quests WHERE finishtime > now - 1 hour;
SELECT SUM(qp), SUM(tp) FROM campaigns WHERE finishtime > now - 1 hour;
SELECT SUM(xp + bonusxp) FROM mobkils WHERE time > now - 1 hour;

--]]

require 'class'
require 'tprint'
require 'verify'
require 'pluginhelper'
require 'sqlitedb'
require 'aardutils'


class "Statdb"(Sqlitedb)

function Statdb:initialize(args)
  super(args)   -- notice call to superclass's constructor
  self.dbname = "/stats.db"
end

function Statdb:getstat(stat)
  self:open()
  local tstat = nil
  for a in self.db:nrows('SELECT * FROM stats WHERE stat_id = 1') do 
     tstat = a[stat]
  end
  self:close()
  return tstat
end

function Statdb:addtostat(stat, add)
  if tonumber(add) == 0 then
    return true
  end
  self:open()
  local tstat = nil
  for a in self.db:nrows('SELECT * FROM stats WHERE stat_id = 1') do 
     tstat = a[stat]
  end
  if tstat == nil then
    self:close()
    return false
  else
    tstat = tonumber(tstat) + tonumber(add)
    self.db:exec(string.format("update stats set %s=%s where stat_id = 1", stat, tstat))
    self:close()
    return true
  end
end

function Statdb:checkstatstable()
  self:open()
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
      combatmazekills INT default 0,
      combatmazedeaths INT default 0,
      powerupsall INT default 0,
      totaltrivia INT default 0
     )]])
  end
  self:close()
end

function Statdb:savewhois(whoisinfo)
  self:checkstatstable()
  local name = self:getstat('name')
  self:open()
  if name == nil then
    local stmt = self.db:prepare[[ INSERT INTO stats VALUES (NULL, :name, :level, :totallevels, :remorts, :tiers, :race, :sex, :subclass,
                                                        :qpearned, :questscomplete, :questsfailed, :campaignsdone, :campaignsfld,
                                                        :gquestswon, :duelswon, :duelslost, :timeskilled, :monsterskilled,
                                                        :combatmazekills, :combatmazedeaths, :powerupsall, :totaltrivia) ]]
                
    stmt:bind_names(  whoisinfo  )
    stmt:step()
    stmt:finalize()  
  else
    local stmt = self.db:prepare[[ UPDATE stats set level = :level, totallevels = :totallevels, remorts = :remorts, tiers = :tiers, 
                                           race = :race, sex = :sex, subclass = :subclass, qpearned = :qpearned,
                                           questscomplete = :questscomplete, questsfailed = :questsfailed, 
                                           campaignsdone = :campaignsdone, campaignsfld = :campaignsfld,
                                           gquestswon = :gquestswon, duelswon = :duelswon, duelslost = :duelslost, 
                                           timeskilled = :timeskilled, monsterskilled = :monsterskilled,
                                           combatmazekills = :combatmazekills, combatmazedeaths = :combatmazedeaths,
                                           powerupsall = :powerupsall WHERE name = :name;]]
    stmt:bind_names(  whoisinfo  )
    stmt:step()
    stmt:finalize()      
  end
  self:close()  
end

function Statdb:checkquesttable()
  self:open()
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

function Statdb:savequest( questinfo )
  self:checkquesttable()
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
  self:open()
  local stmt = self.db:prepare[[ INSERT INTO quests VALUES (NULL, :starttime, :finishtime, 
                                                        :mobname, :mobarea, :mobroom, :qp, :gold, 
                                                        :tier, :mccp, :lucky, 
                                                        :tp, :trains, :pracs, :level, :failed) ]]
  stmt:bind_names(  questinfo  )
  stmt:step()
  stmt:finalize()  
  rowid = self.db:last_insert_rowid()
  mdebug("inserted quest:", rowid)
  self:close() 
end

function Statdb:checkcptable()
  self:open()
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

function Statdb:checkcpmobstable()
  self:open()
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

function Statdb:savecp( cpinfo )
  self:checkcptable()
  self:checkcpmobstable()
  self:addtostat('questpoints', cpinfo.qp)
  self:addtostat('qpearned', cpinfo.qp)
  self:addtostat('triviapoints', cpinfo.tp)
  self:addtostat('totaltrivia', cpinfo.tp)  
  if cpinfo.failed == 1 then
    self:addtostat('campaignsfld', 1)
  else
    self:addtostat('campaignsdone', 1)
  end  
  self:open()
  newlevel = getactuallevel(db:getstat('remorts'), cpinfo.level)
  cpinfo.level = newlevel
  local stmt = self.db:prepare[[ INSERT INTO campaigns VALUES (NULL, :starttime, :finishtime,  
                                                        :qp, :gold, :tp, :trains, :pracs, :level, 
                                                        :failed) ]]
  stmt:bind_names(  cpinfo  )
  stmt:step()
  stmt:finalize()  
  rowid = self.db:last_insert_rowid()
  mdebug("inserted cp:", rowid)
  for i,v in ipairs(cpinfo['mobs']) do
    v['cp_id'] = rowid
    local stmt2 = self.db:prepare[[ INSERT INTO cpmobs VALUES 
                                    (NULL, :cp_id, :name, :room) ]]
    stmt2:bind_names (v)
    stmt2:step()
    stmt2:finalize()
  end
  self:close() 
end

function Statdb:checklevelstable()
  self:open()
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

function Statdb:savelevel( levelinfo )
  self:checklevelstable()
  self:addtostat('totallevels', 1)     
  levelinfo['newlevel'] = tonumber(db:getstat('totallevels'))
  self:open()
  local stmt = self.db:prepare[[ INSERT INTO levels VALUES (NULL, :type, :newlevel, :str, 
                                                        :int, :wis, :dex, :con,  :luc,
                                                        :time, -1, :hp, :mp, :mv, :pracs, :trains, 
                                                        :bonustrains) ]]
  stmt:bind_names(  levelinfo  )
  stmt:step()
  stmt:finalize()  
  rowid = self.db:last_insert_rowid()
  mdebug("inserted level:", rowid)  
  stmt2 = self.db:exec(string.format("UPDATE levels SET finishtime = %d WHERE level_id = %d;" , levelinfo.time, rowid - 1))
  rowid = self.db:last_insert_rowid()
  self:close() 
end

function Statdb:checkmobkillstable()
  self:open()
  if not self:checkfortable('mobkills') then
    self.db:exec([[CREATE TABLE mobkills(
      mk_id INTEGER NOT NULL PRIMARY KEY autoincrement,
      name TEXT,
      xp INT default 0,
      bonusxp INT default 0,
      gold INT default 0,
      tp INT default 0,
      time INT default -1,
      level INT default -1
    )]])
  end
  self:close()
end

function Statdb:savemobkill( killinfo )
  self:checkmobkillstable()  
  self:addtostat('totaltrivia', killinfo.tp)  
  killinfo['level'] = tonumber(db:getstat('totallevels'))
  self:open()  
  local stmt = self.db:prepare[[ INSERT INTO mobkills VALUES (NULL, :mob, :xp, :bonusxp, 
                                                        :gold, :tp, :time, :level) ]]
  stmt:bind_names(  killinfo  )
  stmt:step()
  stmt:finalize() 
  rowid = self.db:last_insert_rowid()
  mdebug("inserted mobkill:", rowid)  
  self:close()        
end

function Statdb:checkgqtable()
  self:open()
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

function Statdb:checkgqmobstable()
  self:open()
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

function Statdb:savegq( gqinfo )
  self:checkgqtable()
  self:checkgqmobstable()
  self:addtostat('questpoints', gqinfo.qp)
  self:addtostat('qpearned', gqinfo.qp)
  self:addtostat('triviapoints', gqinfo.tp)
  self:addtostat('totaltrivia', gqinfo.tp)  
  if gqinfo.won == 1 then
    self:addtostat('gquestswon', 1)
  end  
  self:open()
  newlevel = getactuallevel(db:getstat('remorts'), gqinfo.level)
  gqinfo.level = newlevel
  local stmt = self.db:prepare[[ INSERT INTO gquests VALUES (NULL, :starttime, :finishtime,  
                                                        :qp, :qpmobs, :gold, :tp, :trains, :pracs, :level, 
                                                        :won) ]]
  stmt:bind_names(  gqinfo  )
  stmt:step()
  stmt:finalize()  
  rowid = self.db:last_insert_rowid()
  mdebug("inserted gq:", rowid)
  for i,v in ipairs(gqinfo['mobs']) do
    v['gq_id'] = rowid
    local stmt2 = self.db:prepare[[ INSERT INTO gqmobs VALUES 
                                    (NULL, :gq_id, :num, :name, :room) ]]
    stmt2:bind_names (v)
    stmt2:step()
    stmt2:finalize()
  end
  self:close() 
end
