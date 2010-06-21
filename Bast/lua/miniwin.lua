-- miniwin.lua
-- $Id$
-- class for creating miniwindows

-- Author: Eric Davis - 28th September 2008

--[[

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
TODO: add a miniwindow to set all settings
  - colours open PickColour
  - strings, number opens utils.editbox or utils.msgbox
  - fonts open utils.fontpicker
  - booleans toggle between true and false when clicked
--]]

require 'var'
require 'phelpobject'
require 'tprint'
require 'verify'
require 'serialize'
require 'copytable'

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
  self.clickshow = false
  self.firstdrawn = true
  self.drag_hotspot = "_drag_hotspot"

  -- below are things that can be kept as settings
  self.header_padding = 2

  self:add_cmd('toggle', {func="cmd_toggle", help="toggle window"})
  self:add_cmd('fonts', {func="cmd_fonts", help="show fonts loaded in this miniwin"})

  self:add_setting( 'disabled', {type="bool", help="is this window disabled", default=verify_bool(false), sortlev=1, readonly=true})
  self:add_setting( 'windowpos', {type="number", help="position for this window: see http://www.gammon.com.au/scripts/function.php?name=WindowCreate", low=0, high=13, default=6,sortlev=2})
  self:add_setting( 'x', {type="number", help="x location of this window, -1 = auto", default=-1, sortlev=2})
  self:add_setting( 'y', {type="number", help="y location of this window, -1 = auto", default=-1, sortlev=2})
  self:add_setting( 'bg_colour', {type="colour", help="background colour for this window", default=0x00220E, sortlev=3})
  self:add_setting( 'text_colour', {type="colour", help="text colour for this window", default=0xDCDCDC, sortlev=3})
  self:add_setting( 'hyperlink_colour', {type="colour", help="hyperlink colour for this window", default=0x00FFFF, sortlev=4})
  self:add_setting( 'header_bg_colour', {type="colour", help="header colour for this window", default=0x696969, sortlev=5})
  self:add_setting( 'header_text_colour', {type="colour", help="header text colour for this window", default=0x00FF00, sortlev=5})
  self:add_setting( 'header_height', {type="number", help="the header height", default=1, low=0, high=10, sortlev=5})
  self:add_setting( 'footer_bg_colour', {type="colour", help="footer colour for this window", default=0x696969, sortlev=6})
  self:add_setting( 'footer_text_colour', {type="colour", help="footer text colour for this window", default=0x00FF00, sortlev=6})
  self:add_setting( 'font_size', {type="number", help="font_size for this window", low=2, high=30, default=8, sortlev=43})
  self:add_setting( 'font', {type="string", help="change the font for this window", default=self:getdefaultfont(), sortlev=43})
  self:add_setting( 'width', {type="number", help="width of this window, 0 = auto", low=0, high=100, default=0, sortlev=44})
  self:add_setting( 'height', {type="number", help="height of this window, 0 = auto", low=0, high=140, default=0, sortlev=44})
  self:add_setting( 'height_padding', {type="number", help="height padding for this window", low=0, high=30, default=5, sortlev=44})
  self:add_setting( 'width_padding', {type="number", help="width padding for this window", low=0, high=30, default=5, sortlev=44})
  self:add_setting( 'use_tabwin', {type="bool", help="toggle to use tabwin", default=verify_bool(false), sortlev=50})

  self.default_font_id = '--NoFont--'
  self.default_font_id_bold = nil
  self.window_data = {}

end

function Miniwin:cmd_toggle(cmddict)
  self:toggle()
end

function Miniwin:cmd_fonts(cmddict)
  self:plugin_header('Loaded Fonts')
  local fonts = WindowFontList(self.id)
  if fonts then
    for _, v in ipairs (fonts) do
      local name = WindowFontInfo(self.id, v, 21)
      local size = tonumber(WindowFontInfo(self.id, v, 2)) - tonumber(WindowFontInfo(self.id, v, 3))
      local bold = tonumber(WindowFontInfo(self.id, v, 8)) > 400
      local italic = tonumber(WindowFontInfo(self.id, v, 16)) > 0
      local underline = tonumber(WindowFontInfo(self.id, v, 17)) > 0
      local struck = tonumber(WindowFontInfo(self.id, v, 18)) > 0
      local tlist = {}
      if bold then
        table.insert(tlist, "bold")
      end
      if italic then
        table.insert(tlist, "italic")
      end
      if underline then
        table.insert(tlist, "underline")
      end
      if struck then
        table.insert(tlist, "struck")
      end
      local flags = table.concat(tlist, ", ")
      local stuff = string.format('%-20s %-3d %s', name, size, flags)
      ColourNote(RGBColourToName(var.plugin_colour), "", stuff)
    end
  end -- if any
