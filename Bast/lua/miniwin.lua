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

  -- next 4 use WindowLine to draw lines
  style.leftborder (true or false)
  style.rightborder (true or false)
  style.bottomborder (true or false)
  style.topborder (true or false)

  -- uses WindowRectOp to draw line around cell
  style.cellborder (true or false)

  style.bordercolour (default white)
  style.borderstyle (default 0)
  style.borderwidth (default 1)

  style.image = {}
  style.image.name
  style.image.width
  style.image.height
  style.image.mode
  style.image.srcleft
  style.image.srctop
  style.image.srcright
  style.image.srcbottom

  style.circleOp = {}
  style.circleOp.width
  style.circleOp.height
  style.circleOp.pencolour
  style.circleOp.penstyle
  style.circleOp.penwidth
  style.circleOp.brushcolour
  style.circleOp.brushstyle
  style.circleOp.extra1
  style.circleOp.extra2
  style.circleOp.extra3
  style.circleOp.extra4  

Button Notes:
-------------------------------------
  self:add_button('minimize', {text=" - ", upfunction=function (win, tflags, hotspotid)
                        win:shade()
                      end, hint="Click to shade", place=1})

  text = text for the button
  upfunction = function when mouseup on this button
  hint = the hint for the button
  place = place of the button in the titlebar, anything <= 50 is on the left side of the bar, anything > 50 is on the right side


TODO: add footer, this could be used for resizing, tabs, status bar type things
TODO: resize flag that would make the border be used for resizing, the border will need to be a seperate miniwindow
TODO: add scrollbar for windows that only show a certain amount of text, see the miniwindow chat plugin
TODO: add a specific line width that can be used to wrap lines - see "help statmon" and the chat miniwindow
TODO: add ability to add shapes as styles - see Bigmap_Graphical plugin and WindowCircleOp
TODO: plugin to set colours on all my miniwindows, maybe a theme

windowwidth = self.windowborderwidth 
              + self.width_padding 
              + longestline 
              + self.width_padding 
              + self.windowborderwidth 
              = (self.windowborderwidth * 2 ) + (self.width_padding * 2) + longestline

windowheight = self.windowborderwidth + self.height_padding + self.titlebarheight 
               + sum(headerlineheights) + sum(self.lineheights) 
               + self.header_padding + self.height_padding + self.windowborderwidth

AddHotspot(borderwinid, self.id .. ':resize', function, ....) should work fine

event system - so that when a variable is changed, or the window is moved, or resized, functions can be attached to each event

--]]

require 'var'
require 'phelpobject'
require 'tprint'
require 'verify'
require 'serialize'
require 'copytable'
require 'commas'

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

-- subclass phelpobject
Miniwin = Phelpobject:subclass()

