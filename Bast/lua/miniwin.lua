-- miniwin.lua
-- $Id$
-- class for creating windows miniwindows

-- Author: Eric Davis - 28th September 2008

--[[

Exposed functions are:


Example of making a popup window:

  require "window"

styles can have the following
  style.text = 'text'
  style.textcolour
  style.backcolour
  style.start - absolute position to start
  style.hjust - can be set to center to put text in the center of the window on that line (default is top)
    values: 'left', 'center', 'right'
  style.vjust - can be set to vertically adjust text (comes into play when a line has several sizes of text)
    values: 'top', 'center', 'bottom'
  style.font_name
    if a font can't be loaded, then the default font is used
  style.font_size
  style.bold
  style.italic
  style.underline
  style.strikeout
  style.hotspot_id
  style.mousedown
  style.cancelmousedown
  style.mouseup
  style.mouseover
  style.cancelmouseover
  style.cursor
  style.hint

TODO: add footer
TODO: fix setting header as a static line or though the style passed in
--]]

require 'phelpobject'
require 'tprint'
require 'verify'
require 'pluginhelper'
require 'serialize'
require 'copytable'

DEFAULT_COLOUR = "@w"
TRANSPARENCY_COLOUR = 0x080808
BORDER_WIDTH = 2

local BLACK = 1
local RED = 2
local GREEN = 3
local YELLOW = 4
local BLUE = 5
local MAGENTA = 6
local CYAN = 7
local WHITE = 8

-- colour styles (eg. @r is normal red, @R is bold red)

-- @- is shown as ~
-- @@ is shown as @

-- This table uses the colours as defined in the MUSHclient ANSI tab, however the
-- defaults are shown on the right if you prefer to use those.

colour_conversion = {
   k = GetNormalColour (BLACK)   ,   -- 0x000000
   r = GetNormalColour (RED)     ,   -- 0x000080
   g = GetNormalColour (GREEN)   ,   -- 0x008000
   y = GetNormalColour (YELLOW)  ,   -- 0x008080
   b = GetNormalColour (BLUE)    ,   -- 0x800000
   m = GetNormalColour (MAGENTA) ,   -- 0x800080
   c = GetNormalColour (CYAN)    ,   -- 0x808000
   w = GetNormalColour (WHITE)   ,   -- 0xC0C0C0
   K = GetBoldColour   (BLACK)   ,   -- 0x808080
   R = GetBoldColour   (RED)     ,   -- 0x0000FF
   G = GetBoldColour   (GREEN)   ,   -- 0x00FF00
   Y = GetBoldColour   (YELLOW)  ,   -- 0x00FFFF
   B = GetBoldColour   (BLUE)    ,   -- 0xFF0000
   M = GetBoldColour   (MAGENTA) ,   -- 0xFF00FF
   C = GetBoldColour   (CYAN)    ,   -- 0xFFFF00
   W = GetBoldColour   (WHITE)   ,   -- 0xFFFFFF

   -- add custom colours here

  }  -- end conversion table