end

function Miniwin:savestate()
  if not self.shutdownf and not self.classinit then
    tshownf = tostring(WindowInfo(self.id, 5))
    SetVariable ("shown"..self.cname, tshownf)
  end
  super(self)
end

function Miniwin:isfontinstalled(fontid, font_name)
  if string.lower(WindowFontInfo (self.id, fontid, 21)) == string.lower(font_name) then
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

  check (WindowCreate (self.id,
                 0, 0, 1, 1,
                 6,   -- top right
                 0,
                 self.bg_colour) )

  check (WindowFont (self.id, fontid, font, size, bold, italic, underline, strikeout, 0, 49))

  if not self:isfontinstalled(fontid, font) then
    return -1
  end

  fontt.height = WindowFontInfo (self.id, fontid, 1) + 1 -- height
  fontt.width = WindowFontInfo (self.id, fontid, 6)  -- avg width
  fontt.font_name = WindowFontInfo (self.id, fontid, 21)  -- name
  fontt.bold = bold
  fontt.italic = italic
  fontt.underline = underline
  fontt.strikeout = strikeout

  self.fonts[fontid] = fontt
  return fontid

end

function Miniwin:getdefaultfont()
--  return self.id .. '_default_font'
  check (WindowCreate (self.id,
                 0, 0, 1, 1,
                 6,   -- top right
                 0,
                 verify_colour('black')) )

  check (WindowFont (self.id, "--NoFont--", "--NoFont--", 8, false, false, false, false, 0, 49))  -- normal

  return string.lower(WindowFontInfo (self.id, "--NoFont--", 21))

end

function Miniwin:createwin (text)
  if not next(text) then
    return
  end
  self.text = text
  self.window_data = {}
  self:calc_window_data()
  tshow = WindowInfo(self.id, 5)
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
    tshow = flag
  end
  self:show(tshow)
end

function Miniwin:show(flag)
  if flag == nil then
    flag = false
  end
  if verify_bool(self.disabled) then
    WindowShow(self.id, false)
    return
  end
  WindowShow(self.id, flag)
end

function Miniwin:init()
  super(self)

  self:setdefaultfont(self:addfont(self.font, self.font_size, false, false, false, false, true))
end

function Miniwin:enable()
  super(self)
  self:tabbroadcast(true)
end

function Miniwin:disable()
  self.firstdrawn = true
  self:show(false)
  self:tabbroadcast(false)
  super(self)
end

function Miniwin:toggle()
  if not self.disabled then
    self:show(not WindowInfo(self.id, 5))
  end
  self:savestate()
end

function Miniwin:addhotspot(id, left, top, right, bottom, mouseover, cancelmouseover, mousedown,
                   cancelmousedown, mouseup, hint, cursor)

  if id == nil then
   id = tostring(GetUniqueNumber())
  end

  if mousedown then
   self.hyperlink_functions['mousedown'] [id] = mousedown
   mousedown = "mousedown"
  end
  if cancelmousedown then
   self.hyperlink_functions['cancelmousedown'] [id] = cancelmousedown
   cancelmousedown = "cancelmousedown"
  end
  if mouseup then
   self.hyperlink_functions['mouseup'] [id] = mouseup
   mouseup = "mouseup"
  end
  if mouseover then
   self.hyperlink_functions['mouseover'] [id] = mouseover
   mouseover = "mouseover"
  end
  if cancelmouseover then
   self.hyperlink_functions['cancelmouseover'] [id] = cancelmouseover
   cancelmouseover = "cancelmouseover"
  end
  WindowAddHotspot(self.id, self.id .. ':' .. id,
                left, top, right, bottom,
                mouseover, -- mouseover
                cancelmouseover, -- cancelmouseover
                mousedown,
                cancelmousedown, -- cancelmousedown
                mouseup, -- mouseup
                hint,
                cursor or 1, 0)

end

function Miniwin:mousedown (flags, hotspotid)
  --print('mousedown', 'hotspotid', hotspotid)
  -- find where mouse is so we can adjust window relative to mouse
  self.startx, self.starty = WindowInfo (self.id, 14), WindowInfo (self.id, 15)

  -- find where window is in case we drag it offscreen
  self.origx, self.origy = WindowInfo (self.id, 10), WindowInfo (self.id, 11)

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
  self:addhotspot(id, left, top, right, bottom, nil, nil, action,
                   nil, nil, hint, cursor)

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
  --local retval = WindowText (self.id, self.font_id, text, left, top, right, bottom, self.hyperlink_colour)
  if text then
    left, top, right, bottom = self:Display_Line(line, ttext.text)
  end

  return right

