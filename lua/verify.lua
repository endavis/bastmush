-- $Id$
require "tprint"


--- verify the colour
-- if a nil value is passed, will load the Colour Chooser Dialog
function verify_colour(colour, args)
  args = args or {}
  local low = 0
  local high = 16777215
    
  if (colour == nil or colour == "") and not args.silent then
    colour = PickColour(0)
    if colour ~= -1 then
      return colour
    end
  end
  
  local ttest = string.find(colour, '"')
  if ttest ~= nil then
    return nil
  end
  -- see if it is a number
  local tcolour = tonumber(colour)
  if tcolour and tcolour >= 0 then
    if tcolour <= high and tcolour >= low then
      return tcolour
    end
  else
  -- see if it is a colour name
  
    tcolour = ColourNameToRGB (colour)
    --print("ColourNameToRGB tcolour: ", tcolour)
    if tcolour ~= -1 then
       return tcolour
    end
  end
    
  if args.window and args.window:get_colour(colour, nil, true) ~= nil then
      return colour
  end
    
  return nil
end

function verify_string(stringval, args)
  if type(stringval) == "string" then
    return stringval
  end
  if tostring(stringval) then
    return tostring(stringval)
  end
  return nil
end

function verify_number(numberval, args)
  tvalue = tonumber(numberval)
  if tvalue then
    if args.low and tvalue < args.low then
      if not args.silent then
        ColourNote("red", "white", "Value must be greater than " .. args.low)
      end
      return nil
    end
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
  if type(boolval) == "boolean" then
    return boolval
  end
  tvalue = tonumber(boolval)
  if tvalue == 1 then
    return true
  elseif tvalue == 0 then
    return false
  end
  tvalue = tostring(boolval)
  if tvalue == "true" then
    return true
  elseif tvalue == "false" then
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