-- take a string, and remove colour codes from it (eg. "@Ghello" becomes "hello"
function strip_colours (s)
  s = s:gsub ("@%-", "~")    -- fix tildes
  s = s:gsub ("@@", "\0")  -- change @@ to 0x00
  s = s:gsub ("@%a([^@]*)", "%1")
  return (s:gsub ("%z", "@")) -- put @ back
end -- strip_colours


Miniwin = Phelpobject:subclass()

function Miniwin:initialize(args)
  --[[

  --]]
  super(self, args)
  self.win = GetPluginID()..self.cname
  self.parent = args.parent or nil
  self.header = args.header or "None"
  self.text = {}
  self.children = {}
  self.hyperlink_functions = {}
  self.hyperlink_functions['mousedown'] = {}
  self.hyperlink_functions['cancelmousedown'] = {}
  self.hyperlink_functions['mouseup'] = {}
  self.hyperlink_functions['mouseover'] = {}
  self.hyperlink_functions['cancelmouseover'] = {}
  self.fonts = {}
  self.startx = 0
  self.starty = 0
  self.origx = 0
  self.origy = 0
  self.firstdrawn = true
  self.drag_hotspot = self.cname .. "_drag_hotspot"

  -- below are things that can be kept as settings
  self.header_padding = 2
  self.shutdownf = false
  self.plugininitf = false

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
  self:add_setting( 'font', {type="string", help="change the font for this window", default=self:getdefaultfont(), sortlev=43})
  self:add_setting( 'width', {type="number", help="width of this window, 0 = auto", low=0, high=100, default=0, sortlev=44})
  self:add_setting( 'height', {type="number", help="height of this window, 0 = auto", low=0, high=140, default=0, sortlev=44})
  self:add_setting( 'height_padding', {type="number", help="height padding for this window", low=0, high=30, default=5, sortlev=44})
  self:add_setting( 'width_padding', {type="number", help="width padding for this window", low=0, high=30, default=5, sortlev=44})
  self.classinit = false

  self:add_setting( 'hyperlink_colour', {type="colour", help="hyperlink colour for this window", default=0x00FFFF})
  self:add_setting( 'show_hyperlinks', {type="number", help="show the default hyperlinks", low=0, high=1, default=0})

  self.default_font_id = '--NoFont--'
  self.default_font_id_bold = nil
  self.window_data = {}
  self:setdefaultfont(self:addfont(self.font, self.font_size, false, false, false, false, true))

end


function Miniwin:savestate()
  super(self)
  tshownf = tostring(WindowInfo(self.win, 5))
  if not self.shutdownf and not self.plugininitf then
    SetVariable ("shown"..self.cname, tshownf)
  end
end

function Miniwin:isfontinstalled(fontid, font_name)
  if string.lower(WindowFontInfo (self.win, fontid, 21)) == string.lower(font_name) then
    return true
  end
  return false

end

function Miniwin:checkfontid(font)
  font = string.lower(font)
  local fontv = self.fonts[font]
  if fontv == nil then
    return false
  end
  return true
end

function Miniwin:buildfontid(font, size, bold, italic, underline, strikeout)
  local nfont = font:gsub(' ', '_')
  nfont = nfont:lower()
  local fontid = nfont .. '-' .. size
  if bold then
    fontid = fontid .. '-bold'
  end
  if italic then
    fontid = fontid .. '-italic'
  end
  if underline then
    fontid = fontid .. '-underline'
  end
  if strikeout then
    fontid = fontid .. '-strikeout'
  end
  return fontid
end

function Miniwin:setdefaultfont(fontid)
  self.default_font_id = fontid
  self.default_font_id_bold =  self:addfont(self.fonts[self.default_font_id].font_name,
               self.fonts[self.default_font_id].size,
               true, false, false, false, false)
  SaveState()
end

function Miniwin:addfont(font, size, bold, italic, underline, strikeout)
  local fontt = {}
  if bold == nil then
    bold = false
  end
  if italic == nil then
    italic = false
  end
  if underline == nil then
    underline = false
  end
  if strikeout == nil then
    strikeout = false
  end
  size = size or self.font_size
  local fontid = self:buildfontid(font, size, bold, italic, underline, strikeout)
  if self:checkfontid(fontid) then
    return fontid
  end
  fontt.fontid = fontid
  fontt.size = size

  check (WindowCreate (self.win,
                 0, 0, 1, 1,
                 6,   -- top right
                 0,
                 self.bg_colour) )

  check (WindowFont (self.win, fontid, font, size, bold, italic, underline, strikeout, 0, 49))

  if not self:isfontinstalled(fontid, font) then
    return -1
  end

  fontt.height = WindowFontInfo (self.win, fontid, 1) + 1 -- height
  fontt.width = WindowFontInfo (self.win, fontid, 6)  -- avg width
  fontt.font_name = WindowFontInfo (self.win, fontid, 21)  -- name
  fontt.bold = bold
  fontt.italic = italic
  fontt.underline = underline
  fontt.strikeout = strikeout

  self.fonts[fontid] = fontt
  return fontid

end

function Miniwin:getdefaultfont()
--  return self.win .. '_default_font'
  check (WindowCreate (self.win,
                 0, 0, 1, 1,
                 6,   -- top right
                 0,
                 self:get_colour("bg_colour")) )

  check (WindowFont (self.win, "--NoFont--", "--NoFont--", 8, false, false, false, false, 0, 49))  -- normal

  return string.lower(WindowFontInfo (self.win, "--NoFont--", 21))

end

function Miniwin:createwin (text)
  if not next(text) then
    return
  end
  self.text = text
  self.window_data = {}
  self:calc_window_data()
  tshow = WindowInfo(self.win, 5)
  if tshow == nil then
    tshow = false
  end
  self:drawwin()
  if self.firstdrawn then
    flag = verify_bool(GetVariable ("shown"..self.cname))
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
  self:disable()
end

function Miniwin:init()
  --print("initialize miniwin")
  self.plugininitf = true
  self:disable()
end

function Miniwin:enable()
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
  if not self.plugininitf then
    self.disabled = true
  end
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

  -- find where mouse is so we can adjust window relative to mouse
  self.startx, self.starty = WindowInfo (self.win, 14), WindowInfo (self.win, 15)

  -- find where window is in case we drag it offscreen
  self.origx, self.origy = WindowInfo (self.win, 10), WindowInfo (self.win, 11)

  local f = self.hyperlink_functions['mousedown'][hotspotid]
  if f then
    f(self, flags, hotspotid)
    return true
  end -- function found

  return false
end -- mousedown

function Miniwin:cancelmousedown (flags, hotspotid)

  local f = self.hyperlink_functions['cancelmousedown'][hotspotid]
  if f then
    f(self, flags, hotspotid)
    return true
  end -- function found

  return false
end -- mousedown

function Miniwin:mouseover (flags, hotspotid)

  local f = self.hyperlink_functions['mouseover'][hotspotid]
  if f then
    f(self, flags, hotspotid)
    return true
  end -- function found

  return false
end -- mousedown

function Miniwin:cancelmouseover (flags, hotspotid)

  local f = self.hyperlink_functions['cancelmouseover'][hotspotid]
  if f then
    f(self, flags, hotspotid)
    return true
  end -- function found

  return false
end -- mousedown

function Miniwin:mouseup (flags, hotspotid)

  local f = self.hyperlink_functions['mouseup'][hotspotid]
  if f then
    f(self, flags, hotspotid)
    return true
  end -- function found

  return false
end -- mousedown

function Miniwin:hyperlink_configure_background ()
  self:set('bg_colour', nil)
  self:createwin(self.text)
end -- MiniMiniwin:hyperlink_configure_background


function Miniwin:hyperlink_configure_header ()
  self:set('header_bg_colour', nil)
  self:createwin(self.text)
end -- hyperlink_configure_header

function Miniwin:make_hyperlink (text, id, left, top, right, bottom, action, hint, cursor)
  if text == "" or not text then
    return self:make_hyperlink_regular(id, left, top, right, bottom, action, hint, cursor)
  else
    return self:make_hyperlink_text(text, id, left, top, right, bottom, action, hint, cursor)
  end
end

function Miniwin:make_hyperlink_regular(id, left, top, right, bottom, action, hint, cursor)
  if right == nil then
    right = 0
  end
  if bottom == nil then
    bottom = top + self.fonts[self.default_font_id].height
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

  self.hyperlink_functions['mousedown'][id] = action

  return right

end -- make_hyperlink_regular

function Miniwin:make_hyperlink_text (text, id, line, left, action, hint, cursor, absolute)
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
      style.mousedown = action
      style.vjust = 'center'
      style.hint = hint
      style.cursor = cursor
      style.hotspot_id = id
      text = style
    end
  else
    print("No text for make_hyperlink_from_text")
    return
  end

  ttext = self:convert_line(line, {text})

--  tprint(ttext)
  --local retval = WindowText (self.win, self.font_id, text, left, top, right, bottom, self.hyperlink_colour)
  if text then
    left, top, right, bottom = self:Display_Line(line, ttext.text)
  end

  return right

end -- make_hyperlink_text

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

function Miniwin:get_line_position(line, what)
  local start = 0
  if line == 0 then
    return -1
  end
  if line < 0 then
    line = #(self.window_data) + 1 + line
    if line < 0 then
      return -1
    end
  end

  if self.header_height == 0  or line <= self.header_height then
    start = self.height_padding
  else
    start = self.height_padding + (self.header_padding  * 2)
  end
  if what == 'top' then
    endline = line - 1
  elseif what == 'bottom' then
    endline = line
  end
  for i=1,endline do
    start = start + self:get_line_data(i, 'height')
  end
  return start
end


function Miniwin:get_top_of_line(line)
  return self:get_line_position(line, 'top')
end

function Miniwin:get_bottom_of_line(line)
  return self:get_line_position(line, 'bottom')
end

function Miniwin:get_line_data(line, type)
  if line > 0 then
    return self.window_data[line][type]
  elseif line < 0 then
    return self.window_data[#(self.window_data) + 1 + line][type]
  end
  return -1
end

function Miniwin:adjust_lines()
  local widthchanged = false
  return widthchanged
end

function Miniwin:convert_line(line, styles)
  local linet = {}
  local def_font_id = self.default_font_id
  local maxfontheight = 0
  local start = self.width_padding
  if line <= self.header_height and line > 0 then
    def_font_id = self.default_font_id_bold
  end
  linet.text = {}
  if type(styles) == 'table' then
    for i,style in ipairs(styles) do
      table.insert(linet.text, i, {})
      font_id = self:addfont(style.font_name or self.fonts[def_font_id].font_name,
                      style.font_size or self.fonts[def_font_id].size,
                      style.bold or self.fonts[def_font_id].bold,
                      style.italic or self.fonts[def_font_id].italic,
                      style.underline or self.fonts[def_font_id].underline,
                      style.strikeout or self.fonts[def_font_id].strikeout)

      maxfontheight = math.max(maxfontheight, self.fonts[font_id].height)
      local tlength = WindowTextWidth (self.win, font_id, strip_colours(style.text))
      if style.start and style.start > start then
        linet.text[i].start = style.start
        start = style.start + tlength
      else
        linet.text[i].start = start
        start = start + tlength
      end
      linet.text[i].font_id = font_id
      linet.text[i].text = style.text
      linet.text[i].textcolour = style.textcolour
      linet.text[i].backcolour = style.backcolour
      linet.text[i].hfunction = style.hfunction
      linet.text[i].hjust = style.hjust
      linet.text[i].vjust = style.vjust
      linet.text[i].hotspot_id = style.hotspot_id
      linet.text[i].mousedown = style.mousedown
      linet.text[i].cancelmousedown = style.cancelmousedown
      linet.text[i].mouseup = style.mouseup
      linet.text[i].mouseover = style.mouseover
      linet.text[i].cancelmouseover = style.cancelmouseover
      linet.text[i].hint = style.hint
    end
  else
      table.insert(linet.text, 1, {})
      linet.text[1].font_id = self.default_font_id
      linet.text[1].text = styles
      linet.text[1].start = start
      maxfontheight = math.max(maxfontheight, self.fonts[self.default_font_id].height)
      local tlength = WindowTextWidth (self.win, self.default_font_id, linet.text[1].text)
      start = start + tlength
  end
  linet.width = start + self.width_padding
  linet.height = maxfontheight
  return linet
end

function Miniwin:calc_window_data()
  local height = 0
  if type(self.text) == 'table' then
    local maxwidth = 0
    for line,v in ipairs(self.text) do
      tline = self:convert_line(line, v)
      self.window_data[line] = tline
      maxwidth = math.max(maxwidth, self.window_data[line].width)
    end
    self.window_data.height = self:get_bottom_of_line(-1) + self.height_padding
    self.window_data.width = maxwidth
  end
  while self:adjust_lines() do

  end
end

function Miniwin:buildhotspot(style, left, top, right, bottom)
  local mousedown = ""
  local cancelmousedown = ""
  local mouseup = ""
  local mouseover = ""
  local cancelmouseover = ""
  id = style.hotspot_id or tostring(GetUniqueNumber())
  if style.mousedown then
   self.hyperlink_functions['mousedown'] [id] = style.mousedown
   mousedown = "mousedown"
  end
  if style.cancelmousedown then
   self.hyperlink_functions['cancelmousedown'] [id] = style.cancelmousedown
   cancelmousedown = "cancelmousedown"
  end
  if style.mouseup then
   self.hyperlink_functions['mouseup'] [id] = style.mouseup
   mouseup = "mouseup"
  end
  if style.mouseover then
   self.hyperlink_functions['mouseover'] [id] = style.mouseover
   mouseover = "mouseover"
  end
  if style.cancelmouseover then
   self.hyperlink_functions['cancelmouseover'] [id] = style.cancelmouseover
   cancelmouseover = "cancelmouseover"
  end
  WindowAddHotspot(self.win, id,
                left, top, right, bottom,
                mouseover, -- mouseover
                cancelmouseover or "", -- cancelmouseover
                mousedown or "",
                cancelmousedown or "", -- cancelmousedown
                mouseup or "", -- mouseup
                style.hint or "",
                style.cursor or 1, 0)
end

-- displays text with colour codes imbedded
--
-- win: window to use
-- font_id : font to use
-- Text : what to display
-- Left, Top, Right, Bottom : where to display it
-- Capitalize : if true, turn the first letter into upper-case

function Miniwin:colourtext (font_id, Text, Left, Top, Right, Bottom, Capitalize)

  if Text:match ("@") then
    local x = Left  -- current x position
    local need_caps = Capitalize

    Text = Text:gsub ("@%-", "~")    -- fix tildes
    Text = Text:gsub ("@@", "\0")  -- change @@ to 0x00

    -- make sure we start with @ or gsub doesn't work properly
    if Text:sub (1, 1) ~= "@" then
      Text = DEFAULT_COLOUR .. Text
    end -- if

    for colour, text in Text:gmatch ("@(%a)([^@]+)") do
      text = text:gsub ("%z", "@") -- put any @ characters back

      if need_caps then
        local count
        text, count = text:gsub ("%a", string.upper, 1)
        need_caps = count == 0 -- if not done, still need to capitalize yet
      end -- if

      if #text > 0 then
        x = x + WindowText (self.win, font_id, text, x, Top, Right, Bottom,
                            colour_conversion [colour] or GetNormalColour (WHITE))
      end -- some text to display

    end -- for each colour run

    return x
  end -- if

  if Capitalize then
    Text = Text:gsub ("%a", string.upper, 1)
  end -- if leading caps wanted

  return WindowText (self.win, font_id, Text, Left, Top, Right, Bottom,
                    colour_conversion [DEFAULT_COLOUR] or GetNormalColour (WHITE))

end -- colourtext


function Miniwin:Display_Line (line, styles)
  local def_font_id = self.default_font_id
  local def_colour = self:get_colour("text_colour")
  local def_bg_colour = self:get_colour("bg_colour")
  local left = self.width_padding
  local start = left
  local largestwidth = 0
  local bottom = self:get_bottom_of_line(line)
  local top = self:get_top_of_line(line)
  if line <= self.header_height and line > 0 then
    def_font_id = self.default_font_id .. '_bold'
    def_colour = self:get_colour("header_text_colour")
    def_bg_colour = self:get_colour("header_bg_colour")
  end
  for i,v in ipairs (styles) do
    local tstart = v.start
    local ttop = top
    if v.vjust ~= nil then
      if v.vjust == 'center' then
        local theight = self:get_line_data(line, 'height')
        local fheight = WindowFontInfo(self.win, v.font_id, 1)
        ttop = ttop + (theight - fheight) / 2
      elseif v.vjust == 'bottom' then
        local theight = self:get_line_data(line, 'height')
        local fheight = WindowFontInfo(self.win, v.font_id, 1)
        ttop = ttop + theight - fheight
      end
    end
    if v.hjust ~= nil then
      if v.hjust == 'center' then
        local twidth = self:get_line_data(line, 'width')
        local wwidth = self.window_data.width
        local restt = twidth - tstart
        local restw = wwidth - tstart
        tstart = tstart + (restw - restt) / 2
      elseif v.hjust == 'right' then
        local twidth = self:get_line_data(line, 'width')
        local wwidth = self.window_data.width
        local restt = twidth - tstart
        local restw = wwidth - tstart
        tstart = tstart + restw - restt
      end
    end
    local tlength = WindowTextWidth (self.win, v.font_id, strip_colours(v.text))
    if v.backcolour and not (v.backcolour == 'bg_colour') then
      -- draw background rectangle
      local bcolour = self:get_colour(v.backcolour, def_bg_colour)
      WindowRectOp (self.win, 2, tstart, ttop, tstart + tlength, ttop + WindowFontInfo(self.win, v.font_id, 1), bcolour)
    end
    local textlen = 0
    if v.textcolour ~= nil then
      local tcolour = self:get_colour(v.textcolour, def_colour)
      textlen = WindowText (self.win, v.font_id, strip_colours(v.text),
                    tstart, ttop, 0, 0, tcolour)
    else
      textlen = self:colourtext(v.font_id, v.text, tstart, ttop, 0, 0)
    end
    left = tstart + textlen

    if v.mousedown or v.cancelmousedown or v.mouseup or v.mouseover or v.cancelmouseover then
        self:buildhotspot(v, tstart, ttop, left, bottom)
    end
  end -- for each style run

  return start, top, left, bottom

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

function Miniwin:calc_header_height()
   local height = 0
   for i=1,self.header_height do
    height = height + self.window_data[i].height
   end
   return height
end

function Miniwin:drawwin()
  --print("Got past text check")
  if not next(self.text) then
    return
  end
  local height = self.window_data.height
  local width = self.window_data.width

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
     local hbottom = self:get_bottom_of_line(self.header_height) + self.header_padding
    -- header rectangle
     check (WindowRectOp (self.win, 2, 2, 2, -2, hbottom, self:get_colour("header_bg_colour")))
     check (WindowRectOp (self.win, 5, 2, 2, -2, hbottom, 5, 8))

    self:make_hyperlink("", self.drag_hotspot, 0, 0, 0, hbottom, empty, "Drag to move", 10)
  else
    self:make_hyperlink("", self.drag_hotspot, 0, 0, 0, self:get_bottom_of_line(1), empty, "Drag to move", 10)
  end

  for i, v in ipairs (self.window_data) do
    self:Display_Line (i, self.window_data[i].text)
  end -- for

  if self.show_hyperlinks == 1 then
    self:make_hyperlink_text ("?", "bg_colour", -1, width - (2 * self.fonts[self.default_font_id].width),
                    self.hyperlink_configure_background, "Choose background colour", nil, true)

    if self.header_height > 0 then
      self:make_hyperlink ("?", "header_bg_colour", self.header_height, width - (2 * self.fonts[self.default_font_id].width),
                    self.hyperlink_configure_header, "Choose header background colour", nil, true)
    end
  end

  WindowDragHandler(self.win, self.drag_hotspot, "dragmove", "dragrelease", 0)



-- show all fonts
-- fonts = WindowFontList(self.win)
--
-- if fonts then
--   for _, v in ipairs (fonts) do
--     print (v, WindowFontInfo(self.win, v, 21), WindowFontInfo(self.win, v, 19),WindowFontInfo(self.win, v, 8), WindowFontInfo(self.win, v, 1))
--   end
-- end -- if any

end


function Miniwin:set(option, value, args)
  retcode, tvalue = self:checkvalue(option, value, args)
  if retcode == true then
    if string.find(option, "font") and not self.classinit then
      local font_name = nil
      local font_size = nil
      if option == 'font' then
        font_name = tvalue
      end
      if option == 'font_size' then
        font_size = tvalue
      end
      font_name = font_name or self.fonts[self.default_font_id].font_name
      font_size = font_size  or self.fonts[self.default_font_id].size
      font_id = self:addfont(font_name,
                    font_size,
                    self.fonts[self.default_font_id].bold,
                    self.fonts[self.default_font_id].italic,
                    self.fonts[self.default_font_id].underline,
                    self.fonts[self.default_font_id].strikeout)
      if font_id == -1 then
        ColourNote("red", "", "Could not find font " .. font_name .. " with size " .. tostring(font_size))
        return false
      else
        self:setdefaultfont(font_id)
        self:createwin(self.text)
      end
    end
    retcode2 = super(self, option, value, args)
    if retcode2 then
      if option == "windowpos" then
        self.x = -1
        self.y = -1
      end
      if not self.classinit then
        local sflag = WindowInfo(self.win, 5)
        self:drawwin()
        WindowShow(self.win, sflag)
      end
      return true
    else
      return false
    end

  elseif retcode == 1 then
    return true
  else
    return false
  end

  return true
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
  local td = {}
  td.id = GetPluginID()
  if not text then
    td.text = self.cname
  else
    td.text = text
  end
  td.name = self.cname
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