end -- make_hyperlink_text

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
      local tlength = WindowTextWidth (self.id, font_id, strip_colours(style.text))
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
      local tlength = WindowTextWidth (self.id, self.default_font_id, linet.text[1].text)
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
end

function Miniwin:buildhotspot(style, left, top, right, bottom)

  self:addhotspot(style.hotspot_id, left, top, right, bottom, style.mouseover, style.cancelmouseover, style.mousedown,
                   style.cancelmousedown, style.mouseup, style.hint, style.cursor)

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
      Text = "@x" .. Text
    end -- if

    for colour, text in Text:gmatch ("@(%a)([^@]+)") do
      text = text:gsub ("%z", "@") -- put any @ characters back

      if need_caps then
        local count
        text, count = text:gsub ("%a", string.upper, 1)
        need_caps = count == 0 -- if not done, still need to capitalize yet
      end -- if

      if #text > 0 then
        x = x + WindowText (self.id, font_id, text, x, Top, Right, Bottom,
                            colour_conversion [colour] or self.text_colour)
      end -- some text to display

    end -- for each colour run

    return x
  end -- if

  if Capitalize then
    Text = Text:gsub ("%a", string.upper, 1)
  end -- if leading caps wanted

  return WindowText (self.id, font_id, Text, Left, Top, Right, Bottom,
                    self.text_colour)

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
  for i,v in ipairs (styles) do
    local textlen = 0
    local tstart = v.start
    local ttop = top
    if v.vjust ~= nil then
      if v.vjust == 'center' then
        local theight = self:get_line_data(line, 'height')
        local fheight = WindowFontInfo(self.id, v.font_id, 1)
        ttop = ttop + (theight - fheight) / 2
      elseif v.vjust == 'bottom' then
        local theight = self:get_line_data(line, 'height')
        local fheight = WindowFontInfo(self.id, v.font_id, 1)
        ttop = ttop + theight - fheight
      end
    end
    if v.hjust ~= nil then
      if v.hjust == 'center' then
        local twidth = self:get_line_data(line, 'width')
        local wwidth = self:calc_window_width()
        local restt = twidth - tstart
        local restw = wwidth - tstart
        tstart = tstart + (restw - restt) / 2
      elseif v.hjust == 'right' then
        local twidth = self:get_line_data(line, 'width')
        local wwidth = self:calc_window_width()
        local restt = twidth - tstart
        local restw = wwidth - tstart
        tstart = tstart + restw - restt
      end
    end
    local tlength = WindowTextWidth (self.id, v.font_id, strip_colours(v.text))
    if line <= self.header_height and line > 0 then
      def_colour = self:get_colour("header_text_colour")
      textlen = WindowText (self.id, self.default_font_id_bold, strip_colours(v.text),
                 tstart, ttop, 0, 0, def_colour)
    else
      if v.backcolour and not (v.backcolour == 'bg_colour') then
        -- draw background rectangle
        local bcolour = self:get_colour(v.backcolour, def_bg_colour)
        WindowRectOp (self.id, 2, tstart, ttop, tstart + tlength, ttop + WindowFontInfo(self.id, v.font_id, 1), bcolour)
      end
      if v.textcolour ~= nil then
        local tcolour = self:get_colour(v.textcolour)
        textlen = WindowText (self.id, v.font_id, strip_colours(v.text),
                      tstart, ttop, 0, 0, tcolour)
      elseif line <= self.header_height and line > 0 then

      else
        textlen = self:colourtext(v.font_id, v.text, tstart, ttop, 0, 0)
      end
    end
    left = tstart + textlen
    if v.mousedown ~= nil or
       v.cancelmousedown ~= nil or
       v.mouseup ~= nil or
       v.mouseover ~= nil or
       v.cancelmouseover ~= nil then
      self:buildhotspot(v, tstart, ttop, left, bottom)
    end
  end -- for each style run

  return start, top, left, bottom

end -- Display_Line

function Miniwin:calc_text_width(text)
  length = 0
  if type(text) == "table" then
    for _, v in ipairs (text) do
      length = length + WindowTextWidth(self.id, self.font_id, v.text)
    end
  else
    length = length + WindowTextWidth (self.id, self.font_id, text)
  end
  return length
end

function Miniwin:calc_header_height()
   local height = self.height_padding
   for i=1,self.header_height do
    height = height + self.window_data[i].height
   end
   return height + self.header_padding
end

function Miniwin:calc_window_height()
  local height = self.window_data.height

  if self.height > 0 then
    height = self.height
  end
  return height
end

function Miniwin:calc_window_width()
  local width = self.window_data.width

  if self.width > 0 then
    width = self.width
  end
  return width
end

