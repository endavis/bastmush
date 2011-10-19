-- $Id$
--[[

item details
 - fields
     serial (key)
     keywords
     name
     plainname
     type
     level
     worth
     weight
     wearable
     material
     score
     flags
     foundat
     clanitem

--]]

require 'tprint'
require 'verify'
require 'pluginhelper'
require 'sqlitedb'
require 'aardutils'
require 'tablefuncs'

EQdb = Sqlitedb:subclass()

tableids = {
  levels = 'level_id',
  stats = 'stat_id',
  quests = 'quest_id',
  campaigns = 'cp_id',
  gquests = 'gq_id',
  mobkills = 'mk_id',
  skills = 'sn',
}

--addleveltrainblessing
function EQdb:initialize(args)
  super(self, args)   -- notice call to superclass's constructor
  self.dbname = "\\eq.db"
  self.version = 1
  self:checkversion()
  self:turnonpragmas()
end

function EQdb:turnonpragmas()
  if self:open('turnonpragmas') then
    -- PRAGMA foreign_keys = ON;
    self.db:exec("PRAGMA foreign_keys=1;")
    -- PRAGMA journal_mode=WAL
    self.db:exec("PRAGMA journal_mode=WAL;")
    self:close('turnonpragmas')
  end
end

function EQdb:checkitemstable()
  if self:open('checkitemstable') then
    if not self:checkfortable('items') then
      self.db:exec([[CREATE TABLE items(
        serial INTEGER NOT NULL,
        shortflags TEXT,
        level NUMBER,
        name TEXT,
        plainname TEXT,
        type NUMBER,
        containerid TEXT NOT NULL,
        wearslot INTEGER,
        place INTEGER,
        UNIQUE(serial),
        PRIMARY KEY(serial, containerid));
      )]])
      self.db:exec([[CREATE INDEX IF NOT EXISTS xref_items_containerid ON items(containerid);]])
      self.db:exec([[CREATE INDEX IF NOT EXISTS xref_items_plainname ON items (plainname);]])
      self.db:exec([[CREATE INDEX IF NOT EXISTS xref_items_level ON items(level);]])
      self.db:exec([[CREATE INDEX IF NOT EXISTS xref_items_place ON items(place);]])
    end
    self:close('checkitemstable')
  end
end

function EQdb:checkitemdetailstable()
  if self:open('checkitemdetailstable') then
    if not self:checkfortable('itemdetails') then
      self.db:exec([[
        CREATE TABLE itemdetails(
          serial INTEGER NOT NULL,
          keywords TEXT,
          name TEXT,
          plainname TEXT,
          level NUMBER default 0,
          type NUMBER default 0,
          worth NUMBER default 0,
          weight NUMBER default 0,
          wearable TEXT,
          material NUMBER default 0,
          score NUMBER default 0,
          flags TEXT,
          foundat TEXT,
          fromclan TEXT,
          owner TEXT,
          UNIQUE(serial),
          PRIMARY KEY(serial));)]])
    end

    if not self:checkfortable('resistmod') then
      self.db:exec([[
        CREATE TABLE resistmod(
        rid INTEGER NOT NULL PRIMARY KEY,
        serial INTEGER NOT NULL,
        type TEXT,
        amount NUMBER default 0,
        FOREIGN KEY(serial) REFERENCES itemdetails(serial));
      )]])
    end

    if not self:checkfortable('statmod') then
      self.db:exec([[
        CREATE TABLE statmod(
        sid INTEGER NOT NULL PRIMARY KEY,
        serial INTEGER NOT NULL,
        type TEXT,
        amount NUMBER default 0,
        FOREIGN KEY(serial) REFERENCES itemdetails(serial));
      )]])
    end
    self:close('checkitemdetailstable')
  end
end

function EQdb:getitemdetails(serial)
  timer_start('EQdb:getitemdetails')
  local titem = nil
  self:checkitemdetailstable()
  if self:open('getitemdetails') then
    for a in self.db:nrows("SELECT * FROM itemdetails WHERE serial = " .. tostring(serial)) do
      titem = a
    end
    if titem then
      for a in self.db:nrows("SELECT * FROM resistmod WHERE serial = " .. tostring(serial)) do
        if not titem['resistmod'] then
          titem['resistmod'] = {}
        end
        titem['resistmod'][a.type] = a.amount
      end
    end
    if titem then
      for a in self.db:nrows("SELECT * FROM statmod WHERE serial = " .. tostring(serial)) do
        if not titem['statmod'] then
          titem['statmod'] = {}
        end
        titem['statmod'][a.type] = a.amount
      end
    end
    self:close('getitemdetails')
  end
  timer_end('EQdb:getitemdetails')
  --if titem then
  --  tprint(titem)
  --end
  return titem
