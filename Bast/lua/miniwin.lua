-- miniw.lua
-- $Id$
-- class for creating windows miniwindows

-- Author: Eric Davis - 28th September 2008

--[[

Exposed functions are:


Example of making a popup window:

  require "window"


TODO: add footer
TODO: add ability to load multiple fonts
TODO: fix setting header as a static line or though the style passed in
TODO: change the way show_hyperlink works to do like drawwin and use display_line
TODO: change check_font to use utils.getfontfamilies
--]]

require 'class'
require 'tprint'
require 'verify'
require 'pluginhelper'
require 'serialize'

class "Miniwin"

function Miniwin:initialize(args)
  --[[
    init the class, named arguments only
      the named arguments are
      name, header, text, font, bg_colour
      header_bg_colour, hyperlink_colour, windowpos,
      header_height, header_text_colour,
      text_colour, ishidden
  --]]
  self.set_options = {}
  self.name = args.name or "Default"
  self.win = GetPluginID()..self.name
  self.parent = args.parent or nil
  self.header = args.header or "None"
  self.text = {}
  self.children = {}
  self.hyperlink_functions = {}
  self.font_height = 0
  self.font_width = 0
  self.font_id = self.name.."_font"
  self.font_id_bold = self.name.."_font_bold"
  self.startx = 0
  self.starty = 0
  self.origx = 0
  self.origy = 0
  self.firstdrawn = true
  self.drag_hotspot = self.name .. "_drag_hotspot"


  -- below are things that can be kept as settings
  self.header_padding = 2
  self.shutdownf = false
  self.plugininit = false
  self.classinit = true
  self:add_setting( 'disabled', {type="bool", help="is this window disabled", default=verify_bool(false), sortlev=38, readonly=true})
  self:add_setting( 'windowpos', {type="number", help="position for this window: see http://www.gammon.com.au/scripts/function.php?name=WindowCreate", low=0, high=13, default=6,sortlev=38})
  self:add_setting( 'x', {type="number", help="x location of this window, -1 = auto", default=-1, sortlev=39})
  self:add_setting( 'y', {type="number", help="y location of this window, -1 = auto", default=-1, sortlev=39})
  self:add_setting( 'bg_colour', {type="colour", help="background colour for this window", default=0x00220E, sortlev=40})
  self:add_setting( 'text_colour', {type="colour", help="text colour for this window", default=0xDCDCDC, sortlev=40})
  self:add_setting( 'header_bg_colour', {type="colour", help="header colour for this window", default=0x696969, sortlev=41})
  self:add_setting( 'header_text_colour', {type="colour", help="header text colour for this window", default=0x00FF00, sortlev=41})
  self:add_setting( 'header_height', {type="number", help="the header height", default=1, low=0, high=10, sortlev=41})
  self:add_setting( 'footer_bg_colour', {type="colour", help="footer colour for this window", default=0x696969, sortlev=42})
  self:add_setting( 'footer_text_colour', {type="colour", help="footer text colour for this window", default=0x00FF00, sortlev=42})
  self:add_setting( 'font_size', {type="number", help="font_size for this window", low=2, high=30, default=8, sortlev=43})
  self:add_setting( 'font', {type="string", help="change the font for this window", default="courier new", sortlev=43})
  self:add_setting( 'width', {type="number", help="width of this window, 0 = auto", low=0, high=100, default=0, sortlev=44})
  self:add_setting( 'height', {type="number", help="height of this window, 0 = auto", low=0, high=140, default=0, sortlev=44})
  self:add_setting( 'height_padding', {type="number", help="height padding for this window", low=0, high=30, default=5, sortlev=44})
  self:add_setting( 'width_padding', {type="number", help="width padding for this window", low=0, high=30, default=5, sortlev=44})
  self.classinit = false

  self:add_setting( 'hyperlink_colour', {type="colour", help="hyperlink colour for this window", default=0x00FFFF})
  self:add_setting( 'show_hyperlinks', {type="number", help="show the default hyperlinks", low=0, high=1, default=0})

  self.default_font = nil
  self:getdefaultfont()

  self:changefont(self.font, true)

end

function Miniwin:reset()
  for i,v in pairs(self.set_options) do
    self[i] = verify(v.default, v.type, {low=v.low, high=v.high, silent=true})
  end
  self:drawwin()
end

function Miniwin:savestate()
  mdebug(self.name, 'savestate')
  for i,v in pairs(self.set_options) do
    SetVariable(i .. self.name, tostring(self[i]))
  end
  tshownf = tostring(WindowInfo(self.win, 5))
  if not self.shutdownf and not self.plugininitf then
    mdebug("saving shown as", tshownf)
    SetVariable ("shown"..self.name, tshownf)
  end
