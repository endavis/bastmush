-- this finds a file from the path directory, searching in all subdirectories

function scan_dir_for_file (path, tfile, directoryonly)

  -- find all files in that directory
  local t = assert (utils.readdir (path .. "\\*"))

  for k, v in pairs (t) do
   if not v.hidden and
      not v.system and
      k:sub (1, 1) ~= "." then
      -- recurse to process file or subdirectory
      if v.directory then
        local found = scan_dir_for_file (path .. "\\" .. k, tfile, directoryonly)
        if found then
          return found
        end
      elseif k == tfile then
        if directoryonly then
          return path .. "\\"
        else
          return path .. "\\" .. k
        end
      end -- if 

   end -- if

  end -- for
  return false
end