end

function EQdb:addresists(item)
  timer_start('EQdb:addresists')
  if item.resistmod and next(item.resistmod) then
    self.db:exec("DELETE * from resistmod where serial = " .. tostring(item.serial))
    local stmt = self.db:prepare[[
      INSERT into resistmod VALUES (
        NULL,
        :serial,
        :type,
        :amount);]]
    for i,v in pairs(item.resistmod) do
      local resistm = {}
      resistm['serial'] = item.serial
      resistm['type'] = i
      resistm['amount'] = v
      stmt:bind_names( resistm )
      stmt:step()
      stmt:reset()
    end
    stmt:finalize()
  end
  timer_end('EQdb:addresists')
end

function EQdb:addstats(item)
  timer_start('EQdb:addstats')
  if item.statmod and next(item.statmod) then
    self.db:exec("DELETE * from statmod where serial = " .. tostring(item.serial))
    local stmt = self.db:prepare[[
      INSERT into statmod VALUES (
        NULL,
        :serial,
        :type,
        :amount);]]
    for i,v in pairs(item.statmod) do
      local statm = {}
      statm['serial'] = item.serial
      statm['type'] = i
      statm['amount'] = v
      stmt:bind_names( statm )
      stmt:step()
      stmt:reset()
    end
    stmt:finalize()
  end
  timer_end('EQdb:addstats')
end

function EQdb:additemdetail(item)
  timer_start('EQdb:additemdetail')
  --tprint(item)
  self:checkitemdetailstable()
  if self:open('additemdetail') then
    local titem = self:getitemdetails(tonumber(item.serial))
    local tchanges = self.db:total_changes()
    assert (self.db:exec("BEGIN TRANSACTION"))
    if titem then
      local stmtupd = self.db:prepare[[ UPDATE itemdetails SET
                                                  keywords = :keywords,
                                                  name = :name,
                                                  plainname = :plainname,
                                                  level = :level,
                                                  type = :type,
                                                  worth = :worth,
                                                  weight = :weight,
                                                  wearable = :wearable,
                                                  material = :material,
                                                  score = :score,
                                                  flags = :flags,
                                                  foundat = :foundat,
                                                  fromclan = :fromclan,
                                                  owner = :owner
                                                  WHERE serial = :serial;
                                                            ]]

      stmtupd:bind_names( item )
      stmtupd:step()
      stmtupd:reset()
      stmtupd:finalize()
      --local retval self.db:exec(tsql)
    else
      local stmt = self.db:prepare[[ INSERT INTO itemdetails VALUES (
                                           :serial,
                                           :keywords,
                                           :name,
                                           :plainname,
                                           :level,
                                           :type,
                                           :worth,
                                           :weight,
                                           :wearable,
                                           :material,
                                           :score,
                                           :flags,
                                           :foundat,
                                           :fromclan,
                                           :owner); ]]

      stmt:bind_names(item)
      local stepret = stmt:step()
      local resetret = stmt:reset()
      local finalret = stmt:finalize()
    end
    self:addresists(item)
    self:addstats(item)
    assert (self.db:exec("COMMIT"))
    phelper:mdebug('changes:', self.db:total_changes() - tchanges)
    self:close('additemdetail')
  end
  timer_end('EQdb:additemdetail')
end