end

function Miniwin:NotifyChildren()
  for i, v in ipairs (self.children) do
    v.UpdatefromParent()
  end
end


function Miniwin:__tostring()
  return self.name
end

function Miniwin:checkfont(font)
  fonts = WindowFontList(self.win)
  found = false
  for i, v in pairs(fonts) do
    name = string.lower(WindowFontInfo (self.win, v, 21))
    if name == string.lower(font) then
      found = true
    end
  end
  return found
end

function Miniwin:getdefaultfont(font)
  check (WindowCreate (self.win,
                 0, 0, 1, 1,
                 6,   -- top right
                 0,
                 self.bg_colour) )

  check (WindowFont (self.win, "--NoFont--", "--NoFont--", 8, false, false, false, false, 0, 49))  -- normal

  fonts = WindowFontList(self.win)

  for i, v in pairs(fonts) do
    self.default_font = string.lower(WindowFontInfo (self.win, v, 21))
  end

end


function Miniwin:changefont(font, from_init)
  if not font then
    return
  end
  oldfont = self.font
  -- make miniwindow so I can grab the font info
  check (WindowCreate (self.win,
                 0, 0, 1, 1,
                 6,   -- top right
                 0,
                 self.bg_colour) )

  check (WindowFont (self.win, self.font_id, font, self.font_size, false, false, false, false, 0, 49))  -- normal
  check (WindowFont (self.win, self.font_id_bold, font, self.font_size, true, false, false, false, 0, 49))   -- bold

  self.font_height = WindowFontInfo (self.win, self.font_id, 1) + 1 -- height
  self.font_width = WindowFontInfo (self.win, self.font_id, 6)  -- avg width

  found = self:checkfont(font)

  if found then
    self.font = font
    return true
  else
    print("Font", font, "not loaded for window", self.name)
    if from_init then
      print("Using", self.default_font)
      self:changefont(self.default_font, true)
    else
      print("Falling back to", oldfont)
      self:changefont(oldfont, true)
    end
    return false
  end

end


function Miniwin:createwin (text)
  mdebug('createwin')
  if not next(text) then
    return
  end
  self.text = text
  tshow = WindowInfo(self.win, 5)
  if tshow == nil then
    tshow = false
  end
  self:drawwin()
  if self.firstdrawn then
    flag = verify_bool(GetVariable ("shown"..self.name))
    mdebug('shown', flag)
    mdebug('firstdrawn', self.firstdrawn)
    self.firstdrawn = false
    if flag == nil then
      flag = false
    end
    WindowShow(self.win, flag)
  else
    self:show(tshow)
  end
end

function Miniwin:show(flag)
  if flag == nil then
    flag = false
  end
  if self.disabled then
    WindowShow(self.win, false)
    return
  end
  WindowShow(self.win, flag)
end

function Miniwin:shutdown()
  self.shutdownf = true
end

function Miniwin:init()
  self.plugininitf = true
end

function Miniwin:enable()
  mdebug("enable", self.name)
  self.shutdownf = false
  if self.plugininitf then
    self.plugininitf = false
    self:tabbroadcast(true)
  end
  if self.disabled then
    self.disabled = false
    self:tabbroadcast(true)
  end
end

function Miniwin:disable()
  mdebug("disable", self.name)
  self.disabled = true
  self.firstdrawn = true
  WindowShow(self.win, false)
  self:tabbroadcast(false)
  self:savestate()
end

function Miniwin:toggle()
  WindowShow(self.win, not WindowInfo(self.win, 5))
  self:savestate()
end

function Miniwin:mousedown (flags, hotspotid)

  if hotspotid == self.drag_hotspot then
    -- find where mouse is so we can adjust window relative to mouse
    self.startx, self.starty = WindowInfo (self.win, 14), WindowInfo (self.win, 15)

    -- find where window is in case we drag it offscreen
    self.origx, self.origy = WindowInfo (self.win, 10), WindowInfo (self.win, 11)
  end -- if

  local f = self.hyperlink_functions[hotspotid]
  if f then
    f(self, flags, hotspotid)
    return true
  end -- function found

  return false
end -- mousedown


function Miniwin:hyperlink_configure_background ()
  local new_colour = PickColour (self.bg_colour)
  if new_colour ~= -1 then
    self.bg_colour = new_colour
    SetVariable ("bg_colour", self.bg_colour)
  end -- new colour
  self:drawwin()