-- initialize the Miniwindow 
function Miniwin:initialize(args)
  --[[

  --]]
  super(self, args)
  self.parent = args.parent or nil
  self.borderwinid = self.id .. ':border'
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
  self.origwindowpos = -1
  self.notitletext = false
  self.clickshow = false
  self.firstdrawn = true
  self.drag_hotspot = "_drag_hotspot"
  self.border_width = 2
  self.actual_header_start_line = 1
  self.actual_header_end_line = 1

  self.titlebarlinenum = 1
  self.tablinenum = 2

  -- below are things that can be kept as settings
  self.header_padding = 2

  self:add_cmd('toggle', {func="cmd_toggle", help="toggle window"})
  self:add_cmd('fonts', {func="cmd_fonts", help="show fonts loaded in this miniwin"})
  self:add_cmd('shade', {func="shade", help="shade the miniwin"})
  self:add_cmd('snapshot', {func="cmd_snapshot", help="make a snapshot of the miniwin, first argument is file name, it will be saved in the Documents folder"})
  self:add_cmd('info', {func="cmd_info", help="show some info about the window"})

  self:add_setting( 'disabled', {type="bool", help="is this window disabled", default=verify_bool(false), sortlev=1, readonly=true})
  self:add_setting( 'windowpos', {type="number", help="position for this window: see http://www.gammon.com.au/scripts/function.php?name=WindowCreate", low=-1, high=13, default=6,sortlev=2, longname="Window Position", msg=[[
see http://www.gammon.com.au/scripts/function.php?name=WindowCreate
-1 = use x,y variables                    7  = on right, center top-bottom
0  = strech to output view size      8  = on right, at bottom
1  = stretch with aspect ratio         9  = center left-right at bottom
2  = strech to owner size               10 = on left, at bottom
3  = stretch with aspect ratio         11 = on left, center top-bottom
4  = top left                                    12 = centre all
5  = center left-right at top             13 = tile
6  = top right
]]})
  self:add_setting( 'x', {type="number", help="x location of this window, -1 = auto", default=-1, sortlev=2})
  self:add_setting( 'y', {type="number", help="y location of this window, -1 = auto", default=-1, sortlev=2})
  self:add_setting( 'bg_colour', {type="colour", help="background colour for this window", default=0x0D0D0D, sortlev=3, longname="Background Colour"})
  self:add_setting( 'text_colour', {type="colour", help="text colour for this window", default=0xDCDCDC, sortlev=3, longname="Text Colour"})
  self:add_setting( 'window_border_colour', {type="colour", help="border colour for window", default=0x303030, sortlev=3, longname="Window Border Colour"})
  self:add_setting( 'title_bg_colour', {type="colour", help="background colour for the titlebar", default=0x575757, sortlev=3, longname="Title Background Colour"})
  self:add_setting( 'tab_bg_colour', {type="colour", help="background colour for a tab", default=0xDCDCDC, sortlev=6, longname="Tab Background Colour"})
  self:add_setting( 'tab_text_colour', {type="colour", help="text colour for a tab", default=0x0D0D0D, sortlev=6, longname="Tab Text Colour"})
  self:add_setting( 'tab_border_colour', {type="colour", help="border colour for a tab", default=0xDCDCDC, sortlev=6, longname="Tab Border Colour"})
  self:add_setting( 'button_text_colour', {type="colour", help="text colour for the buttons in the titlebar", default=0x70CBB9, sortlev=10, longname="Button Text Colour"})
  self:add_setting( 'button_text_highlight_colour', {type="colour", help="text colour for the buttons in the titlebar", default='black', sortlev=10, longname="Button Text Highlight Colour"})
  self:add_setting( 'button_bg_highlight_colour', {type="colour", help="text colour for the buttons in the titlebar", default=0x70CBB9, sortlev=10, longname="Button Background Colour"})
  self:add_setting( 'button_border_light', {type="colour", help="border colour for cells", default=0x404040, sortlev=10, longname="Button Border Light"})
  self:add_setting( 'button_border_dark', {type="colour", help="border colour for cells", default=0x1F1F1F, sortlev=10, longname="Button Border Dark"})
  self:add_setting( 'hyperlink_colour', {type="colour", help="hyperlink colour for this window", default=0x00FFFF, sortlev=15, longname="Hyperlink Colour"})
  self:add_setting( 'header_bg_colour', {type="colour", help="header colour for this window", default=0x696969, sortlev=20, longname="Header Background Colour"})
  self:add_setting( 'header_text_colour', {type="colour", help="header text colour for this window", default=0x00FF00, sortlev=20, longname="Header Text Colour"})
  self:add_setting( 'header_height', {type="number", help="the header height", default=1, low=0, high=10, sortlev=20})
  self:add_setting( 'footer_bg_colour', {type="colour", help="footer colour for this window", default=0x696969, sortlev=25, longname="Footer Background Colour"})
  self:add_setting( 'footer_text_colour', {type="colour", help="footer text colour for this window", default=0x00FF00, sortlev=25, longname="Footer Text Colour"})
  self:add_setting( 'border_colour', {type="colour", help="border colour for cells", default="white", sortlev=30, longname="Cell Border Colour"})
  self:add_setting( 'font_size', {type="number", help="font_size for this window", low=2, high=30, default=8, sortlev=35})
  self:add_setting( 'font', {type="string", help="change the font for this window", default=self:getdefaultfont(), sortlev=35})
  self:add_setting( 'width', {type="number", help="width of this window, 0 = auto", low=0, high=100, default=0, sortlev=40})
  self:add_setting( 'height', {type="number", help="height of this window, 0 = auto", low=0, high=140, default=0, sortlev=40})
  self:add_setting( 'height_padding', {type="number", help="height padding for this window", low=0, high=30, default=2, sortlev=45})
  self:add_setting( 'width_padding', {type="number", help="width padding for this window", low=0, high=30, default=2, sortlev=45})
  self:add_setting( 'use_tabwin', {type="bool", help="toggle to use tabwin", default=verify_bool(true), sortlev=50})
  self:add_setting( 'font_warn', {type="bool", help="have been warned about font", default=verify_bool(false), sortlev=55, readonly=true})
  self:add_setting( 'shaded', {type="bool", help="window is shaded", default=verify_bool(false), sortlev=55, readonly=true})
  self:add_setting( 'shade_with_header', {type="bool", help="when window is shaded, still show header", default=verify_bool(false), sortlev=55, longname = "Shade with header"})
  self:add_setting( 'titlebar', {type="bool", help="don't show the titlebar", default=verify_bool(true), sortlev=56, longname="Show the titlebar"})

  self.default_font_id = '--NoFont--'
  self.default_font_id_bold = nil
  self.window_data = {}

  self.buttons = {}
  self.buttonstyles = {}
  self:add_button('minimize', {text=" - ", upfunction=function (win, tflags, hotspotid)
                        win:shade()
                      end, hint="Click to shade", place=1})
  self:add_button('menu', {text=" M ", upfunction=function (win, flags, hotspotid)
                        win:menuclick()
                      end, hint="Click to show menu", place=2})
  self:add_button('drag', {text=" + ", upfunction=empty, hint="Click and hold, then drag to move", cursor=10, place=98, 
                            mousedown=true, drag_hotspot=true})
  self:add_button('close', {text=" X ", upfunction=function (win, tflags, hotspotid)
                        win:show(false)
                      end, hint="Click to close", place=99})

  self.defaulttab = None
  self.activetab = None
  self.tabs = {} -- key will be tabname, data will be text
  self.tabstyles = {}

end

function Miniwin:addtab(tabname, text, place)
 if self:counttabs() == 0 then
   self.defaulttab = tabname
 end
 self.tabs[tabname] = {}
 self.tabs[tabname].text = text
 self.tabs[tabname].place = place
end

function Miniwin:removetab(tabname)
  self.tabs[tabname] = nil
end

function Miniwin:counttabs()
  local count = 0
  for i,v in pairs(self.tabs) do
    count = count + 1
  end
  return count
end

function Miniwin:changetotab(tabname)
  if self.tabs[tabname] then
    self.activetab = tabname
    self:createwin(self.tabs[tabname].text)
  end
end

function Miniwin:buildtabline()
  if self:counttabs() > 1 then
    local tabline = {}
    for i,v in tableSort(self.tabs, 'place', 50) do
      local style = {}
      style.text = ' ' .. i .. ' '
      style.tab = i
      style.mouseup = function(flags, hotspot_id)
                        self:changetotab(i)
                      end
      style.mouseover = function(flags, hotspot_id)

                        end
      --style.topborder = true
      style.leftborder = true
      style.rightborder = true
      --style.bottomborder = true
      style.bordercolour = 'tab_border_colour'
      --style.font = 'Dina'
      if i == self.activetab then
        style.textcolour = 'tab_text_colour'
        style.backcolour = 'tab_bg_colour'
        style.bordercolour = 'tab_border_colour'
        style.fillall = true
      end
      table.insert(tabline, style)
    end
    tabline.bottomborder = true
    tabline.topborder = true
    tabline.bordercolour = 'tab_border_colour'
    return tabline
  end 
  return {}
end

-- Command to toggle window
function Miniwin:cmd_toggle(cmddict)
  self:toggle()
