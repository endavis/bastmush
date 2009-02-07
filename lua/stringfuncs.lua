function strip (str)
    s, _ =  string.gsub (str, "^%s*(.-)%s*$", "%1")
    return s
end
