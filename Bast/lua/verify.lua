-- $Id$
--[[
http://code.google.com/p/bastmush
 - Documentation and examples
 
the following functions can be used to verify data, if the data is not valid for that type, nil is returned

verify_colour
  Accepts
    nil or emptystring will show PickColour dialog
    int between 0 and 16777215
    #000000 to #FFFFFF
    colour names such as gold, red
  Does not accept
    arguments with " or ' in them are automatically invalid
  stuff to put in args table
    silent - if true, will not show PickColour dialog
    
verify_string
  Accepts
    anything that can be turned into a string

verify_number
  Accepts
    anything that can be turned into a number
  stuff to put in args table
    low  - the lowest value the data can be
    high - the highest value the data can be
    silent - if true, will not print any errors
    
verify_bool
  Accepts
    booleans
    the string true, on and the number 1 will convert to the boolean true
    the string false, off and the number 0 will convert to the boolean false
    
--]]

--- verify the colour
-- if a nil value is passed, will load the Colour Chooser Dialog
function verify_colour(colour, args)
  args = args or {}
  local low = 0
  local high = 16777215
    
  -- if no argument and not silent then open PickColour Dialog
  if (colour == nil or colour == "") and not args.silent then
    colour = PickColour(0)
    if colour ~= -1 then
      return colour
    end
  end
  
  -- test if we have the chars ' or "
  local ttest = string.find(colour, '"')
  local ttest2 = string.find(colour, "'")
  if ttest ~= nil or ttest2 ~= nil then
    return nil
  end
  
  -- see if it is a number
  local tcolour = tonumber(colour)
  if tcolour and tcolour >= 0 then
    if tcolour <= high and tcolour >= low then
      return tcolour
    end
  else
  
  -- see if it is a colour name, which also works with the #000000 format
    tcolour = ColourNameToRGB (colour)
    if tcolour ~= -1 then
       return tcolour
    end
  end
    
  -- check to see if there is a colour of that name in the window
  if args.window and args.window:get_colour(colour, nil, true) ~= nil then
      return colour
  end
    
  return nil
end

function verify_string(stringval, args)
  -- check if we can turn it into a string
  if tostring(stringval) then
    return tostring(stringval)
  end
  return nil
end

function verify_number(numberval, args)
  args = args or {}
  -- turn it into a number
  tvalue = tonumber(numberval)
  
  -- check if we were successful
  if tvalue then
  
    -- check if it is lesser than the low argument
    if args.low and tvalue < args.low then
      if not args.silent then
        ColourNote("red", "white", "Value must be greater than " .. args.low)
      end
      return nil
    end
    
    -- check if is greater than the high argument
    if args.high and tvalue > args.high then
      if not args.silent then
        ColourNote("red", "white", "Value must be lower than " .. args.high)
      end
      return nil   
    end
    
    return tonumber(numberval)
  end
  
  return nil
end

function verify_bool(boolval, args)
  args = args or {}
  -- check if we already have a boolean
  if type(boolval) == "boolean" then
    return boolval
  end
  
  -- check to see if we have a 1 or 0
  tvalue = tonumber(boolval)
  if tvalue == 1 then
    return true
  elseif tvalue == 0 then
    return false
  end
  
  -- check if we have the string forms
  tvalue = tostring(boolval)
  if string.lower(tvalue) == "true" or string.lower(tvalue) == "on" then
    return true
  elseif string.lower(tvalue) == "false" or string.lower(tvalue) == "off" then
    return false
  end
  
  return nil
end

verify_table = {
               string = verify_string,
               colour = verify_colour,
               number = verify_number,
               bool = verify_bool,
              }


function verify(value, type, args)
  f = verify_table[type]
  if not f then
    ColourNote("red", "", "Not a valid option type for " .. option)
    return nil
  end
  return f(value, args)
end