end

-- Command to take snapshot of this window
function Miniwin:cmd_snapshot(cmddict)
  WindowWrite(self.id, cmddict[1])
end

-- Command to show info
function Miniwin:cmd_info(cmddict)
  self:plugin_header('Info')
  ColourNote(RGBColourToName(var.plugin_colour), "black", string.format("%-20s : %s" , 'Name', self.cname))
  ColourNote(RGBColourToName(var.plugin_colour), "black", string.format("%-20s : %s" , 'Id', self.id))
  ColourNote(RGBColourToName(var.plugin_colour), "black", string.format("%-20s : %s" , 'Height', tostring(WindowInfo(self.id, 4))))
  ColourNote(RGBColourToName(var.plugin_colour), "black", string.format("%-20s : %s" , 'Width', tostring(WindowInfo(self.id, 3))))
  ColourNote(RGBColourToName(var.plugin_colour), "black", string.format("%-20s : %s" , 'Calced Height', tostring(self.window_data.actualwindowheight)))
  ColourNote(RGBColourToName(var.plugin_colour), "black", string.format("%-20s : %s" , 'Calced Width', tostring(self.window_data.actualwindowwidth)))
end

-- Command to print loaded fonts for this window
function Miniwin:cmd_fonts(cmddict)
  self:plugin_header('Loaded Fonts')
  local fonts = WindowFontList(self.id)
  local tstuff = string.format('%-40s %-20s %-3s %-4s %s', 'id', 'name', 'size', 'height', 'flags')
  ColourNote(RGBColourToName(var.plugin_colour), "", tstuff)
  if fonts then
    for _, v in ipairs (fonts) do
      local name = WindowFontInfo(self.id, v, 21)
      local size = round ( (WindowFontInfo(self.id, v, 1) - WindowFontInfo(self.id, v, 4)) * 72 / GetDeviceCaps (90) )
      local bold = tonumber(WindowFontInfo(self.id, v, 8)) > 400
      local italic = tonumber(WindowFontInfo(self.id, v, 16)) > 0
      local underline = tonumber(WindowFontInfo(self.id, v, 17)) > 0
      local struck = tonumber(WindowFontInfo(self.id, v, 18)) > 0
      local height = tonumber(WindowFontInfo(self.id, v, 1))
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
      local stuff = string.format('%-40s %-20s %-3d %-4d %s', v, name, size, height, flags)
      ColourNote(RGBColourToName(var.plugin_colour), "", stuff)
    end
  end -- if any
end

-- Save all variables, this is called by phelper
function Miniwin:savestate()
  if not self.shutdownf and not self.classinit then
    tshownf = tostring(WindowInfo(self.id, 5))
    SetVariable ("shown"..self.cname, tshownf)
  end
  super(self)
end

-- check if a font is installed
function Miniwin:isfontinstalled(fontid, font_name, win)
  twin = win or self.id
  --print('win : ', twin)
  if string.lower(WindowFontInfo (twin, fontid, 21)) == string.lower(font_name) then
    return true
  end
  return false

end

-- check to see if a fontid exists in the miniwindow
function Miniwin:checkfontid(font)
  font = string.lower(font)
  local fontv = self.fonts[font]
  if fontv == nil then
    return false
  end
  return true
end

-- build a fontid
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

-- set the default font
function Miniwin:setdefaultfont(fontid)
  self.default_font_id = fontid
  self.default_font_id_bold =  self:addfont(self.fonts[self.default_font_id].font_name,
               self.fonts[self.default_font_id].size,
               true, false, false, false, false)
  SaveState()
end

-- add a font to the miniwindow, it also loads the font in a temp window to make sure
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
  bold = verify_bool(bold)
  italic = verify_bool(italic)
  underline = verify_bool(underline)
  strikeout = verify_bool(strikeout)
  font = string.lower(font)
  size = size or self.font_size
  local fontid = self:buildfontid(font, size, bold, italic, underline, strikeout)
  if self:checkfontid(fontid) then
    return fontid
  end

  fontt.fontid = fontid
  fontt.size = size

  twinid = self.id .. '_fonttest'

  check (WindowCreate (twinid,
                 0, 0, 1, 1,
                 6,   -- top right
                 0,
                 self.bg_colour) )

  check (WindowFont (twinid, fontid, font, size, bold, italic, underline, strikeout, 0, 49))

  if not self:isfontinstalled(fontid, font, twinid) then
    return -1
  end

  if not WindowInfo(self.id, 21) then
    check (WindowCreate (self.id,
                 0, 0, 1, 1,
                 6,   -- top right
                 0,
                 self.bg_colour) )
  end

  check (WindowFont (self.id, fontid, font, size, bold, italic, underline, strikeout, 0, 49))
  
  fontt.height = WindowFontInfo (self.id, fontid, 1) -- height
  fontt.width = WindowFontInfo (self.id, fontid, 6)  -- avg width
  fontt.font_name = WindowFontInfo (self.id, fontid, 21)  -- name
  fontt.bold = bold
  fontt.italic = italic
  fontt.underline = underline
  fontt.strikeout = strikeout

  check (WindowDelete (twinid))

  self.fonts[fontid] = fontt
  return fontid

end

-- get the default font if no font is loaded in a miniwindow
function Miniwin:getdefaultfont()
  local tempid = self.id .. '_default_font_win'
  check (WindowCreate (tempid,
                 0, 0, 1, 1,
                 6,   -- top right
                 0,
                 verify_colour('black')) )

  check (WindowFont (tempid, "--NoFont--", "--NoFont--", 8, false, false, false, false, 0, 49))  -- normal

  rstring = string.lower(WindowFontInfo (tempid, "--NoFont--", 21))

  WindowDelete(tempid)

  return rstring

end

-- add a button to the button bar, see notes at the top of this file
function Miniwin:add_button(button, buttoninfo)
  self.buttons[button] = buttoninfo
end