function EQdb:additems(items)
  timer_start('EQdb:additems')
  self:checkitemstable()
  for i,v in pairs(items) do
    --print(v.containerid)
    break
  end
  --print('additems')
  if self:open('additems') then
    local tchanges = self.db:total_changes()
    assert (self.db:exec("BEGIN TRANSACTION"))
    self.db:exec("DROP INDEX IF EXISTS xref_items_container_place")
    self.db:exec("DROP INDEX IF EXISTS xref_items_containerid")
    self.db:exec("DROP INDEX IF EXISTS xref_items_plainname")
    self.db:exec("DROP INDEX IF EXISTS xref_items_level")
    self.db:exec("DROP INDEX IF EXISTS xref_items_place")
    local stmt = self.db:prepare[[ INSERT INTO items VALUES (
                                           :serial,
                                           :shortflags,
                                           :level,
                                           :name,
                                           :plainname,
                                           :type,
                                           :containerid,
                                           :wearslot,
                                           :place) ]]
    for i,v in pairs(items) do
      stmt:bind_names(v)
      local stepret = stmt:step()
      local resetret = stmt:reset()
      --print('additems: stepret', stepret)
      --print('additems: resetret', resetret)
    end
    stmt:finalize()
    self.db:exec([[CREATE INDEX IF NOT EXISTS xref_items_container_place ON items(containerid, place);]])
    self.db:exec([[CREATE INDEX IF NOT EXISTS xref_items_containerid ON items(containerid);]])
    self.db:exec([[CREATE INDEX IF NOT EXISTS xref_items_plainname ON items (plainname);]])
    self.db:exec([[CREATE INDEX IF NOT EXISTS xref_items_level ON items(level);]])
    self.db:exec([[CREATE INDEX IF NOT EXISTS xref_items_place ON items(place);]])
    assert (self.db:exec("COMMIT"))
    local rowid = self.db:last_insert_rowid()
    phelper:mdebug('rowid:', rowid)
    phelper:mdebug('changes:', self.db:total_changes() - tchanges)
    self:close('additems')
  end
  timer_end('EQdb:additems')
end

function EQdb:clearcontainer(containerid)
  timer_start('EQdb:clearcontainer')
  self:checkitemstable()
  --print('clearing container', containerid)
  if self:open('additems') then
    --assert (self.db:exec("BEGIN TRANSACTION"))
    self.db:exec("DELETE from items where containerid = '" .. tostring(containerid) .. "';")
    --assert (self.db:exec("COMMIT"))
  end
  timer_end('EQdb:clearcontainer')
end

function EQdb:reorderitems(place, containerid, removed)
  timer_start('EQdb:reorderitems')
  local titem = {containerid=containerid, place=place}
  self:checkitemstable()
  --print('reorderitems - place: ' .. tostring(place))
  --print('reorderitems - containerid: ' .. tostring(containerid))
  --print('reorderitems - removed: ' .. tostring(removed))
  if self:open('reorderitems') then
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmtremove = self.db:prepare[[ UPDATE items SET place=place - 1 WHERE place > :place AND containerid = :containerid;]]
    local stmtadd = self.db:prepare[[UPDATE items SET place=place + 1 WHERE place >= :place AND containerid = :containerid;]]
    if removed == true then
      --print('executing removed')
      --self.db:exec(string.format("UPDATE items SET place=place - 1 WHERE place > %d AND containerid = %d;", tonumber(place), tonumber(containerid)))
      --print('removed')
      stmtremove:bind_names(titem)
      stmtremove:step()
      stmtremove:reset()
    else
      --print('executing added')
      --self.db:exec(string.format("UPDATE items SET place=place + 1 WHERE place >= %d AND containerid = %d;", tonumber(place), tonumber(containerid)))
      --print('added')
      stmtadd:bind_names(titem)
      stmtadd:step()
      stmtadd:reset()
    end
    stmtadd:finalize()
    stmtremove:finalize()
    assert (self.db:exec("COMMIT"))
    self:close('reorderitems')
  end
  timer_end('EQdb:reorderitems')
end

function EQdb:reorderitemsmultiple(reorderstuff)
  timer_start('EQdb:reorderitemsmultiple')
  local titem = {containerid=containerid, place=place}
  self:checkitemstable()
  if self:open('getitems') then
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmtremove = self.db:prepare[[ UPDATE items SET place=place - 1 WHERE containerid = :containerid and place > :place;]]
    local stmtadd = self.db:prepare[[UPDATE items SET place=place + 1 WHERE containerid = :containerid AND place >= :place;]]
    for i,v in pairs(reorderstuff) do
      if v.removed == true then
        --print('removed')
        stmtremove:bind_names(v)
        stmtremove:step()
        stmtremove:reset()
      else
        --print('added')
        stmtadd:bind_names(v)
        stmtadd:step()
        stmtadd:reset()
      end
    end
    stmtadd:finalize()
    stmtremove:finalize()
    assert (self.db:exec("COMMIT"))
    self:close('getitem')
  end
  timer_end('EQdb:reorderitemsmultiple')
end

function EQdb:updateitemlocation(item)
  timer_start('EQdb:updateitemlocation')
  self:checkitemstable()
  if self:open('updateitemlocation') then
    assert (self.db:exec("BEGIN TRANSACTION"))
    self.db:exec(string.format("UPDATE items SET containerid = '%s', wearslot = %d, place = %d where serial = %d;",
                                     tostring(item.containerid), tonumber(item.wearslot),
                                     tonumber(item.place), tonumber(item.serial)))
    assert (self.db:exec("COMMIT"))
    self:close('updateitemlocation')
  end
  timer_end('EQdb:updateitemlocation')