end -- MiniMiniwin:hyperlink_configure_background


function Miniwin:hyperlink_configure_header ()
  local new_colour = PickColour (self.header_bg_colour)
  if new_colour ~= -1 then
    self.header_bg_colour = new_colour
    SetVariable ("header_bg_colour", self.header_bg_colour)
  end -- new colour
  self:drawwin()
end -- hyperlink_configure_header

function Miniwin:make_hyperlink (text, id, left, top, right, bottom, action, hint, cursor)

  if right == nil then
    right = left + WindowTextWidth (self.win, self.font_id, text)
  end
  if bottom == nil then
    bottom = top + self.font_height
  end

  WindowAddHotspot(self.win, id,
                    left, top, right, bottom,
                   "", -- mouseover
                   "", -- cancelmouseover
                   "mousedown",
                   "", -- cancelmousedown
                   "", -- mouseup
                   hint,
                   cursor or 1, 0)

  local retval = WindowText (self.win, self.font_id, text, left, top, right, bottom, self.hyperlink_colour)
  self.hyperlink_functions [id] = action

  return right

end -- make_hyperlink

function Miniwin:make_hyperlink_from_text (text, id, line, left, action, hint, cursor, absolute)
--[[
  local style = {}
  style.text = string.format ("Time to go: %s", quest_timer.text)
  style.len = #style.text
  style.textcolour = 'time_colour'
  style.style = 0
--]]

  if text ~= nil and text ~= '' then
    if type(text) ~= "table" then
      local style = {}
      style.text = text
      style.len = #style.text
      style.textcolour = self.hyperlink_colour
      style.start = left
      text = style
    end
  else
    print("No text for make_hyperlink_from_text")
    return
  end
  top = self:get_top_of_line(line)
  bottom = top + self.font_height

  --local retval = WindowText (self.win, self.font_id, text, left, top, right, bottom, self.hyperlink_colour)
  if text then
    start, right = self:Display_Line(line, {text}, absolute)
  end

  --mdebug("Hotspot left", start, "right", right, "top", top, "bottom", bottom)
  WindowAddHotspot(self.win, id,
                    start, top, right, bottom,
                   "", -- mouseover
                   "", -- cancelmouseover
                   "mousedown",
                   "", -- cancelmousedown
                   "", -- mouseup
                   hint,
                   cursor or 1, 0)

  self.hyperlink_functions [id] = action

  return right

end -- make_hyperlink

function Miniwin:get_colour(colour, default, return_original)
  local return_orig = return_original or false
  local tcolour = nil
  local i = 0
  local found = false
  if colour then
    local temp = colour
    while i < 5 do
      if self[temp] then
        temp = self[temp]
      elseif not self[temp] and i > 0 then
        found = true
        break
      end
      i = i + 1
    end
    if temp and found then
      colour = temp
    end
  end
  if colour then
    tcolour = verify_colour(colour, {})
    if tcolour ~= nil and tcolour ~= -1 then
      if return_orig then
        return colour
      else
        return tcolour
      end
    end
  end
  if self.parent then
    colour = self.parent:get_colour(colour, default, return_original)
    if colour then
      return colour
    end
  end
  return default
end

function Miniwin:get_top_of_line(line)
  if line > 0 then
    line = line - 1
    if self.header_height == 0  then
      return  line * self.font_height + self.height_padding
    elseif line <= self.header_height - 1 then
      return  line * self.font_height + self.height_padding
    else
      return  line * self.font_height + self.height_padding + self.header_padding
    end
  elseif line <= -1 then
    local rline = (line * self.font_height) - self.height_padding
    return self:calc_height() + rline
  end

end

