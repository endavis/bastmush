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
    window to lookup the colour in the window

verify_string
  Accepts
    anything that can be turned into a string
  stuff to put in args table
    silent - if true, will not print any errors
    msg to show a message in the input box

verify_number
  Accepts
    anything that can be turned into a number
  stuff to put in args table
    low  - the lowest value the data can be
    high - the highest value the data can be
    silent - if true, will not print any errors
    msg to show a message in the input box

verify_bool
  Accepts
    booleans
    the string true, on and the number 1 will convert to the boolean true
    the string false, off and the number 0 will convert to the boolean false

--]]

--- verify the colour
-- if a nil value is passed, will load the Colour Chooser Dialog
function verify_colour(colour, args)
  -- set args.silent to true to not use the pickcolour dialog when the colour is nil
  -- set args.window to lookup the colour in the window
  args = args or {}
  local low = 0
  local high = 16777215

  -- if no argument and not silent then open PickColour Dialog
  if (colour == nil or colour == "") and not args.silent then
    local tcolour = args.default or 0
    colour = PickColour(tcolour)
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
  -- set args.msg to show a message in the input box
  if (stringval == nil or stringval == '') and not args.silent then
     local msg = ''
     if args.help then
       msg = args.help .. '\n'
     end
     if args.msg then
       msg = args.msg .. '\n'
     end
     local tmsg = args.default or ""
     stringval = tostring(utils.inputbox(msg), "", tmsg)
  end

  -- check if we can turn it into a string
  if tostring(stringval) then
    return tostring(stringval)
  end
  return nil
end

function verify_number(numberval, args)
  -- set args.msg to show a message in the input box
  -- set args.silent to not show inputbox when set to nil
  -- set args.low to set the low threshhold
  -- set args.high to set the high threshhold
  local args = args or {}
  -- turn it into a number
  local tvalue = tonumber(numberval)

  if tvalue == nil and not args.silent then
     local msg = ''
     if args.help then
       msg = args.help .. '\n'
     end
     if args.msg then
       msg = args.msg .. '\n'
     end
     if args.low and args.high then
       msg = msg .. 'Must be between ' .. tostring(args.low) .. ' and ' .. tostring(args.high)
     elseif args.low then
       msg = msg .. 'Must be greater than or equal to ' .. tostring(args.low)
     elseif args.high then
       msg = msg .. 'Must be less that or equal to '  .. tostring(args.high)
     end
     if args.default then
       msg = msg .. '\nThe default value is ' .. tostring(args.default)
     end
     local tmsg = args.default or ""
     tvalue = tonumber(utils.inputbox(msg, "", tmsg))
  end

  -- check if we were successful
  if tvalue ~= nil then

    -- check if it is lesser than the low argument
    if args.low and tvalue < args.low then
      if not args.silent then
        ColourNote("red", "white", "Value must be greater than or equal to " .. args.low)
      end
      return nil
    end

    -- check if is greater than the high argument
    if args.high and tvalue > args.high then
      if not args.silent then
        ColourNote("red", "white", "Value must be lower than or equal to " .. args.high)
      end
      return nil
    end

    return tonumber(tvalue)
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
  local tvalue = tonumber(boolval)
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

function isfontinstalled(fontid, font_name, win)
  local twin = win or "test_font"
  if string.lower(WindowFontInfo (twin, fontid, 21)) == string.lower(font_name) then
    return true
  end
  return false

end

function verify_font(fonttable, args)
  local fontt = {}
  if fonttable == nil then
    fontt.bold = false
    fontt.italic = false
    fontt.underline = false
    fontt.strikeout = false
    fontt.name = ""
    fontt.size = ""
  else
    fontt.bold = verify_bool(fonttable.bold)
    fontt.italic = verify_bool(fonttable.italic)
    fontt.underline = verify_bool(fonttable.underline)
    fontt.strikeout = verify_bool(fonttable.strikeout)
    fontt.name = string.lower(fonttable.name or "")
    fontt.size = tonumber(fonttable.size or "8")
  end

  if fontt.name == '' or fontt.size == '' or args.ask then
    if fontt.size == '' then
      fontt.size = 8
    end
    wanted_font = utils.fontpicker (fontt.name, fontt.size) --font dialog
    if wanted_font then
      fontt = wanted_font
    else
      return nil
    end
  end

  fontt.name = string.lower(fontt.name)

  local fontid = tostring(fontt.name) .. '_' .. tostring(fontt.size)
  local twinid = '_fonttest'

  check (WindowCreate (twinid,
                 0, 0, 1, 1,
                 6,   -- top right
                 0,
                 000000) )

  check (WindowFont (twinid, fontid, fontt.name, fontt.size, fontt.bold, fontt.italic, fontt.underline, fontt.strikeout, 0, 49))

  local found = nil
  if isfontinstalled(fontid, fontt.name, twinid) then
    found = fontt
  end

  check (WindowDelete (twinid))
  return found

end

function formatfont(font)
  return font.name .. ', ' .. font.size
end

function verify_aardcolour(colour, args)
  local tcolour, number = colour:match("^@([xcmyrgbwCMYRGBWD])(.*)$")
  if tcolour ~= nil and tcolour ~= 'x' and (number == nil or number == '') then
    return colour
  elseif tcolour == 'x' then
    local ton = tonumber(number)
    if ton and ton >= 0 and ton <= 255 then
      return colour
    end
  end
  return nil
end

function verify_table(tableval, args)
  if type(tableval) == 'table' then
    return tableval
  end
  return nil
end

verify_table = {
               string = verify_string,
               colour = verify_colour,
               number = verify_number,
               bool = verify_bool,
               font = verify_font,
               table = verify_table,
               aardcolour = verify_aardcolour,
              }

function verify(value, ttype, args)
  if ttype == nil then
    ColourNote("red", "", "Type is nil for value" .. tostring(value))
    return
  end
  f = verify_table[ttype]
  if not f then
    ColourNote("red", "", "Not a valid option type for " .. value)
    return nil
  end
  return f(value, args)
end

