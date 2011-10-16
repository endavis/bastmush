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
  self:turnonwal()
end

function EQdb:turnonwal()
  if self:open('turnonwal') then
   --PRAGMA journal_mode=WAL
    self.db:exec("PRAGMA journal_mode=WAL;")
    self:close('turnonwal')
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

function EQdb:additems(items)
  timer_start('EQdb:additems')
  self:checkitemstable()
  for i,v in pairs(items) do
    --print(v.containerid)
    break
  end
  print('additems')
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
  print('clearing container', containerid)
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
                                                  where serial = %d;]],
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