function Miniwin:Display_Line (line, styles, absolute)
  local id = self.font_id
  local colour = self:get_colour("text_colour")
  local bg_colour = self:get_colour("bg_colour")
  local left = self.width_padding
  if absolute then
    left = 0
  end
  local start = -1
  local top = self:get_top_of_line(line)
  if line <= self.header_height and line > 0 then
    id = self.font_id_bold
    colour = self:get_colour("header_text_colour")
    bg_colour = self:get_colour("header_bg_colour")
  end
  --tprint(styles)
  if type(styles) == "table" then
    for _, v in ipairs (styles) do
      local tlength = WindowTextWidth (self.win, self.font_id, v.text)
      if v.start then
        if v.start == "mid" then
          local mid = (self.current_width / 2)  - (tlength / 2) - self.width_padding
          left = left + mid
        else
          left = left + v.start
        end
      end
      local tcolour = self:get_colour(v.textcolour, colour)
      if v.backcolour and not (v.backcolour == 'bg_colour') then
        -- draw background rectangle
        local bcolour = self:get_colour(v.backcolour, bg_colour)
        WindowRectOp (self.win, 2, left, top, left + tlength, top + self.font_height, bcolour)
      end
      if start == -1 then
         start = left
      end
      local tstart = left
      local textlen = WindowText (self.win, id, v.text,
                      left, top, 0, 0, tcolour)
      left = left + textlen
      --mdebug("Style Text", v.text, "left", tstart, "right", left, "top", top, "bottom", top + self.font_height)
    end -- for each style run
  else
    local tstart = left
    local textlen = WindowText (self.win, id, styles, left, top, 0, 0, colour)
    left = left + textlen
    --mdebug("Text", styles, "left", tstart, "right", left, "top", top, "bottom", top + self.font_height)
  end
  return start, left

end -- Display_Line

function Miniwin:calc_text_width(text)
  length = 0
  if type(text) == "table" then
    for _, v in ipairs (text) do
      length = length + WindowTextWidth(self.win, self.font_id, v.text)
    end
  else
    length = length + WindowTextWidth (self.win, self.font_id, text)
  end
  return length
end

function Miniwin:calc_width(minwidth)
  minwidth = minwidth or 0
  local mwidth = 0
  if self.width ~= 0 then
   return (self.width * self.font_width) + (self.width_padding * 2)
  else
    for i,v in ipairs(self.text) do
      local ttext = ""
      local twidth = 0
      if type(v) == "table" then
        for i2, v2 in ipairs(v) do
          ttext = ttext .. v2.text
        end
      else
        ttext = v
      end
      twidth = WindowTextWidth (self.win, self.font_id, ttext)
      mwidth = math.max(mwidth, twidth)
    end
    self.current_width = math.max(mwidth + (self.width_padding * 2), minwidth)
    return self.current_width
  end
end