function Miniwin:buttonmouseover(name)
   --print('--------- buttonmouseover -------------')
   --print(name)
   --tprint(self.buttonstyles[name])

   self.buttonstyles[name].textcolour = 'button_text_highlight_colour'
   self.buttonstyles[name].backcolour = 'button_bg_highlight_colour'
   self:displayline(self.window_data[1])
   Repaint()
   --0x6DEFC8
   --v = self.buttonstyles[name]
   --WindowRectOp (self.id, 2, v.tstart, v.ttop, v.tstart + v.textlength, v.ttop + WindowFontInfo(self.id, v.font_id, 1), verify_colour(0x6DEFC8))
   --Repaint()
end

function Miniwin:buttoncancelmouseover(name)
   --print('--------- buttoncancelmouseover -------------')
   --print(name)
   --tprint(self.buttonstyles[name])
   self.buttonstyles[name].textcolour = 'button_text_colour'
   self.buttonstyles[name].backcolour = nil
   self:displayline(self.window_data[1])
   Repaint()

   --v = self.buttonstyles[name]
   --WindowRectOp (self.id, 2, v.tstart, v.ttop, v.tstart + v.textlength, v.ttop + WindowFontInfo(self.id, v.font_id, 1), 
   --                           self:get_colour('title_bg_colour'))
   --Repaint()
end

-- build the titlebar with buttons and text
function Miniwin:buildtitlebar()
  local tstyle = {}
  local addedtitle = false

  local j = 0
  for name,button in tableSort(self.buttons, 'place', 50) do
    j = j + 1
    if j ~= 1 then
     local tstyle2 = {}
     tstyle2.text = " "
     tstyle2.font_size = 4
     table.insert(tstyle, tstyle2)
    end
    local style = {}
    style.text = button.text
    style.textcolour = "button_text_colour"
    style.cellborder = true
    style.bold = false
    style.bordercolour = 'button_border_light'
    style.bordercolour2 = 'button_border_dark'
    style.borderstyle = 4
    if button.mousedown then
      style.mousedown = button.upfunction
    else
      style.mouseup = button.upfunction
    end

    style.mouseover = function (win, hotspotid, flags)
        win:buttonmouseover(name)
    end
    style.cancelmouseover = function (win, hotspotid, flags)
        win:buttoncancelmouseover(name)
    end

    style.hint = button.hint
    if button.cursor then
      style.cursor = button.cursor
    end
    if button.hotspot_id then
      style.hotspot_id = button.hotspot_id
    end

    if button.drag_hotspot then
      style.hotspot_id = self.drag_hotspot
      style.mousedown = empty
    end

    style.button = name
    if button.place > 50 then
      if (not addedtitle) and (not self.notitletext) then
        addedtitle = true
        local hstyle = {}
        hstyle.text = self.titlebartext or self.cname 
        hstyle.bold = true
        hstyle.textcolour = "button_text_colour"
        hstyle.hjust = 'center'
        table.insert(tstyle, hstyle)
      end
      style.hjust = 'right'
    end
    table.insert(tstyle, style)
   
  end

  --tstyle.bordercolour = 'black'
  tstyle.backcolour = 'title_bg_colour'
  --tstyle.cellborder = true
  --tstyle.backcolour = 'black'
  return tstyle
end

-- sets the font from the mouse menu
function Miniwin:menusetfont()
        if self.font_warn == false then --display msg about fixed width fonts
                local msg = "This miniwindow may not display properly without a fixed width font.".. --font msg text
                                "\n\nUse menu option \"Reset Defaults\" or command '" .. phelper.cmd .. ' ' .. self.cname .. " reset' to reset font\n"..
                                "if the window becomes unreadable.\n"..
                                "\nYes to proceed.\nNo to to proceed and stop displaying this message.\nCancel to cancel."
                local s = utils.umsgbox ( msg, "Font selection", "yesnocancel", "!", 1 ) --font msg box
                if s == "cancel" then --process msg box response
                        return
                elseif s == "no" then
                        self:set('font_warn', true)
                end
        end
        tfont = self.fonts[self.default_font_id]
        wanted_font = utils.fontpicker (tfont.font_name, tfont.size) --font dialog
        if wanted_font then
                --tprint(wanted_font)
                fid = self:addfont(wanted_font.name, wanted_font.size, wanted_font.bold, wanted_font.italic,
                                   wanted_font.underline, wanted_font.strikeout)
                self:setdefaultfont(fid)
                self.font = self.fonts[self.default_font_id].font_name
                self.font_size = self.fonts[self.default_font_id].size
                self:savestate()
                self:redraw()
        end
end