end

function EQdb:updateitem(item)
  timer_start('EQdb:updateitem')
  self:checkitemstable()
  if self:open('updateitem') then
    assert (self.db:exec("BEGIN TRANSACTION"))
    self.db:exec(string.format([[UPDATE items SET shortflags = '%s',
                                                  level= %d,
                                                  name = '%s',
                                                  plainname = '%s',
                                                  type = %d,
                                                  containerid = '%s',
                                                  wearslot = %d,
                                                  place = %d
                                                  WHERE serial = %d;]],
                                     tostring(item.shortflags), tonumber(item.level),
                                     tostring(item.name), tostring(item.plainname), tonumber(item.type),
                                     tostring(item.containerid), tonumber(item.wearslot),
                                     tonumber(item.place), tonumber(item.serial)))
    assert (self.db:exec("COMMIT"))
    self:close('updateitem')
  end
  timer_end('EQdb:updateitem')
end

function EQdb:getitem(serial)
  timer_start('EQdb:getitem')
  local item = false
  self:checkitemstable()
  if self:open('getitem') then
    for a in self.db:nrows("SELECT * FROM items WHERE serial = '" .. tostring(serial) .. "'") do
      item = a
    end
    self:close('getitem')
  end
  timer_end('EQdb:getitem')
  return item
end

function EQdb:getitemsbywearslot(wearslot)
  timer_start('EQdb:getitemsbywearslot')
  local items = {}
  self:checkitemstable()
  if self:open('getitemsbywearslot') then
    for a in self.db:nrows("SELECT * FROM items WHERE wearslot=" .. tostring(wearslot) ..";") do
      items[a.serial] = a
    end
    self:close('getitemsbywearslot')
  end
  timer_end('EQdb:getitemsbywearslot')
  --print('getitemsbywearslot', wearslot)
  --tprint(items)
  return items
end


function EQdb:getcontainercontents(containerid, sortkey, reverse, itype)
  if not sortkey then
    sortkey = 'place'
  end
  timer_start('EQdb:getcontainercontents')
  local sqlstr = "SELECT * FROM items WHERE containerid = '%s' "
  if itype then
    sqlstr = sqlstr .. " AND type = " .. tostring(itype)
  end
  sqlstr = sqlstr .. " ORDER BY ".. tostring(sortkey) .. " "
  if reverse then
    sqlstr = sqlstr .. "DESC"
  end
  sqlstr = sqlstr .. ";"
  local items = {}
  self:checkitemstable()
  if self:open('getcontainercontents') then
    for a in self.db:nrows(string.format(sqlstr, containerid)) do
      table.insert(items, a)
    end
    self:close('getcontainercontents')
  end
  timer_end('EQdb:getcontainercontents')
  return items
end

function EQdb:removeitems(items)
  timer_start('EQdb:removeitems')
  self:checkitemstable()
  if self:open('removeitems') then
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare[[ DELETE from items where serial = :serial; ]]
    for i,v in pairs(items) do
      stmt:bind_names(v)
      stmt:step()
      stmt:reset()
    end
    stmt:finalize()
    assert (self.db:exec("COMMIT"))
    local rowid = self.db:last_insert_rowid()
    self:close('removeitems')
  end
  timer_end('EQdb:removeitems')
end

function EQdb:getcontainers()
  timer_start('EQdb:getcontainers')
  containers = {}
  self:checkitemstable()
  if self:open('getcontainers') then
    for a in self.db:nrows("SELECT * FROM items WHERE type = 11") do
      table.insert(containers, a)
    end
    self:close('updateitemlocation')
  end
  timer_end('EQdb:getcontainers')
  return containers
end

function putobjectininv(item)
  local teqdb = EQdb:new{}
  local item = teqdb:getitem(item.serial)
  if item.containerid == 'Worn' then
    SendNoEcho('remove ' .. item.serial)
  elseif item.containerid ~= 'Inventory' then
    SendNoEcho('get ' .. item.serial .. ' ' .. item.containerid)
  end
end

function putobjectbackinplace(item, container)
  if container == 'Worn' then
    SendNoEcho('wear ' .. item.serial)
  elseif container ~= 'Inventory' then
    SendNoEcho('put ' .. item.serial .. ' ' .. trim(container))
  end
end

