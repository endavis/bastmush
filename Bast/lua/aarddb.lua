-- $Id$
require 'class'
require 'tprint'
require 'verify'
require 'pluginhelper'

class "Aarddb"(Sqlitedb)

function Aarddb:initialize(args)
  super(args)   -- notice call to superclass's constructor
  self.dbname = "/info.db"
end

function Aarddb:checkareastable()
  self:open()
  if not self:checkfortable('areas') then
    self.db:exec([[CREATE TABLE areas(
      are_id INTEGER NOT NULL PRIMARY KEY autoincrement,  
      name TEXT UNIQUE NOT NULL,
      from INT default 1,
      to INT default 1,
      lock INT default 0,
      author TEXT,
      speedwalk TEXT,
      keyword TEXT
     )]])
  end
  self:close()
end

function Aarddb:addareas(area_list)
  self:checkareastable()
  self:open()
  local stmt = self.db:prepare[[ INSERT INTO areas VALUES (NULL, :name, :from,  
                                                        :to, :lock, :author, :speedwalk, :keyword) ]]  
  
  
  self:close()
end