-- build the mousemenu, looks for anything in the settings table with a longname
function Miniwin:buildmousemenu()
  menu = " >Font | Set font - Currently: " .. tostring(self.font) .. ', ' .. tostring(self.font_size) .. " | Increase font size | Decrease font size | Default Font | < | >Colours "
  --local colours = {}
  for name,setting in tableSort(self.set_options, 'sortlev', 50) do
    if setting.longname ~= nil and setting.type == 'colour' then
      --table.append(colours, name, true)
      menu = menu .. ' | ' .. setting.longname .. ' - Currently: ' .. tostring( RGBColourToName(self[name]))
    end
  end
  --for name,value in table.sort(colours, 
  menu = menu .. ' | < | >Toggle '
  for name,setting in tableSort(self.set_options, 'sortlev', 50) do
    if setting.longname ~= nil and setting.type == 'bool' then
      menu = menu .. ' | ' .. setting.longname .. ' - Currently: ' .. tostring(self[name])
    end
  end
  menu = menu .. ' | < | >Other '
  for name,setting in tableSort(self.set_options, 'sortlev', 50) do
    if setting.longname ~= nil and setting.type ~= 'bool' and setting.type ~= 'colour' then
      menu = menu .. ' | ' .. setting.longname .. ' - Currently: ' .. tostring(self[name])
    end
  end
  menu = menu .. ' | < || Restore Defaults || Help'
  return menu
end

-- the function called when the mouse is clicked in the menu button
function Miniwin:menuclick ()
  --make text for menu options
  local menu = self:buildmousemenu()
  local result = WindowMenu (self.id, WindowInfo (self.id, 14), WindowInfo (self.id, 15), menu) --do menu
  if result:match(' - ') then
    tresult = utils.split(result, '-')
    result = trim(tresult[1])
  end
  if result ~= "" then --if we get a menu item clicked
          if result:match("Set font") then
            self:menusetfont()
          elseif result == "Increase font size" then
            self:set('font_size', self.font_size + 1)
          elseif result == "Decrease font size" then
            self:set('font_size', self.font_size - 1)
          elseif result == "Default Font" then
            self:set('font_size', 'default')
            self:set('font', 'default')
          elseif result:match("Restore Defaults") then
            self:cmd_reset()   
          elseif result == "Help" then
            self.phelper.helpwin:show(true)
          else
            for name,setting in tableSort(self.set_options, 'type', 'unknown') do
              if result == setting.longname then
                --print("changing settings " .. setting.longname)
                if setting.type == 'bool' then
                  self:set(name, not self[name])
                else
                  self:set(name, nil)
                end
              end
            end
          end
  end -- if result
end -- ListMenu

-- redraw the window
function Miniwin:redraw()
   local shown = WindowInfo(self.id, 5)
   self:buildwindow()
   self:drawwin()
   WindowShow(self.id, shown)
end

-- create the window
function Miniwin:createwin (text)
  if text == nil then
    if self:counttabs() > 0 then
      text = self.tabs[self.defaulttab].text
      self.activetab = self.defaulttab
    else
      return
    end
  elseif text and not next(text) then
    if self:counttabs() > 0 then
      text = self.tabs[self.defaulttab].text
      self.activetab = self.defaulttab
    else
      return
    end
  end
  self.text = text
  self:buildwindow()
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

-- show or hide the window
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

-- init the window after the plugin has been initialized
function Miniwin:init()
  super(self)

  self:setdefaultfont(self:addfont(self.font, self.font_size, false, false, false, false, true))
end

-- enable the window
function Miniwin:enable()
  super(self)
  self:tabbroadcast(true)
end

-- disable the window
function Miniwin:disable()
  self.firstdrawn = true
  self:show(false)
  self:tabbroadcast(false)
  super(self)
end

-- toggle the window to be shown/not shown
function Miniwin:toggle()
  if not self.disabled then
    self:show(not WindowInfo(self.id, 5))
  end
  self:savestate()
end

-- shade the window
function Miniwin:shade()
  if not self.disabled then
    self:set('shaded', not self.shaded)
  end
  self:savestate()
end

-- add a hotspot to the window
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

-- mousedown function, checks to see if the id exists in the hyperlink_functions['mousedown'] table
function Miniwin:mousedown (flags, hotspotid)
  --print('mousedown', 'hotspotid', hotspotid)
  -- find where mouse is so we can adjust window relative to mouse
  self.startx, self.starty = WindowInfo (self.id, 14), WindowInfo (self.id, 15)

  -- find where window is in case we drag it offscreen
  self.origx, self.origy = WindowInfo (self.id, 10), WindowInfo (self.id, 11)
  self.origwindowpos = self.windowpos

  local f = self.hyperlink_functions['mousedown'][hotspotid]
  if f then
    f(self, flags, hotspotid)
    return true
  end -- function found

  return false
end -- mousedown

-- cancelmousedown function, checks to see if the id exists in the hyperlink_functions['cancelmousedown'] table
function Miniwin:cancelmousedown (flags, hotspotid)

  local f = self.hyperlink_functions['cancelmousedown'][hotspotid]
  if f then
    f(self, flags, hotspotid)
    return true
  end -- function found

  return false
end -- mousedown

-- mouseover function, checks to see if the id exists in the hyperlink_functions['mouseover'] table
function Miniwin:mouseover (flags, hotspotid)

  local f = self.hyperlink_functions['mouseover'][hotspotid]
  if f then
    f(self, flags, hotspotid)
    return true
  end -- function found

  return false
end -- mousedown

-- cancelmouseover function, checks to see if the id exists in the hyperlink_functions['cancelmouseover'] table
function Miniwin:cancelmouseover (flags, hotspotid)

  local f = self.hyperlink_functions['cancelmouseover'][hotspotid]
  if f then
    f(self, flags, hotspotid)
    return true
  end -- function found

  return false
end -- mousedown

-- mouseup function, checks to see if the id exists in the hyperlink_functions['mouseup'] table
function Miniwin:mouseup (flags, hotspotid)

  local f = self.hyperlink_functions['mouseup'][hotspotid]
  if f then
    f(self, flags, hotspotid)
    return true
  end -- function found

  return false
end -- mousedown

-- horizontal and vertical justify styles in a line after we have found out height and width of window
-- and all styles in the line
function Miniwin:justify_styles(line, linenum)

  for i,v in ipairs (line.text) do
    local stylelen = 0
    local tstart = v.start
    local ttop = line.texttop

    if v.vjust ~= nil then
      if v.vjust == 'center' then
        local theight = line.height
        local fheight = WindowFontInfo(self.id, v.font_id, 1)
        ttop = ttop + (theight - fheight) / 2
      elseif v.vjust == 'bottom' then
        local theight = line.height
        local fheight = WindowFontInfo(self.id, v.font_id, 1)
        ttop = ttop + theight - fheight
      end
    end
    if v.hjust ~= nil then
      if v.hjust == 'center' then
        local centerofline = ((self.window_data.lineend - self.window_data.linestart) / 2) + self.window_data.linestart
        tstart = centerofline - (v.stylelen / 2) 
      elseif v.hjust == 'right' then
        
        local twidth = line.width
        local wwidth = self.window_data.actualwindowwidth - self.border_width - self.width_padding
        if self.titlebar and linenum == self.titlebarlinenum then
          wwidth = self.window_data.actualwindowwidth - self.border_width - 2
        end
        local restt = twidth - tstart
        local restw = wwidth - tstart
        tstart = tstart + restw - restt
      end
    end
    v.textstart = tstart
    v.texttop = ttop + 1
    if v.textcolour ~= nil then
        v.stylelen = WindowTextWidth (self.id, v.font_id, strip_colours(v.text),
                      v.textstart, v.texttop, 0, 0, self:get_colour(v.textcolour))
    else
        v.stylelen = self:colourtext(v.font_id, v.text, v.textstart, v.texttop, 0, 0, nil, true)
    end


    if tstart + v.stylelen >= self.window_data.textend then
      if self.titlebar and linenum == self.titlebarlinenum then
        v.textend = self.window_data.actualwindowwidth - self.border_width - 2
      else
        v.textend = self.window_data.textend
      end
    else
      v.textend = v.textstart + v.stylelen
    end

    if v.button then
      self.buttonstyles[v.button] = v
    end
    if v.tab then
      self.tabstyles[v.tab] = v
    end
  end -- for each style run
  return line
end

function Miniwin:is_header_line(linenum)
  if self.actual_header_start_line ~= nul and self.actual_header_end_line ~= nil then
    return self.header_height > 0 and linenum >= self.actual_header_start_line  and linenum <= self.actual_header_end_line
  else
    return false
  end
end

-- convert a line, go through and figure out colours, fonts, start positions, end positions, and borders for every line
-- toppadding = extra spacing between top of line and top of text cell
-- bottompadding = extra spacing between bottom of line and bottom of text cell
-- textpadding = extra spacing between cell wall and text
function Miniwin:convert_line(linenum, line, top, toppadding, bottompadding, textpadding)
  local bottompadding = bottompadding or 0
  local toppadding = toppadding or 0
  local textpadding = textpadding or 0
  local linet = {}
  local def_font_id = self.default_font_id
  local def_colour = self:get_colour('text_colour')
  local maxfontheight = 0
  --local start = linepadding
  local start = self.border_width + self.width_padding
  if self:counttabs() > 0 and linenum == self.tablinenum then
    start = self.border_width
  end
  if self.titlebar and linenum == self.titlebarlinenum then
    start = self.border_width + 2
  end
  if self:is_header_line(linenum) then
      def_font_id = self.default_font_id_bold
      def_colour = self:get_colour("header_text_colour")
  end
  linet.text = {}
  if type(line) == 'table' then
    for i,style in ipairs(line) do
      table.insert(linet.text, i, copytable.deep(style))
      font_id = self:addfont(style.font_name or self.fonts[def_font_id].font_name,
                      style.font_size or self.fonts[def_font_id].size,
                      style.bold or self.fonts[def_font_id].bold,
                      style.italic or self.fonts[def_font_id].italic,
                      style.underline or self.fonts[def_font_id].underline,
                      style.strikeout or self.fonts[def_font_id].strikeout)
      maxfontheight = math.max(maxfontheight, self.fonts[font_id].height)
      if style.image and style.image.name then
         print('Convert_Line: Got Image')
      elseif style.circleOp and style.circleOp.width then
         print('Convert_Line: Got CircleOp')
      else
        local tlength = WindowTextWidth (self.id, font_id, strip_colours(style.text))
        if style.start and style.start > start then
          linet.text[i].start = style.start
          start = style.start + tlength
        else
          linet.text[i].start = start
          start = start + tlength
        end
        linet.text[i].stylelen = tlength
        linet.text[i].font_id = font_id
        linet.text[i].bordercolour = style.bordercolour or self.border_colour
        linet.text[i].textcolour = style.textcolour or def_colour
      end
    end

    linet.leftborder = line.leftborder or false
    linet.rightborder = line.rightborder or false
    linet.bottomborder = line.bottomborder or false
    linet.topborder = line.topborder or false
    linet.borderstyle = line.borderstyle or 0
    linet.borderwidth = line.borderwidth or 1
    linet.bordercolour = line.bordercolour or self.border_colour
    linet.backcolour = line.backcolour or nil
  else
      table.insert(linet.text, 1, {})
      linet.text[1].font_id = self.default_font_id
      linet.text[1].text = line
      linet.text[1].start = start
      linet.text[1].stylelen = tlength
      maxfontheight = math.max(maxfontheight, self.fonts[self.default_font_id].height)
      local tlength = WindowTextWidth (self.id, self.default_font_id, linet.text[1].text)
      start = start + tlength
  end
  linet.lineborder = line.lineborder
  linet.width = start
  linet.height = maxfontheight
  linet.linetop = top
  linet.celltop = linet.linetop + toppadding
  linet.texttop = linet.celltop + textpadding
  linet.textbottom = linet.texttop + linet.height + 1
  linet.cellbottom = linet.textbottom + textpadding
  linet.linebottom = linet.cellbottom + bottompadding

  return linet
end

function Miniwin:buildwindow()
  local height = 0
  local tempdata = {}
  self.window_data = {}

  local header = {}
  local text = {}

  local linenum = 0

  self.window_data.maxlinewidth = 0

  if self.titlebar then
    linenum = linenum + 1
    titlebar = self:buildtitlebar()
    self.titlebarlinenum = linenum
    tempdata[linenum] = self:convert_line(linenum, titlebar, self.border_width, 2, 2, 1)
    height = tempdata[linenum].linebottom
  end

  if self:counttabs() > 1 then
    linenum = linenum + 1
    tabline = self:buildtabline()
    self.tablinenum = linenum
    tempdata[linenum] = self:convert_line(linenum, tabline, height, 1, 0)
    height = tempdata[linenum].linebottom
    self.window_data.maxlinewidth = math.max(self.window_data.maxlinewidth, tempdata[linenum].width)
  end

  if type(self.text) == 'table' then
    -- breakout header_stuff
    for i=1,self.header_height do
      table.insert(header, self.text[i])
    end

    -- breakout text stuff
    for i=1+self.header_height, #self.text do
      table.insert(text, self.text[i])
    end


    -- do header stuff
    for line, v in ipairs(header) do
      linenum = linenum + 1
      if line == 1 then
        height = height - 1
        self.actual_header_start_line = linenum
        self.actual_header_end_line = linenum + #header - 1
      end

      if line == 1 and #header == 1 then
        tline = self:convert_line(linenum, v, height, 3, 0)
      elseif line == 1 and #header > 1 then
        tline = self:convert_line(linenum, v, height, 3, 0)
      elseif line == #header then
        tline = self:convert_line(linenum, v, height, 0, 0)
      end
      --tline.backcolour = 'header_bg_colour'

      tempdata[linenum] = tline
      height = tempdata[linenum].linebottom
      self.window_data.maxlinewidth = math.max(self.window_data.maxlinewidth, tempdata[linenum].width)
    end

    height = height + self.height_padding

    -- do text stuff
    for line,v in ipairs(text) do
      linenum = linenum + 1

      tline = self:convert_line(linenum, v, height, 0, 0, 0)
    
      tempdata[linenum] = tline
      height = tempdata[linenum].linebottom
      self.window_data.maxlinewidth = math.max(self.window_data.maxlinewidth, tempdata[linenum].width)
    end

    if self.width > 0 then
      self.window_data.actualwindowwidth = self.width
    else
      self.window_data.actualwindowwidth = self.window_data.maxlinewidth + self.width_padding + self.border_width
    end

    if self.height > 0 then
      self.window_data.actualwindowheight = self.height
    else
       self.window_data.actualwindowheight = height + self.height_padding + self.border_width
    end
    self.window_data.linestart = self.border_width
    self.window_data.lineend = self.window_data.actualwindowwidth - self.border_width 
    self.window_data.textstart = self.border_width + self.width_padding
    self.window_data.textend = self.window_data.actualwindowwidth - self.border_width - self.width_padding

    for line, v in ipairs(tempdata) do  
        self.window_data[line] = self:justify_styles(v, line)
    end

  end
end

-- build a hotspot, called from displayline
function Miniwin:buildhotspot(style, left, top, right, bottom)
  self:addhotspot(style.hotspot_id, left, top, right, bottom, style.mouseover, style.cancelmouseover, style.mousedown,
                   style.cancelmousedown, style.mouseup, style.hint, style.cursor)

end

-- displays text with colour codes imbedded
--
-- font_id : font to use
-- Text : what to display
-- Left, Top, Right, Bottom : where to display it
-- Capitalize : if true, turn the first letter into upper-case
-- lengthonly : if true, return the length of the style only

function Miniwin:colourtext (font_id, Text, Left, Top, Right, Bottom, Capitalize, lengthonly)
  wfunction = WindowText
  if lengthonly then
    wfunction = WindowTextWidth
  end

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
        x = x + wfunction (self.id, font_id, text, x, Top, Right, Bottom,
                            colour_conversion [colour] or self.text_colour)
      end -- some text to display

    end -- for each colour run

    return x
  end -- if

  if Capitalize then
    Text = Text:gsub ("%a", string.upper, 1)
  end -- if leading caps wanted

  return wfunction (self.id, font_id, Text, Left, Top, Right, Bottom,
                    self.text_colour)

end -- colourtext

-- display a single line that has been converted and adjusted
function Miniwin:displayline (styles)
  self:mdebug('Displaying', styles)
  local def_font_id = self.default_font_id
  local def_colour = self:get_colour("text_colour")
  local def_bg_colour = self:get_colour("bg_colour")

  if not self.shaded and styles.linebottom > (WindowInfo(self.id, 4) - self.border_width - self.height_padding) then
    styles.bottom = WindowInfo(self.id, 4) - self.border_width - self.height_padding
  end

  if styles.backcolour then
    WindowRectOp (self.id, 2, self.window_data.linestart, styles.linetop, self.window_data.lineend, styles.linebottom, self:get_colour(styles.backcolour) )
  end
  for i,v in ipairs (styles.text) do

    if v.backcolour and not (v.backcolour == 'bg_colour') then
      -- draw background rectangle
      local bcolour = self:get_colour(v.backcolour, def_bg_colour)
      if v.fillall then
        WindowRectOp (self.id, 2, v.textstart, styles.linetop, v.textstart + v.stylelen, styles.linebottom, bcolour)
      else
        WindowRectOp (self.id, 2, v.textstart, styles.celltop, v.textstart + v.stylelen, styles.cellbottom, bcolour)
      end
    end
    if v.image and v.image.name then
      print('displayline: Got Image')
    elseif v.circleOp and v.circleOp.height then
      print('displayline: Got CircleOp')
    else
      if v.textcolour ~= nil then
        local tcolour = self:get_colour(v.textcolour)
        stylelen = WindowText (self.id, v.font_id, strip_colours(v.text),
                    v.textstart, v.texttop, 0, 0, tcolour)
      else
        stylelen = self:colourtext(v.font_id, v.text, v.textstart, v.texttop, 0, 0)
      end
    end
    tborderwidth = v.borderwidth or 1
    tborderstyle = v.borderstyle or 0
    if v.cellborder then
       if tborderstyle == 0 then
         tborderstyle = 1
       end
         WindowRectOp (self.id, tborderstyle, v.textstart, styles.celltop, v.textend, styles.cellbottom, 
                          self:get_colour(v.bordercolour), self:get_colour(v.bordercolour2))
    else

      if v.topborder then
          WindowLine (self.id, v.textstart, styles.celltop, v.textend, styles.celltop, self:get_colour (v.bordercolour), tborderstyle, tborderwidth)
      end
      if v.bottomborder then
          WindowLine (self.id, v.textstart, styles.cellbottom, v.textend, styles.cellbottom, self:get_colour (v.bordercolour), tborderstyle, tborderwidth)
      end
      if v.leftborder then
          WindowLine (self.id, v.textstart, styles.celltop, v.textstart, styles.cellbottom, self:get_colour (v.bordercolour), tborderstyle, tborderwidth)
      end
      if v.rightborder then
          WindowLine (self.id, v.textend - 1, styles.celltop, v.textend - 1, styles.cellbottom, self:get_colour (v.bordercolour), tborderstyle, tborderwidth)
      end
    end
    if v.mousedown ~= nil or
       v.cancelmousedown ~= nil or
       v.mouseup ~= nil or
       v.mouseover ~= nil or
       v.cancelmouseover ~= nil then
      self:buildhotspot(v, v.textstart, styles.celltop, v.textend, styles.cellbottom)
    end
    if v.hotspot_id == self.drag_hotspot then
      WindowDragHandler(self.id, self.id .. ':' .. self.drag_hotspot, "dragmove", "dragrelease", 0)
    end
  end -- for each style run

  tbordercolour = styles.bordercolour
  tborderwidth = styles.borderwidth or 1
  tborderstyle = styles.borderstyle or 0
   if styles.lineborder then
       if tborderstyle == 0 then
         tborderstyle = 1
       end
         WindowRectOp (self.id, tborderstyle, self.border_width, styles.linetop, self.window_data.actualwindowwidth - self.border_width, styles.linebottom, 
                self:get_colour(styles.bordercolour), self:get_colour(styles.bordercolour2))
   else

    if styles.topborder then
        WindowLine (self.id, self.window_data.linestart, styles.linetop, self.window_data.lineend, styles.linetop, 
                                             self:get_colour (tbordercolour), tborderstyle, tborderwidth)
    end
    if styles.bottomborder then
        WindowLine (self.id, self.window_data.linestart, styles.linebottom, self.window_data.lineend, styles.linebottom, 
                                             self:get_colour (tbordercolour), tborderstyle, tborderwidth)
    end
    if styles.leftborder then
        WindowLine (self.id, self.window_data.linestart, styles.linetop, self.window_data.linestart, styles.linebottom, self:get_colour (tbordercolour), tborderstyle, tborderwidth)
    end
    if styles.rightborder then
        WindowLine (self.id, self.window_data.lineend - 1, styles.linetop, self.window_data.lineend - 1, styles.linebottom, self:get_colour (tbordercolour), tborderstyle, tborderwidth)
    end
  end

--  return start, top, left, bottom

end -- displayline

-- create the window and do things before text is drawn
function Miniwin:pre_create_window_internal(height, width, x, y)
  local height = height or self.window_data.actualwindowheight 
  local width = width or self.window_data.actualwindowwidth

  -- recreate the window the correct size
  local tx = x or self.x
  local ty = y or self.y 
  if tx >= 0 and ty >= 0 then
    check (WindowCreate (self.id,
                 tx, ty,   -- left, top (auto-positions)
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

  if not self.shaded or self.shade_with_header then
    local htop = 0
    local hbottom = 0
    if self.header_height > 0 then
        htop = self.window_data[self.actual_header_start_line].linetop + 1
        hbottom = self.window_data[self.actual_header_end_line + 1].linetop - 1

      -- header colour
      check (WindowRectOp (self.id, 2, 3, htop + 1, -3, hbottom, self:get_colour("header_bg_colour"))) -- self:get_colour("header_bg_colour")))
      --check (WindowRectOp (self.id, 1, 2, htop + 1, -2, hbottom, self:get_colour("black"))) -- self:get_colour("header_bg_colour")))
    end
  end

  --check (WindowRectOp (self.id, 2, 0, 0, 0, 0, 0x575757))

  WindowDeleteAllHotspots (self.id)

