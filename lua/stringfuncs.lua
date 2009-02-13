-- $Id$
[[--
http://code.google.com/p/bastmush
 - Documentation and examples
 
functions in this module
 strip - strip a string of all forward and trailing whitespace
--]]
 
function strip (str)
    s, _ =  string.gsub (str, "^%s*(.-)%s*$", "%1")
    return s
end
