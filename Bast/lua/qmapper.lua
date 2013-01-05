
function querymapper(sqlt)
  local stuff = {}
  local mapdb = assert (sqlite3.open(GetInfo (66) .. Trim (WorldName ()) .. ".db"))
  if mapdb then
    for a in mapdb:nrows(sqlt) do
      table.insert(stuff, a)
    end
    mapdb:close()
  end
  return stuff
end