end

-- do stuff after the text has been drawn
function Miniwin:post_create_window_internal()

  if not self.titlebar then
    self:addhotspot('mousemenu', self.border_width, self.border_width, self.border_width + 5, self.border_width + 5, 
                   nil, nil, function (win, flags, hotspotid)
                        win:menuclick()
                      end,
                   nil, nil, 'Show Menu')
  end
    
  -- DrawEdge rectangle
  check (WindowRectOp (self.id, 1, 0, 0, 0, 0, self:get_colour('window_border_colour')))
  check (WindowRectOp (self.id, 1, 1, 1, -1, -1, self:get_colour('window_border_colour')))
end

-- draw the window
function Miniwin:drawwin()
  --print("Got past text check")
  if not next(self.text) then
    return
  end

  if self.shaded and self.titlebar then
    local tx = WindowInfo(self.id, 10)
    local ty = WindowInfo(self.id, 11)

    if self.x or self.y then
      local tx = x or self.x
      local ty = y or self.y 
    end
    -- look at shaded stuff
    local sheight = self.window_data[1].linebottom + self.border_width
    if self.shade_with_header and self.header_height > 0 then 
      local hbottom = self.window_data[self.actual_header_end_line].linebottom + self.border_width + 2
      sheight = hbottom
    end
    self:pre_create_window_internal(sheight, nil, tx, ty)
    self:displayline(self.window_data[1])
    if self.shade_with_header then
      for i=1,self.actual_header_end_line do
        self:displayline(self.window_data[i + 1])
      end
    end
  else
    self:pre_create_window_internal()
    for i, v in ipairs (self.window_data) do
      self:displayline (self.window_data[i])
    end -- for
  end

  self:post_create_window_internal()

end

-- set values, redraws the miniwindow if a setting is changed
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
        self:redraw()
      end
    end
    retcode2 = super(self, option, tvalue, args)
    if retcode2 then
      if option == "windowpos" and not self.classinit then
        self.x = -1
        self.y = -1
      end
      if not self.classinit then
        self:redraw()
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

-- the function to drag and move the window
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

  self.windowpos = -1

end -- dragmove

-- the function after the window has been dragged, will set the position
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

-- broadcast to the tabwin
function Miniwin:tabbroadcast(flag, text)
  local ttext = ""
  if text then
    if not next(text) then
      ttext = " " .. text .. " "
    else
      ttext = text
    end
  elseif self.lasttabtext then
    ttext = self.lasttabtext
  elseif self.cname then
    ttext = " " .. self.cname .. " "
  end
  
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

-- empty function for hyperlinks
function empty(flags, hotspot_id)

end

-- create a popup style with another miniwindow
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