function Miniwin:pre_create_window_internal()
  local height = self:calc_window_height()
  local width = self:calc_window_width()

  -- recreate the window the correct size
  if self.x ~= -1 and self.y ~= -1 then
    check (WindowCreate (self.id,
                 self.x, self.y,   -- left, top (auto-positions)
                 width,     -- width
                 height,  -- height
                 0,
                 2,  -- flags
                 self:get_colour("bg_colour")) )
  else
    check (WindowCreate (self.id,
                 0, 0,   -- left, top (auto-positions)
                 width,     -- width
                 height,  -- height
                 self.windowpos,
                 0,  -- flags
                 self:get_colour("bg_colour")) )
  end

  -- DrawEdge rectangle
  check (WindowRectOp (self.id, 5, 0, 0, 0, 0, 10, 15))

  WindowDeleteAllHotspots (self.id)

  if self.header_height > 0 then
     local hbottom = self:calc_header_height()
    -- header rectangle
     check (WindowRectOp (self.id, 2, 2, 2, -2, hbottom, self:get_colour("header_bg_colour")))
     check (WindowRectOp (self.id, 5, 2, 2, -2, hbottom, 5, 8))

  end
  self:make_hyperlink("", self.drag_hotspot, width-15, 0, 0, self:get_bottom_of_line(1), empty, "Drag to move: " .. self.cname, 10)

  WindowDragHandler(self.id, self.id .. ':' .. self.drag_hotspot, "dragmove", "dragrelease", 0)

end

function Miniwin:post_create_window_internal()
  return
end

function Miniwin:drawwin()
  --print("Got past text check")
  if not next(self.text) then
    return
  end

  self:pre_create_window_internal()

  for i, v in ipairs (self.window_data) do
    self:Display_Line (i, self.window_data[i].text)
  end -- for

  self:post_create_window_internal()

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
    retcode2 = super(self, option, tvalue, args)
    if retcode2 then
      if option == "windowpos" and not self.classinit then
        self.x = -1
        self.y = -1
      end
      if not self.classinit then
        local sflag = WindowInfo(self.id, 5)
        self:drawwin()
        self:show(sflag)
      end
      if option == 'use_tabwin' then
        self:tabbroadcast(tvalue)
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
  local posx, posy = WindowInfo (self.id, 17),
                     WindowInfo (self.id, 18)

  self.x = posx - self.startx
  self.y = posy - self.starty
  if self.x < 0 then
    self.x = 0
  end
  if self.y < 0 then
    self.y = 0
  end

  -- move the window to the new location
  WindowPosition(self.id, self.x, self.y, 0, 2);

  -- change the mouse cursor shape appropriately
  if posx < 0 or posx > GetInfo (281) or
     posy < 0 or posy > GetInfo (280) then
    check (SetCursor ( 11))   -- X cursor
  else
    check (SetCursor ( 1))   -- hand cursor
  end -- if

end -- dragmove

function Miniwin:dragrelease(flags, hotspot_id)
  local newx, newy = WindowInfo (self.id, 17), WindowInfo (self.id, 18)

  -- don't let them drag it out of view
  if newx < 0 or newx > GetInfo (281) or
     newy < 0 or newy > GetInfo (280) then
     -- put it back
    if self.x ~= -1 and self.y ~= -1 then
      WindowPosition(self.id, self.origx, self.origy, 0, 2)
    else
      WindowPosition(self.id, 0, 0, self.windowpos, 0)
    end
    SaveState()
  end -- if out of bounds

end -- dragrelease

function Miniwin:tabbroadcast(flag, text)
  local ttext = text or self.lasttabtext or self.cname
  if self.use_tabwin then
    local td = {}
    td.id = GetPluginID()
    td.name = self.cname
    if self.tabcolour then
      td.tabcolour = self.tabcolour
    end
    td.text = ttext
    td.win = self.id
    local wins = serialize.save( "windowstuff", td )
    self.lasttabtext = text
    if flag then
      if not self.disabled then
        self:broadcast(5000, wins, wins)
      end
    else
      self:broadcast(5001, wins, wins)
    end
  else
    if not flag then
      local td = {}
      td.id = GetPluginID()
      td.name = self.cname
      td.win = self.id
      local wins = serialize.save( "windowstuff", td )
      self:broadcast(5001, wins, wins)
    end
  end
end


function empty(flags, hotspot_id)

end

function popup_style(win, text, colour)
  style = {}
  style.text = text
  style.textcolour = colour
  style.mouseover = function (flags, hotspotid)
                      win:show(true)
                    end
  style.cancelmouseover = function (flags, hotspotid)
                      if not win.clickshow then
                        win:show(false)
                      end
                    end
  style.mousedown = function (flags, hotspotid)
                      win.clickshow = not win.clickshow
                    end 
  return style
end