function Miniwin:calc_height()
  if self.height == 0 or self.height == nil then
     return (#self.text) * self.font_height + (self.height_padding * 2) + self.header_padding
  else
     return self.height * self.font_height + (self.height_padding * 2) + self.header_padding
  end
end

function Miniwin:drawwin()
  --print("Got past text check")
  if not next(self.text) then
    return
  end
  local height = self:calc_height()
  local width = self:calc_width()

  -- recreate the window the correct size
  if self.x ~= -1 and self.y ~= -1 then
    check (WindowCreate (self.win,
                 self.x, self.y,   -- left, top (auto-positions)
                 width,     -- width
                 height,  -- height
                 0,
                 2,  -- flags
                 self:get_colour("bg_colour")) )
  else
    check (WindowCreate (self.win,
                 0, 0,   -- left, top (auto-positions)
                 width,     -- width
                 height,  -- height
                 self.windowpos,
                 0,  -- flags
                 self:get_colour("bg_colour")) )
  end

  -- DrawEdge rectangle
  check (WindowRectOp (self.win, 5, 0, 0, 0, 0, 10, 15))

  WindowDeleteAllHotspots (self.win)

  if self.header_height > 0 then
    -- header rectangle
     local hheight = self.font_height * self.header_height + (self.height_padding * 2) + self.header_padding
     local hheight2 = self.font_height * self.header_height + self.height_padding + self.header_padding
     if hheight ~= height then
       check (WindowRectOp (self.win, 2, 2, 2, -2, hheight2, self:get_colour("header_bg_colour")))
       check (WindowRectOp (self.win, 5, 2, 2, -2, hheight2, 5, 8))
     else
       check (WindowRectOp (self.win, 2, 2, 2, -2, hheight, self:get_colour("header_bg_colour")))
       check (WindowRectOp (self.win, 5, 2, 2, -2, hheight, 5, 8))
     end
  end

  for i, v in ipairs (self.text) do
    self:Display_Line (i, v)
  end -- for

  if self.show_hyperlinks == 1 then
    self:make_hyperlink_from_text ("?", "bg_colour", -1, width - (2 * self.font_width),
                    self.hyperlink_configure_background, "Choose background colour", nil, true)

    if self.header_height > 0 then
      self:make_hyperlink_from_text ("?", "header_bg_colour", self.header_height, width - (2 * self.font_width),
                    self.hyperlink_configure_header, "Choose header background colour", nil, true)
    end
  end

  self:make_hyperlink("", self.drag_hotspot, 0, 0, 0, self.font_height * self.header_height, empty, "Drag to move", 10)
  WindowDragHandler(self.win, self.drag_hotspot, "dragmove", "dragrelease", 0)

end


function Miniwin:set(option, value, silent)
  local changedsetting = nil
  if silent == nil or silent then
    function changedsetting(toption, tvarstuff, cvalue)

    end
  else
    function changedsetting(toption, tvarstuff, cvalue)
      plugin_header()
      if tvarstuff.type == "colour" then
        colourname = RGBColourToName(self:get_colour(cvalue))
        ColourNote("orange", "black", toption .. " set to : ",
              colourname, "black", colourname)
      else
        colourname = RGBColourToName(var.plugin_colour)
        ColourNote("orange", "black", toption .. " set to : ",
              colourname, "black", tostring(cvalue))
      end
      ColourNote("", "", "")
    end
  end

  varstuff = self.set_options[option]
  if varstuff.readonly and not self.classinit then
    plugin_header()
    ColourNote(RGBColourToName(var.plugin_colour), "", "That is a read-only var")
    ColourNote("", "", "")
    return true
  end
  if not varstuff then
    ColourNote("red", "", "Option" .. option .. "does not exist.")
    return false
  end
  if value == 'default' then
    value = varstuff.default
  end
  tvalue = verify(value, varstuff.type, {low=varstuff.low, high=varstuff.high, window=self})
  if tvalue == nil then
    ColourNote("red", "", "That is not a valid value for " .. option)
    return true
  end
  if option == "font" and not self.classinit then
    if not self:changefont(tvalue) then
      ColourNote("red", "", "Could not find font " .. tvalue)
      self:drawwin()
      return true
    end
  elseif string.find(option, "font") then
    self[option] = tvalue
    if not self.classinit then
      self:changefont(self.font)
    end
  else
    self[option] = tvalue
  end
  if option == "windowpos" then
    self.x = -1
    self.y = -1
  end
  if not self.classinit then
    --self:tabbroadcast()
    local sflag = WindowInfo(self.win, 5)
    self:drawwin()
    WindowShow(self.win, sflag)
  end
  changedsetting(option, varstuff, tvalue)
  SaveState()
  return true
end


function Miniwin:print_settings()
  for _,v in ipairs(self.skeys) do
    if self.set_options[v].get then
       value = self.set_options[v].get(i)
    else
       value = self[v]
    end
    if self.set_options[v].type == "colour" then
      value = verify_colour(value, {window = self})
    end
    print_setting_helper(v, value, self.set_options[v].help, self.set_options[v].type, self.set_options[v].readonly)
  end
end


function Miniwin:add_setting(name, setting)
  self.set_options[name] = setting
  self.skeys = sort_settings(self.set_options)

  self:set(name, verify(GetVariable(name..self.name) or setting.default, setting.type, {window = self}), true)
end

function Miniwin:dragmove(flags, hotspot_id)

  -- find where it is now
  local posx, posy = WindowInfo (self.win, 17),
                     WindowInfo (self.win, 18)

  self.x = posx - self.startx
  self.y = posy - self.starty
  -- move the window to the new location
  WindowPosition(self.win, self.x, self.y, 0, 2);

  -- change the mouse cursor shape appropriately
  if posx < 0 or posx > GetInfo (281) or
     posy < 0 or posy > GetInfo (280) then
    check (SetCursor ( 11))   -- X cursor
  else
    check (SetCursor ( 1))   -- hand cursor
  end -- if

end -- dragmove

function Miniwin:dragrelease(flags, hotspot_id)
  local newx, newy = WindowInfo (self.win, 17), WindowInfo (self.win, 18)

  -- don't let them drag it out of view
  if newx < 0 or newx > GetInfo (281) or
     newy < 0 or newy > GetInfo (280) then
     -- put it back
    if self.x ~= -1 and self.y ~= -1 then
      WindowPosition(self.win, self.origx, self.origy, 0, 2)
    else
      WindowPosition(self.win, 0, 0, self.windowpos, 0)
    end
  end -- if out of bounds

end -- dragrelease

function Miniwin:tabbroadcast(flag)
  mdebug('tabbroadcast - self.disabled', self.disabled)
  local td = {}
  td.id = GetPluginID()
  if not text then
    td.text = self.name
  else
    td.text = text
  end
  td.name = self.name
  td.win = self.win
  local wins = serialize.save( "windowstuff", td )
  if flag then
    if not self.disabled then
      broadcast(5000, wins, wins)
    end
  else
    broadcast(5001, wins, wins)
  end
end


function empty(flags, hotspot_id)

end

