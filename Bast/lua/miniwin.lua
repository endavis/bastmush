-- miniwin.lua
-- $Id: miniwin.lua 1835 2012-06-22 14:42:58Z endavis $
-- class for creating miniwindows

-- Author: Eric Davis - 28th September 2008

--[[
multiple functions in a hotspot
or functions that are always called in a hotspot
such as the scroll in the text rectangle

The miniwindows are populated with mushclient styles, you create a table of styles

Example:
quickest way to create a window
 mwin =  Miniwin:new{name="NewWin"}

 lstyle = {} -- the entire line

 style = {}
 style.text = "Right Horizontally (Italic)"
 style.italic = true
 style.hjust = 'right'
 style.hint = serialize.save_simple(style)
 style.mouseover = nofunc

 table.insert(lstyle, {style})
 mwin:addtab('default', lstyle, {{text="Window Header"}} )
 mwin:show(true)


The global line can have the following
  lstyle.backcolour
  lstyle.gradient (true for gradient)
  lstyle.colour1
  lstyle.colour2
  lstyle.bordercolour
  lstyle.borderwidth
  lstyle.borderstyle
  lstyle.lineborder
  lstyle.bordercolour
  lstyle.bordercolour2
  lstyle.topborder
  lstyle.bottomborder
  lstyle.leftborder then
  lstyle.rightborder then

styles can have the following
These are the main ones
  style.text = 'text' -- the only one actually required
  style.textcolour
  style.backcolour
  style.nocolourconvert -- don't convert inline ascii codes (@x123 or @b)

Added for miniwin
  style.start - absolute position to start
  style.hjust - can be set to center to put text in the center of the window on that line (default is left)
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

-- The following are for mouse events and are either function names of the class or actual functions in the plugin
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

  -- images and circleOp are not coded yet
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
  self:add_button('minimize', {text=" - ", mousedown|mouseup=function (win, tflags, hotspotid)
                        win:shade()
                      end, hint="Click to shade", place=1})

  text = text for the button
  mousedown|mouseup = function when mousedown|mouseup on this button
  hint = the hint for the button
  place = place of the button in the titlebar, anything <= 50 is on the left side of the bar, anything > 50 is on the right side


TODO: add footer, this could be used for resizing, tabs, status bar type things
TODO: add a specific line width that can be used to wrap lines - see "help statmon" and the chat miniwindow
TODO: add ability to add shapes as styles - see Bigmap_Graphical plugin and WindowCircleOp
TODO: addline function that adds a single line to the text addline(line, tab) tab is optional, then I could just convert_line and adjust_line
TODO: have adjust_line be the one that breaks up the lines

windowwidth = self.windowborderwidth
              + self.width_padding
              + longestline
              + self.width_padding
              + self.windowborderwidth
              = (self.windowborderwidth * 2 ) + (self.width_padding * 2) + longestline

windowheight = self.windowborderwidth + self.height_padding + self.titlebarheight
               + sum(headerlineheights) + sum(self.lineheights)
               + self.header_padding + self.height_padding + self.windowborderwidth

AddHotspot(borderwinid, self.winid .. ':resize', function, ....) should work fine

event system - so that when a variable is changed, or the window is moved, or resized, functions can be attached to each event
 the events I have so far -
   visibility - called whenever this window changes visibility
     args = {flag=showflag}
   shade - called whenever this windows shaded value changes
     args = {flag=shadedflag}

events I would like to add - move, resize
--]]

require 'var'
require 'phelpobject'
require 'tprint'
require 'verify'
require 'serialize'
require 'copytable'
require 'commas'
require 'wait'
require 'colours'

url_re = rex.new("(?:https?://|mailto:)\\S*[\\w/=@#\\-\\?]")

-- subclass phelpobject
Miniwin = Phelpobject:subclass()

function parseURLs(text)
  local URLs = {}
  local start, position = 0, 0

  url_re:gmatch(text,
    function (link, _)
        start, position = string.find(text, link, position, true)
        table.insert(URLs, {start=start, stop=position, text=link})
    end
  )

  if next(URLs) then
    local tparse = {}
    local textlen = #text
    local last = 1
    for i,v in ipairs(URLs) do
      if v.start ~= last then
        table.insert(tparse, {text=string.sub(text, last, v.start - 1)})
      end
      table.insert(tparse, {text=string.sub(text, v.start, v.stop), url=true})
      last = v.stop
    end
    if last ~= textlen then
      table.insert(tparse, {text=string.sub(text, last + 1, textlten)})
    end
    return tparse
  else
    return {{text=text}}
  end


end -- function findURL

-- initialize the Miniwindow
function Miniwin:initialize(args)
  --[[

  --]]
  super(self, args)
  self.otype = "Miniwin"
  self.parent = args.parent or nil
  self.winid = self.id
  self.text = {}
  self.children = {}
  self.hyperlink_functions = {}
  self.hyperlink_functions['mousedown'] = {}
  self.hyperlink_functions['cancelmousedown'] = {}
  self.hyperlink_functions['mouseup'] = {}
  self.hyperlink_functions['mouseover'] = {}
  self.hyperlink_functions['cancelmouseover'] = {}
  self.hyperlink_functions['releasecallback'] = {}
  self.hyperlink_functions['movecallback'] = {}
  self.hyperlink_functions['wheelcallback'] = {}
  self.textareahotspots = {}
  self.fonts = {}
  self.startx = 0
  self.starty = 0
  self.origx = 0
  self.origy = 0
  self.origwindowpos = -1
  self.notitletext = false
  self.clickshow = false
  self.firstdrawn = true
  self.actual_header_start_line = nil
  self.actual_header_end_line = nil
  self.actual_text_start_line = nil
  self.actual_text_end_line = nil
  self.drawscrollbar = false
  self.scrollbarwidth = 15
  self.keepscrolling = false
  self.clickdelta = -1
  self.dragscrolling = false
  self.menuname = 'unknown'
  self.resizable = args.resizable or false
  self.newheight = -1
  self.newwidth = -1
  self.newx = -1
  self.newy = -1
  self.resizewinid = 'z' .. self.winid .. ':movewin'

  self.dontuseaardz = false

  self.titlebarlinenum = -1
  self.tablinenum = -1

  -- below are things that can be kept as settings
  self.header_padding = 2

  self.activetab = None
  self.tabs = {} -- key will be tabname, data will be text
  --self.tabstyles = {}
  self.tablist = {}

  self:add_cmd('toggle', {func="cmd_toggle", help="toggle window", nomenu=true})
  self:add_cmd('fonts', {func="cmd_fonts", help="show fonts loaded in this miniwin"})
  self:add_cmd('shade', {func="shade", help="shade the miniwin", nomenu=true})
  self:add_cmd('snapshot', {func="cmd_snapshot", help="make a snapshot of the miniwin"})
  self:add_cmd('info', {func="cmd_info", help="show some info about the window"})
  self:add_cmd('show', {func="cmd_show", help="show the window"})
  self:add_cmd('hide', {func="cmd_hide", help="hide the window"})
  self:add_cmd('front', {func="cmd_front", help="bring the window to the front"})
  self:add_cmd('back', {func="cmd_back", help="put the window in the back"})

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
  self:add_setting( 'bg_colour', {type="colour", help="background colour for this window", default=0x000000, sortlev=3, longname="Background Colour", globalset=true})
  self:add_setting( 'text_colour', {type="colour", help="text colour for this window", default=0xDCDCDC, sortlev=3, longname="Text Colour", globalset=true})
  self:add_setting( 'window_border_colour', {type="colour", help="border colour for window", default=verify_colour("white"), sortlev=4, longname="Window Border Colour", globalset=true})
  self:add_setting( 'window_border_width', {type="number", help="border width for window", default=2, sortlev=4, longname="Window Border Width", globalset=true})
  self:add_setting( 'title_gradient1', {type="colour", help="gradient colour 1 for the titlebar", default=verify_colour(0x151515), sortlev=5, longname="Title Gradient Colour 1", globalset=true})
  self:add_setting( 'title_gradient2', {type="colour", help="gradient colour 2 for the titlebar", default=verify_colour(0x333333), sortlev=5, longname="Title Gradient Colour 2", globalset=true})
  self:add_setting( 'tab_bg_colour', {type="colour", help="background colour for a tab", default=0xDCDCDC, sortlev=6, longname="Tab Background Colour", globalset=true})
  self:add_setting( 'tab_text_colour', {type="colour", help="text colour for a tab", default=0x0D0D0D, sortlev=6, longname="Tab Text Colour", globalset=true})
  self:add_setting( 'tab_border_colour', {type="colour", help="border colour for a tab", default=0xDCDCDC, sortlev=6, longname="Tab Border Colour", globalset=true})
  self:add_setting( 'button_text_colour', {type="colour", help="text colour for the buttons in the titlebar", default=verify_colour("white"), sortlev=10, longname="Button Text Colour", globalset=true})
  self:add_setting( 'button_text_highlight_colour', {type="colour", help="text colour for the buttons in the titlebar", default='black', sortlev=10, longname="Button Text Highlight Colour", globalset=true})
  self:add_setting( 'button_bg_highlight_colour', {type="colour", help="text colour for the buttons in the titlebar", default=0x70CBB9, sortlev=10, longname="Button Background Colour", globalset=true})
  self:add_setting( 'button_border_light', {type="colour", help="border colour for cells", default=0x404040, sortlev=10, longname="Button Border Light", globalset=true})
  self:add_setting( 'button_border_dark', {type="colour", help="border colour for cells", default=0x1F1F1F, sortlev=10, longname="Button Border Dark", globalset=true})
  self:add_setting( 'hyperlink_colour', {type="colour", help="hyperlink colour for this window", default=0x00FFFF, sortlev=15, longname="Hyperlink Colour", globalset=true})
  self:add_setting( 'header_bg_colour', {type="colour", help="header background colour for this window", default=0x696969, sortlev=20, longname="Header Background Colour", globalset=true})
  self:add_setting( 'header_text_colour', {type="colour", help="header text colour for this window", default=0x00FF00, sortlev=20, longname="Header Text Colour", globalset=true})
  self:add_setting( 'header_height', {type="number", help="the header height", default=1, low=0, high=10, sortlev=20, globalset=true})
  self:add_setting( 'footer_bg_colour', {type="colour", help="footer colour for this window", default=0x696969, sortlev=25, longname="Footer Background Colour", globalset=true})
  self:add_setting( 'footer_text_colour', {type="colour", help="footer text colour for this window", default=0x00FF00, sortlev=25, longname="Footer Text Colour", globalset=true})
  self:add_setting( 'border_colour', {type="colour", help="border colour for cells", default="white", sortlev=30, longname="Cell Border Colour", globalset=true})
  self:add_setting( 'textfont', {type="font", help="change the font for this window", default=serialize.save_simple(self:getdefaultfont()), sortlev=35, istable=true, formatfunc=formatfont, globalset=true})
  self:add_setting( 'width', {type="number", help="width of this window, 0 = auto", low=0, default=0, sortlev=40})
  self:add_setting( 'height', {type="number", help="height of this window, 0 = auto", low=0, default=0, sortlev=40})
  self:add_setting( 'height_padding', {type="number", help="height padding for this window", low=0, high=30, default=2, sortlev=45})
  self:add_setting( 'width_padding', {type="number", help="width padding for this window", low=0, high=30, default=2, sortlev=45})
  self:add_setting( 'use_tabwin', {type="bool", help="toggle to use tabwin", default=verify_bool(true), sortlev=50})
  self:add_setting( 'font_warn', {type="bool", help="have been warned about font", default=verify_bool(false), sortlev=55, readonly=true})
  self:add_setting( 'shaded', {type="bool", help="window is shaded", default=verify_bool(false), sortlev=55, readonly=true, globalset=true})
  self:add_setting( 'shade_with_header', {type="bool", help="when window is shaded, still show header", default=verify_bool(false), sortlev=55, longname = "Shade with header"})
  self:add_setting( 'titlebar', {type="bool", help="don't show the titlebar", default=verify_bool(true), sortlev=56, longname="Show the titlebar", globalset=true})
  self:add_setting( 'showtabline', {type="bool", help="(don't) show the titlebar", default=verify_bool(true), sortlev=56, longname="Show the tabline", globalset=true})
  self:add_setting( 'showresize', {type="bool", help="show resize hotspots", default=verify_bool(true), sortlev=56, longname="Show Resize Hotspots"})
  self:add_setting( 'maxlines', {type="number", help="window only shows this number of lines, 0 = no limit", default=0, low=-1, sortlev=57, longname="Max Lines"})
  self:add_setting( 'maxtabs', {type="number", help="maximum # of tabs", default=1, low=0, sortlev=57, longname="Max Tabs"})
  self:add_setting( 'firstshown', {type="bool", help="shown first", default=verify_bool(false), sortlev=57})
  self:add_setting( 'lockwindow', {type="bool", help="make the window non draggable", default=verify_bool(false), sortlev=57, longname="Lock the Window in place"})
  self:add_setting( 'layer', {type="number", help="the layer this miniwin is on, this does not work when using the Aardwolf MUSHclient", default=0, low=-1000, high=1000, longname="Set the Layer", sortlev=57})

  self.default_font_id = '--NoFont--'
  self.default_font_id_bold = nil
  --self.window_data = {}

  self.buttons = {}
  --self.buttonstyles = {}
  self:add_button('menu', {text=" M ", mouseup=function (win, flags, hotspotid)
                        win:menuclick(flags)
                      end, hint="Left Click to show Window menu\nRight Click to show Plugin menu", place=2})
  self:add_button('shade', {text=" - ", mouseup=function (win, tflags, hotspotid)
                        win:shade()
                      end, hint="Click to shade", place=90})
  self:add_button('close', {text=" X ", mouseup=function (win, tflags, hotspotid)
                        win:show(false)
                      end, hint="Click to close", place=99})

  self:registerevent('option_textfont', self, self.onfontchange)
  self:registerevent('option_use_tabwin', self, self.onuse_tabwinchange)
  self:registerevent('option_windowpos', self, self.onwindowposchange)
  self:registerevent('option_layer', self, self.onlayerchange)
  self:registerevent('option-any', self, self.onanychange)
end

function Miniwin:onfontchange(args)
  local font = args.value
  if self.disabled or self.classinit then
    return
  else
    fontid = self:addfont(font.name, font.size, font.bold, font.italic, font.underline, font.strikeout)
    self:setdefaultfont(fontid)
    self:resettabs()
  end
end

function Miniwin:onlayerchange(args)
  --print(self.cname, 'onlayerchange')
  if self.dontuseaardz or not IsPluginInstalled("462b665ecb569efbf261422f") then
    --print(self.cname, 'setting zorder to', self.layer)
    WindowSetZOrder(self.winid, self.layer)
  end
end

function Miniwin:onwindowposchange(args)
  if not self.classinit then
    self.x = -1
    self.y = -1
  end
end

function Miniwin:onuse_tabwinchange(args)
  self:tabbroadcast(self.use_tabwin)
end

function Miniwin:onanychange(args)
  for i,v in pairs(self.tablist) do
    self.tabs[v].convtext = nil
    self.tabs[v].convheader = nil
  end
  if not self.classinit then
    self:resettabs()
  end
end

function Miniwin:updateheader(tabname, header)
  if self.tabs[tabname] ~= nil then
    self.tabs[tabname].header = header
    self.tabs[tabname].convheader = nil
  end
end

function Miniwin:addline(tabname, line)
 -- add a line to the end of the text
end

function Miniwin:addtab(tabname, text, header, makeactive, sticky, position, resetstart)
  timer_start('miniwin:addtab')
  if self.disabled then
    self.classinit = true
    self:init(true)
    self:enable()
  end
  if self.tabs[tabname] == nil then
    self.tabs[tabname] = {}
    self.tabs[tabname].text = text
    self.tabs[tabname].tabname = tabname
    self.tabs[tabname].header = header
    self.tabs[tabname].buttonstyles = {}
    self.tabs[tabname].tabstyles = {}
    if sticky then
      self.tabs[tabname].sticky = true
    end
    if position and #self.tablist >= position then
      table.insert(self.tablist, position, tabname)
    else
      table.insert(self.tablist, tabname)
    end
  else
    self.tabs[tabname].text = text
    self.tabs[tabname].header = header
    self.tabs[tabname].build_data = nil
    self.tabs[tabname].convtext = nil
    self.tabs[tabname].convheader = nil
  end
  if resetstart then
    self.tabs[tabname].startline = nil
  end

  if not self.classinit then
--      if self.activetab then
--        print('activetab.tabname', self.activetab.tabname)
--      else
--        print('no active tab')
--      end
--      print('tabname', tabname)
    if self.maxtabs > 0 and self:counttabs() > self.maxtabs then
      local tabremoved = false
      for i,v in pairs(self.tablist) do
        if not self.tabs[v].sticky then
          tabremoved = table.remove(self.tablist, i)
          break
        end
      end
      self.tabs[tabremoved] = nil
      if tabremoved == self.activetab then
        self:changeactivetab(tabname)
        self:resettabs()
      else
        if #self.tablist > 2 then
          --print('redrawing tabline only')
          self:redrawtabline()
        else
          self:resettabs()
        end
      end
    elseif self.activetab and self.activetab.tabname ~= tabname then
      --redraw tab line only
      if #self.tablist > 2 then
        --print('redrawing tabline only')
        self:redrawtabline()
      else
        self:resettabs()
      end
    else
      self:redraw()
    end
    if self.activetab == nil or makeactive then
      self:changeactivetab(tabname)
      self:resettabs()
    end
    --self:resettabs()
    --self:redraw()
  end
  if not self.firstshown then
    self:set('firstshown', true)
    self:show(true)
  end
  timer_end('miniwin:addtab')
end

function Miniwin:changeactivetab(tabname)
  self.activetab = self.tabs[tabname]
  self:processevent('tabchange', {newtab=tabname})
end

function Miniwin:settabnametext(tabname, newtext)
  if self.tabs[tabname] then
    self.tabs[tabname].tabnametext = newtext
  end
  -- just redraw the tabline instead of the entire window
  self:redrawtabline()
end

function Miniwin:redrawtabline()
  if self:counttabs() > 1 and self.showtabline then
    if self.activetab.build_data and next(self.activetab.build_data) and self.activetab.build_data.tabbarlinenum then
      local tabline = self:buildtabline()
      self.activetab.tabbarlineconv = self:convert_line(tabline, 1, 0, 0, 'tabbarline')[1]
      if self.activetab.build_data[self.activetab.build_data.tabbarlinenum - 1] then
        local top = self.activetab.build_data[self.activetab.build_data.tabbarlinenum - 1].linebottom
        self.activetab.build_data[self.activetab.build_data.tabbarlinenum] = self:justify_line(self.activetab.tabbarlineconv, top, self.activetab.build_data.tabbarlinenum, 'tabbarline')
        self:displayline(self.activetab.tabbarlineconv, true)
      end
    end
  end
end

function Miniwin:stickytab(tabname)
  self.tabs[tabname].sticky = true
end

function Miniwin:unstickytab(tabname)
  self.tabs[tabname].sticky = false
end

function Miniwin:resettabs()
 timer_start('miniwin:resettabs')
 for i,v in pairs(self.tabs) do
   v.build_data = nil
 end
 if not self.classinit then
   self:redraw()
 end
 timer_end('miniwin:resettabs')
end

function Miniwin:removetab(tabname)
  for i,v in pairs(self.tablist) do
    if self.tabs[v].tabname == tabname then
      table.remove(self.tablist, i)
    end
  end
  self.tabs[tabname] = nil
  if tabname == self.activetab.tabname then
    self:changetotab(self.tablist[1])
    self:redraw()
  else
    self:resettabs()
  end
end

function Miniwin:counttabs()
  return #self.tablist
end

function Miniwin:hastab(tabname)
  if self.tabs[tabname] then
    return true
  else
    return false
  end
end

function Miniwin:changetotab(tabname)
  if self.tabs[tabname] then
    self:changeactivetab(tabname)
    self:redraw()
  end
end

function Miniwin:tabmenu(tabname)
  local menu = 'Close'
  local stext = '| Sticky'
  if self.tabs[tabname].sticky then
    stext = ' | UnSticky'
  end
  menu = menu .. stext
  local result = WindowMenu (self.winid, WindowInfo (self.winid, 14), WindowInfo (self.winid, 15), menu) --do menu
  if result:match(' - ') then
    local tresult = utils.split(result, '-')
    result = trim(tresult[1])
  end
  if result ~= "" then
    if result:match("UnSticky") then
      self:unstickytab(tabname)
    elseif result:match("Sticky") then
      self:stickytab(tabname)
    elseif result:match("Close") then
      self:removetab(tabname)
    end
  end
end

function Miniwin:createtabstyle(v, tstyle)
  local style = copytable.deep(tstyle)
  style.tab = v.tabname
  style.mouseup = function(win, flags, hotspot_id)
                    if bit.band(flags, 0x10) ~= 0 then
                      -- left
                      self:changetotab(v.tabname)
                    elseif bit.band(flags, 0x20) ~= 0 then
                      -- right
                      self:tabmenu(v.tabname)
                    end
                  end
  style.mouseover = function(win, flags, hotspot_id)

                    end
--  style.leftborder = true
--  style.rightborder = true
  style.bordercolour = 'tab_border_colour'
  if v.tabname == self.activetab.tabname then
    if not style.textcolour then
      style.textcolour = 'tab_text_colour'
    end
    if not style.backcolour then
      style.backcolour = 'tab_bg_colour'
    end
    style.bordercolour = 'tab_border_colour'
    style.fillall = true
  end
  return style
end

function Miniwin:buildtabline()
  if self:counttabs() > 1 then
    local tabline = {}
    for i,v in ipairs(self.tablist) do
      v = self.tabs[v]
      if v.tabnametext ~= nil then
        local style = self:createtabstyle(v, {text=" " .. v.tabname .. " ", leftborder = true})
        table.insert(tabline, style)
        if type(v.tabnametext) == 'string' then
          local style = self:createtabstyle(v, {text=v.tabnametext})
          table.insert(tabline, style)
        elseif type(v.tabnametext) == 'table' then
          for i,x in ipairs(v.tabnametext) do
             local style = self:createtabstyle(v, x)
             table.insert(tabline, style)
          end
        end
        local style = self:createtabstyle(v, {text=" ", rightborder = true})
        table.insert(tabline, style)
      else
        local style = self:createtabstyle(v, {text=" " .. v.tabname .. " ", leftborder=true, rightborder=true})
        table.insert(tabline, style)
      end
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

function Miniwin:cmd_show(cmddict)
  self:show(true)
end

function Miniwin:cmd_hide(cmddict)
  self:show(false)
end

function Miniwin:cmd_front(cmddict)
  self:front()
end

function Miniwin:cmd_back(cmddict)
  self:back()
end

-- Command to take snapshot of this window
function Miniwin:cmd_snapshot(cmddict)
  local tfile = cmddict[1]
  local tdir = GetInfo(64)
  if tfile == nil then
     tfile = tostring(utils.inputbox("Enter a filename, will be saved in \n  " .. tdir))
  end
  if tfile then
    WindowWrite(self.winid, tfile)
  else
    phelper:plugin_header("Snapshot")
    ColourNote(RGBColourToName(var.plugin_colour), "black", "No filename specified")
  end

end

-- Command to show info
function Miniwin:cmd_info(cmddict)
  self:plugin_header('Info')
  ColourNote(RGBColourToName(var.plugin_colour), "black", string.format("%-20s : %s" , 'Name', self.cname))
  ColourNote(RGBColourToName(var.plugin_colour), "black", string.format("%-20s : %s" , 'Id', self.winid))
  ColourNote(RGBColourToName(var.plugin_colour), "black", string.format("%-20s : %s" , 'Shown', tostring(WindowInfo(self.winid, 5))))
  ColourNote(RGBColourToName(var.plugin_colour), "black", string.format("%-20s : %s" , 'Hidden', tostring(WindowInfo(self.winid, 6))))
  ColourNote(RGBColourToName(var.plugin_colour), "black", string.format("%-20s : %s" , 'Left', tostring(WindowInfo(self.winid, 10))))
  ColourNote(RGBColourToName(var.plugin_colour), "black", string.format("%-20s : %s" , 'Top', tostring(WindowInfo(self.winid, 11))))
  if self.activetab then
    ColourNote(RGBColourToName(var.plugin_colour), "black", string.format("%-20s : %s" , 'Height', tostring(WindowInfo(self.winid, 4))))
    ColourNote(RGBColourToName(var.plugin_colour), "black", string.format("%-20s : %s" , 'Width', tostring(WindowInfo(self.winid, 3))))
    ColourNote(RGBColourToName(var.plugin_colour), "black", string.format("%-20s : %s" , 'Calced Height', tostring(self.activetab.build_data.actualwindowheight)))
    ColourNote(RGBColourToName(var.plugin_colour), "black", string.format("%-20s : %s" , 'Calced Width', tostring(self.activetab.build_data.actualwindowwidth)))
  end
end

-- Command to print loaded fonts for this window
function Miniwin:cmd_fonts(cmddict)
  self:plugin_header('Loaded Fonts')
  local fonts = WindowFontList(self.winid)
  local tstuff = string.format('%-40s %-20s %-3s %-4s %s', 'id', 'name', 'size', 'height', 'flags')
  ColourNote(RGBColourToName(var.plugin_colour), "", tstuff)
  if fonts then
    for _, v in ipairs (fonts) do
      local name = WindowFontInfo(self.winid, v, 21)
      local size = round ( (WindowFontInfo(self.winid, v, 1) - WindowFontInfo(self.winid, v, 4)) * 72 / GetDeviceCaps (90) )
      local bold = tonumber(WindowFontInfo(self.winid, v, 8)) > 400
      local italic = tonumber(WindowFontInfo(self.winid, v, 16)) > 0
      local underline = tonumber(WindowFontInfo(self.winid, v, 17)) > 0
      local struck = tonumber(WindowFontInfo(self.winid, v, 18)) > 0
      local height = tonumber(WindowFontInfo(self.winid, v, 1))
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
    tshownf = tostring(WindowInfo(self.winid, 5))
    SetVariable ("shown"..self.cname, tshownf)
  end
  super(self)
end

-- check if a font is installed
function Miniwin:isfontinstalled(fontid, font_name, win)
  local twin = win or self.winid
  if string.lower(WindowFontInfo (twin, fontid, 21)) == string.lower(font_name) then
    return true
  end
  return false

end

-- check to see if a fontid exists in the miniwindow
function Miniwin:checkfontid(font)
  local font = string.lower(font)
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
  self.default_font_id_bold =  self:addfont(self.fonts[self.default_font_id].name,
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
  local fontt = {}
  fontt.bold = verify_bool(bold)
  fontt.italic = verify_bool(italic)
  fontt.underline = verify_bool(underline)
  fontt.strikeout = verify_bool(strikeout)
  fontt.name = string.lower(font or "")
  fontt.size = tonumber(size or "8")
  local fontid = self:buildfontid(fontt.name, fontt.size, fontt.bold, fontt.italic, fontt.underline, fontt.strikeout)
  if self:checkfontid(fontid) then
    return fontid
  end

  local tfontt = verify_font(fontt, {})
  if tfontt ~= nil then
    tfontt.id = fontid
  end

  if not WindowInfo (self.winid, 4) then
    --print(self.cname, 'WindowCreate addfont')
    check (WindowCreate (self.winid,
                 0, 0,   -- left, top (auto-positions)
                 0,     -- width
                 0,  -- height
                 0,
                 2,  -- flags
                 self:get_colour("bg_colour")) )
    if IsPluginInstalled("462b665ecb569efbf261422f") and self.dontuseaardz == false then
      --print(self.cname, 'registering window in add font')
      CallPlugin("462b665ecb569efbf261422f", "registerMiniwindow", self.winid)
    end
  end
  check (WindowFont (self.winid, tfontt.id, tfontt.name, tfontt.size,
                     tfontt.bold, tfontt.italic, tfontt.underline,
                     tfontt.strikeout, 0, 49))
  tfontt.height = WindowFontInfo (self.winid, fontid, 1) -- height
  tfontt.width = WindowFontInfo (self.winid, fontid, 6)  -- avg width_padding

  self.fonts[tfontt.id] = tfontt
  return tfontt.id

end

function Miniwin:reloadfonts()
  local tfonts = copytable.shallow(self.fonts)
  self.fonts = {}
  for i,v in pairs(tfonts) do
    self:addfont(v.name, v.size, v.bold, v.italic, v.underline, v.strikeout)
  end
end

-- get the default font if no font is loaded in a miniwindow
function Miniwin:getdefaultfont()
  local tempid = self.winid .. '_default_font_win'
  check (WindowCreate (tempid,
                 0, 0, 1, 1,
                 6,   -- top right
                 0,
                 verify_colour('black')) )

  check (WindowFont (tempid, "--NoFont--", "--NoFont--", 8, false, false, false, false, 0, 49))  -- normal

  local rstring = string.lower(WindowFontInfo (tempid, "--NoFont--", 21))

  WindowDelete(tempid)

  return {name=rstring, size=8}

end

-- add a button to the button bar, see notes at the top of this file
function Miniwin:add_button(button, buttoninfo)
  self.buttons[button] = buttoninfo
end

function Miniwin:buttonmouseover(name)
   self.activetab.buttonstyles[name].textcolour = 'button_text_highlight_colour'
   self.activetab.buttonstyles[name].backcolour = 'button_bg_highlight_colour'
   self:displayline(self.activetab.build_data[self.activetab.buttonstyles[name].linenum])
   Redraw()
end

function Miniwin:buttoncancelmouseover(name)
   self.activetab.buttonstyles[name].textcolour = 'button_text_colour'
   self.activetab.buttonstyles[name].backcolour = nil
   self:displayline(self.activetab.build_data[self.activetab.buttonstyles[name].linenum])
   Redraw()
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
    style.font_name = 'Dina'
    style.font_size = 9
    style.mousedown = button.mousedown
    style.mouseup = button.mouseup
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

    style.button = name
    if button.place > 50 then
      if (not addedtitle) and (not self.notitletext) then
        addedtitle = true
        local hstyle = {}
        hstyle.text = self.titlebartext or self.cname
        hstyle.bold = true
        hstyle.textcolour = "button_text_colour"
        hstyle.hjust = 'center'
        hstyle.font_name = 'Dina'
        hstyle.font_size = 9
        table.insert(tstyle, hstyle)
      end
      style.hjust = 'right'
    end
    table.insert(tstyle, style)

  end

  tstyle.bordercolour = 'white'
  --tstyle.backcolour = 'title_bg_colour'
  --tstyle.lineborder = true
  tstyle.bottomborder = true
  --tstyle.cellborder = true
  --tstyle.backcolour = 'black'
  tstyle.gradient = true
  tstyle.colour1 = 'title_gradient1'
  tstyle.colour2 = 'title_gradient2'
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
        local tfont = self.fonts[self.default_font_id]
        local fonttable = {}
        fonttable.name = tfont.name
        fonttable.size = tfont.size
        local newtable = copytable.shallow(self.set_options['textfont'])
        newtable.ask = true
        local wanted_font = verify_font(fonttable, newtable)
        if wanted_font then
                self:set('textfont', wanted_font)
        end
end

-- build the mousemenu, looks for anything in the settings table with a longname
function Miniwin:buildmousemenu()
  local menu = "Window Menu || >Font | Set font - Currently: " .. tostring(self.textfont.name) .. ', ' .. tostring(self.textfont.size) .. " | Increase font size | Decrease font size | Default Font | < | >Colours "
  --local colours = {}
  for name,setting in tableSort(self.set_options, 'sortlev', 50) do
    if setting.longname ~= nil and setting.type == 'colour' then
      --table.append(colours, name, true)
      menu = menu .. ' | ' .. setting.longname .. ' - Currently: ' .. tostring( RGBColourToName(self:get_colour(self[name])))
    end
  end
  --for name,value in table.sort(colours,
  menu = menu .. ' | < | >Toggle '
  for name,setting in tableSort(self.set_options, 'sortlev', 50) do
    if setting.longname ~= nil and setting.type == 'bool' then
      local estring = ""
      if self[name] then
        estring = "+"
      end
      menu = menu .. ' | ' .. estring .. setting.longname
    end
  end
  menu = menu .. ' | < | >Other '
  for name,setting in tableSort(self.set_options, 'sortlev', 50) do
    if setting.longname ~= nil and setting.type ~= 'bool' and setting.type ~= 'colour' then
      menu = menu .. ' | ' .. setting.longname .. ' - Currently: ' .. tostring(self[name])
    end
  end
  menu = menu .. ' | < || >Reset | Reset All | Reset Size | Reset Position | < || >Commands '
  for name,cmd in pairs(self.cmds_table) do
    if cmd.nomenu ~= true then
      menu = menu .. '|' .. name .. ' - ' .. cmd.help
    end
  end
  menu = menu .. '| < '
  menu = menu .. '|| Bring to Front | Send to Back '
  menu = menu .. '|| Copy Text to Clipboard '
  menu = menu .. '|| Help'
  return menu
end

function Miniwin:buildpluginmousemenu()
  local menu = "Plugin Menu || >Colours "
  --local colours = {}
  for name,setting in tableSort(self.phelper.set_options, 'sortlev', 50) do
    if setting.longname ~= nil and setting.type == 'colour' then
      --table.append(colours, name, true)
      menu = menu .. ' | ' .. setting.longname .. ' - Currently: ' .. tostring( RGBColourToName(self.phelper[name]))
    end
  end
  --for name,value in table.sort(colours,
  menu = menu .. ' | < | >Toggle '
  for name,setting in tableSort(self.phelper.set_options, 'sortlev', 50) do
    if setting.longname ~= nil and setting.type == 'bool' then
      menu = menu .. ' | ' .. setting.longname .. ' - Currently: ' .. tostring(self.phelper[name])
    end
  end
  menu = menu .. ' | < | >Other '
  for name,setting in tableSort(self.phelper.set_options, 'sortlev', 50) do
    if setting.longname ~= nil and setting.type ~= 'bool' and setting.type ~= 'colour' then
      menu = menu .. ' | ' .. setting.longname .. ' - Currently: ' .. tostring(self.phelper[name])
    end
  end
  menu = menu .. ' | < || Restore Plugin Defaults || >Commands'
  for name,cmd in pairs(phelper.cmds_table) do
    if cmd.nomenu ~= true then
      menu = menu .. '|' .. name .. ' - ' .. cmd.help
    end
  end
  menu = menu .. '| < || Help'
  return menu
end

function Miniwin:movewindow()
  local flags = 0
  if self.x >= 0 and self.y >= 0 then
    flags = 2
  end
  WindowPosition(self.winid, self.x, self.y, self.windowpos, flags);
end


-- the function called when the mouse is clicked in the menu button
function Miniwin:windowmenu(result)
  if result:match("Set font") then
    self:menusetfont()
  elseif result == "Increase font size" then
    local tfont = copytable.shallow(self.textfont)
    tfont.size = tfont.size + 1
    self:set('textfont', tfont)
  elseif result == "Decrease font size" then
    local tfont = copytable.shallow(self.textfont)
    tfont.size = tfont.size - 1
    self:set('textfont', tfont)
  elseif result == "Default Font" then
    self:set('textfont', 'default')
  elseif result == 'Reset All' then
    self:cmd_reset()
  elseif result == 'Bring to Front' then
    if IsPluginInstalled("462b665ecb569efbf261422f") then
      --print(self.cname, 'boostMe')
      CallPlugin("462b665ecb569efbf261422f","boostMe", self.winid)
    else
      self:set('layer', 200)
    end
  elseif result == 'Send to Back' then
    if IsPluginInstalled("462b665ecb569efbf261422f") then
      --print(self.cname, 'dropMe')
      CallPlugin("462b665ecb569efbf261422f","dropMe", self.winid)
    else
      self:set('layer', -200)
    end
  elseif result == 'Copy Text to Clipboard' then
    SetClipboard(self:getfulltextforactivetab())
  elseif result == "Reset Size" then
    self.width = self.set_options.width.default
    self.height = self.set_options.height.default
    WindowResize(self.winid, self.width, self.height, self:get_colour('bg_colour'))
    SaveState()
    self:resettabs()
  elseif result == 'Reset Position' then
    self.x = self.set_options.x.default
    self.y = self.set_options.y.default
    self.windowpos = self.set_options.windowpos.default
    SaveState()
    self:movewindow()
  elseif result == "Help" then
    self.phelper.helpwin:show(true)
  else
    for name,setting in tableSort(self.set_options, 'type', 'unknown') do
      if result == setting.longname then

        if setting.type == 'bool' then
          return self:set(name, not self[name])
        else
          return self:set(name, nil)
        end
      end
    end
    if self.cmds_table[result] ~= nil then
      self:run_cmd({action=result})
    end
  end

end

function Miniwin:pluginmenu(result)
  if result:match("Restore Plugin Defaults") then
    self.phelper:cmd_reset()
  elseif result == "Help" then
    self.phelper.helpwin:show(true)
  else
    for name,setting in tableSort(self.phelper.set_options, 'type', 'unknown') do
      if result == setting.longname then

        if setting.type == 'bool' then
          return self.phelper:set(name, not self[name])
        else
          return self.phelper:set(name, nil)
        end
      end
    end
    if phelper.cmds_table[result] ~= nil then
      phelper:run_cmd({action=result})
    end
  end
end

function Miniwin:getfulltextforactivetab()
  local newtext = ''
  if self.activetab.justheader ~= '' then
    newtext = self.activetab.justheader
  end
  newtext = newtext .. self.activetab.justtext
  return newtext
end

function Miniwin:menuclick(flags)
  local menu = ''
  --make text for menu options
  -- right click for window menu, left click for plugin menu
  if bit.band(flags, 0x10) ~= 0 then
    menu = self:buildmousemenu()
    menutype = 'window'
  elseif bit.band(flags, 0x20) ~= 0 then
    menu = self:buildpluginmousemenu()
    menutype = 'plugin'
  end
  local result = WindowMenu (self.winid, WindowInfo (self.winid, 14), WindowInfo (self.winid, 15), menu) --do menu
  if result:match(' - ') then
    tresult = utils.split(result, '-')
    result = trim(tresult[1])
  end
  if result ~= "" then
    if menutype == 'plugin' then
      self:pluginmenu(result)
    else
      self:windowmenu(result)
    end
  end
end -- ListMenu

-- redraw the window
function Miniwin:redraw(justtext)
   local shown = WindowInfo(self.winid, 5)
   if self.firstdrawn then
    local flag = verify_bool(GetVariable ("shown"..self.cname))
    self.firstdrawn = false
    if flag == nil then
      flag = false
    end
    shown = flag
   end
   if justtext then
     self:drawtext(self.activetab)
   else
     --self:buildwindow(self.activetab)
     self:drawwin()
   end
   WindowShow(self.winid, shown)
end

-- show or hide the window
function Miniwin:show(flag)
  if flag == nil or verify_bool(self.disabled) then
    flag = false
  end
  WindowShow(self.winid, flag)
  SaveState()
  self:processevent('visibility', {flag=flag})
end

function Miniwin:front()
  if IsPluginInstalled("462b665ecb569efbf261422f") then
    --print(self.cname, 'boostMe')
    CallPlugin("462b665ecb569efbf261422f","boostMe", self.winid)
  else
    self:set('layer', 200)
  end
end

function Miniwin:back()
  if IsPluginInstalled("462b665ecb569efbf261422f") then
    --print(self.cname, 'dropMe')
    CallPlugin("462b665ecb569efbf261422f","dropMe", self.winid)
  else
    self:set('layer', -200)
  end
end

-- init the window after the plugin has been initialized
function Miniwin:init()
  super(self)
  local font = self.textfont
  self:setdefaultfont(self:addfont(font.name, font.size, font.bold, font.italic, font.underline, font.strikeout))
end

-- enable the window
function Miniwin:enable()
  local disabled = self.disabled
  super(self)
  if disabled ~= self.disabled then
    self:tabbroadcast(true)
  end
end

-- disable the window
function Miniwin:disable()
  self.firstdrawn = true
  self:show(false)
  local disabled = self.disabled
  super(self)
  if disabled ~= self.disabled then
    self:tabbroadcast(false)
  end
end

-- toggle the window to be shown/not shown
function Miniwin:toggle()
  if not self.disabled then
    self:show(not WindowInfo(self.winid, 5))
  end
  self:savestate()
end

-- shade the window
function Miniwin:shade()
  if not self.disabled then
    self:set('shaded', not self.shaded)
    self:processevent('shade', {flag=self.shaded})
  end
  self:savestate()
end

function Miniwin:addscrollwheelhandler(id, wheelcallback)
  if wheelcallback then
   self.hyperlink_functions['wheelcallback'] [id] = wheelcallback
   wheelcallback = "wheelcallback"
  end
  WindowScrollwheelHandler(self.winid, self.id .. ':' .. id, wheelcallback)
end

-- wheelcallback function, checks to see if the id exists in the hyperlink_functions['wheelcallback'] table
function Miniwin:wheelcallback (flags, hotspotid)
  local f = self.hyperlink_functions['wheelcallback'][hotspotid]
  if f then
    f(self, flags, hotspotid)
    return true
  end -- function found

  return false
end -- movecallback

function Miniwin:adddraghandler(id, movecallback, releasecallback, flags)
  if movecallback then
   self.hyperlink_functions['movecallback'] [id] = movecallback
   movecallback = "movecallback"
  end
  if releasecallback then
   self.hyperlink_functions['releasecallback'] [id] = releasecallback
   releasecallback = "releasecallback"
  end
  WindowDragHandler(self.winid, self.id .. ':' .. id, movecallback, releasecallback, flags)
end

-- movecallback function, checks to see if the id exists in the hyperlink_functions['movecallback'] table
function Miniwin:movecallback (flags, hotspotid)

  local f = self.hyperlink_functions['movecallback'][hotspotid]
  if f then
    f(self, flags, hotspotid)
    return true
  end -- function found

  return false
end -- movecallback

-- releasecallback function, checks to see if the id exists in the hyperlink_functions['releasecallback'] table
function Miniwin:releasecallback (flags, hotspotid)

  local f = self.hyperlink_functions['releasecallback'][hotspotid]
  if f then
    f(self, flags, hotspotid)
    return true
  end -- function found

  return false
end -- releasecallback

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
  WindowAddHotspot(self.winid, self.id .. ':' .. id,
                left, top, right, bottom,
                mouseover, -- mouseover
                cancelmouseover, -- cancelmouseover
                mousedown,
                cancelmousedown, -- cancelmousedown
                mouseup, -- mouseup
                hint,
                cursor or 1, 0)

  if left >= self.activetab.build_data.textarea.left and left <= self.activetab.build_data.textarea.right and
        top >= self.activetab.build_data.textarea.top and top <= self.activetab.build_data.textarea.bottom then
     table.insert(self.textareahotspots, self.id .. ':' .. id)
     if self.activetab.build_data.drawscrollbar then
       self:addscrollwheelhandler(id, self.wheelmove)
     end
  end

end

-- mousedown function, checks to see if the id exists in the hyperlink_functions['mousedown'] table
function Miniwin:mousedown (flags, hotspotid)
  -- find where mouse is so we can adjust window relative to mouse
  self.startx, self.starty = WindowInfo (self.winid, 14), WindowInfo (self.winid, 15)

  -- find where window is in case we drag it offscreen
  self.origx, self.origy = WindowInfo (self.winid, 10), WindowInfo (self.winid, 11)
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

-- convert a line, go through and figure out colours, fonts, start positions, end positions, and borders for every line
-- toppadding = extra spacing between top of line and top of text cell
-- bottompadding = extra spacing between bottom of line and bottom of text cell
-- textpadding = extra spacing between cell wall and text
-- check against self.width or self.maxlinelength
function Miniwin:convert_line(line, toppadding, bottompadding, textpadding, ltype)
  local alllines = {}
  local fulllinetext = ''
  local bottompadding = bottompadding or 0
  local toppadding = toppadding or 0
  local textpadding = textpadding or 0
  local linet = {}
  local def_font_id = self.default_font_id
  local def_colour = self:get_colour('text_colour')
  local maxfontheight = 0
  local linecharlength = 0
  local start = self.window_border_width + self.width_padding
  local def_colour = nil
  if ltype == 'tabbarline' then
    start = self.window_border_width
  end
  if ltype == 'titlebarline' then
    start = self.window_border_width + 2
  end
  if ltype == 'headerline' then
      def_font_id = self.default_font_id_bold
      def_colour = self:get_colour("header_text_colour")
  end
  linet.text = {}
  if type(line) ~= 'table' then
    line = parseURLs(line)
  end
  if type(line) == 'table' then
    local ti = 0
    for i,style in ipairs(line) do
      local pstuff = parseURLs(style.text)
      for i2,v in ipairs(pstuff) do
        ti = ti + 1
        local tstyle = copytable.deep(style)
        if v.url then
          if tstyle.mouseup then
            local oldfunc = tstyle.mouseup
            tstyle.mouseup = function (win, flags, hotspotid)
               oldfunc(win, flags, hotspotid)
               OpenBrowser(v.text)
            end
          else
            tstyle.mouseup = function ()
              OpenBrowser(v.text)
            end
          end
        end
        tstyle.text = v.text
        fulllinetext = fulllinetext .. v.text
        if ti ~= 1 and tstyle.start and tstyle.start < start then
          tstyle.start = nil
        end
        table.insert(linet.text, ti, tstyle)
        local font_id = self:addfont(style.font_name or self.fonts[def_font_id].name,
                        style.font_size or self.fonts[def_font_id].size,
                        style.bold or self.fonts[def_font_id].bold,
                        style.italic or self.fonts[def_font_id].italic,
                        style.underline or self.fonts[def_font_id].underline,
                        style.strikeout or self.fonts[def_font_id].strikeout)

        maxfontheight = math.max(maxfontheight, self.fonts[font_id].height)
        if tstyle.image and tstyle.image.name then
          self:mdebug('Convert_Line: Got Image')
        elseif tstyle.circleOp and tstyle.circleOp.width then
          self:mdebug('Convert_Line: Got CircleOp')
        else
          local tlength = 0
          if tstyle.text then
            if tstyle.nocolourconvert then
              tlength = WindowTextWidth (self.winid, font_id, tstyle.text)
            else
              tlength = WindowTextWidth (self.winid, font_id, strip_colours(tstyle.text))
            end
          end
          if tstyle.start and tstyle.start > start then
            linet.text[ti].start = tstyle.start
            start = tstyle.start + tlength
          else
            linet.text[ti].start = start
            start = start + tlength
          end
          linet.text[ti].stylelen = tlength
          linet.text[ti].font_id = font_id
          linet.text[ti].bordercolour = tstyle.bordercolour or self.border_colour
          linet.text[ti].textcolour = tstyle.textcolour or def_colour
        end
        linecharlength = linecharlength + tstyle.text:len()
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
  end
  linet.lineborder = line.lineborder
  linet.toppadding = toppadding
  linet.bottompadding = bottompadding
  linet.textpadding = textpadding
  linet.width = start
  linet.height = maxfontheight
  linet.linecharlength = linecharlength
  linet.gradient = line.gradient
  linet.colour1 = line.colour1
  linet.colour2 = line.colour2
  linet.fulllinetext = fulllinetext
  table.insert(alllines, linet)
  --print(fulllinetext)
  return alllines
end


-- horizontal and vertical justify styles in a line after we have found out height and width of window
-- and all styles in the line
function Miniwin:justify_line(line, top, linenum, ltype, linestart, lineend)
  line.linetop = top
  line.celltop = line.linetop + line.toppadding
  line.texttop = line.celltop + line.textpadding
  line.textbottom = line.texttop + line.height + 1
  line.cellbottom = line.textbottom + line.textpadding
  line.linebottom = line.cellbottom + line.bottompadding
  line.linestart = linestart or (0 + self.window_border_width)
  line.lineend = lineend or (self.activetab.build_data.actualwindowwidth - self.window_border_width)

  for i,v in ipairs (line.text) do
    local stylelen = 0
    local tstart = v.start
    local ttop = line.texttop
    v.linenum = linenum
    if v.vjust ~= nil then
      if v.vjust == 'center' then
        local theight = line.height
        local fheight = WindowFontInfo(self.winid, v.font_id, 1)
        ttop = ttop + (theight - fheight) / 2
      elseif v.vjust == 'bottom' then
        local theight = line.height
        local fheight = WindowFontInfo(self.winid, v.font_id, 1)
        ttop = ttop + theight - fheight
      end
    end
    if v.hjust ~= nil then
      if v.hjust == 'center' then
        local centerofline = ((line.lineend - line.linestart) / 2) + line.linestart
        tstart = centerofline - (v.stylelen / 2)
      elseif v.hjust == 'right' then

        local twidth = line.width
        local wwidth = line.lineend
        if ltype == 'titlebarline' then
          wwidth = self.activetab.build_data.actualwindowwidth - self.window_border_width - 2
        end
        local restt = twidth - tstart
        local restw = wwidth - tstart
        tstart = tstart + restw - restt
      end
    end
    v.textstart = tstart
    v.texttop = ttop + 1
    if v.nocolourconvert then
        v.stylelen = WindowTextWidth (self.winid, v.font_id, v.text,
                      v.textstart, v.texttop, 0, 0, self:get_colour(v.textcolour or self.text_colour))
    elseif v.textcolour ~= nil or v.nocolourconvert then
        v.stylelen = 0
        if v.text then
          v.stylelen = WindowTextWidth (self.winid, v.font_id, strip_colours(v.text),
                      v.textstart, v.texttop, 0, 0, self:get_colour(v.textcolour))
        end
    else
        v.stylelen = self:colourtext(v.font_id, v.text, v.textstart, v.texttop, 0, 0, nil, true)
    end


    if tstart + v.stylelen >= line.lineend then
      if ltype == 'titlebarline' then
        v.textend = self.activetab.build_data.actualwindowwidth - self.window_border_width - 2
      else
        v.textend = line.lineend
      end
    else
      v.textend = v.textstart + v.stylelen
    end

    if v.button then
      self.activetab.buttonstyles[v.button] = v
    end
    if v.tab then
      self.activetab.tabstyles[v.tab] = v
    end
  end -- for each style run

  return line
end

function Miniwin:is_header_line(linenum)
  if self.actual_header_start_line ~= nil and self.actual_header_end_line ~= nil then
    return linenum >= self.actual_header_start_line  and linenum <= self.actual_header_end_line
  else
    return false
  end
end

function Miniwin:convert_tab(tabname)
 -- goes through text and header and finds the max line width in pixels and max line width in characters
 -- go through and convert each text line
 -- will need to do this on font change, width change, height change
 timer_start('miniwin:convert_tab:' .. tabname)
 self.tabs[tabname].convtext = {}
 self.tabs[tabname].convheader = {}
 self.tabs[tabname].justtext = ''
 self.tabs[tabname].justheader = ''
 local maxwidth = 0
 local maxcharlength = 0

 if self.tabs[tabname].text then
   local linenum = 0
   for i,v in ipairs(self.tabs[tabname].text) do
     local tlines = self:convert_line(v)
     for ii,vv in ipairs(tlines) do
       linenum = linenum + 1
       self.tabs[tabname].justtext =  self.tabs[tabname].justtext .. vv.fulllinetext .. "\r\n"
       self.tabs[tabname].convtext[linenum] = vv
       maxwidth = math.max(maxwidth, self.tabs[tabname].convtext[linenum].width)
       maxcharlength = math.max(maxcharlength, self.tabs[tabname].convtext[linenum].linecharlength)
     end
   end
 end
 -- go through and convert each header line
 if self.tabs[tabname].header then
   local linenum = 0
   for i,v in ipairs(self.tabs[tabname].header) do
     if i == 1 and #self.tabs[tabname].header == 1 then
       tlines = self:convert_line(v, 3, 2, 0, 'headerline')
     elseif i == 1 and #self.tabs[tabname].header > 1 then
       tlines = self:convert_line(v, 3, 0, 0, 'headerline')
     elseif i == #self.tabs[tabname].header then
       tlines = self:convert_line(v, 0, 2, 0, 'headerline')
     else
       tlines = self:convert_line(v, 0, 0, 0, 'headerline')
     end
     for ii,vv in ipairs(tlines) do
       linenum = linenum + 1
       self.tabs[tabname].justheader =  self.tabs[tabname].justheader .. vv.fulllinetext .. "\r\n"
       self.tabs[tabname].convheader[linenum] = vv
       maxwidth = math.max(maxwidth, self.tabs[tabname].convheader[linenum].width)
       maxcharlength = math.max(maxcharlength, self.tabs[tabname].convheader[linenum].linecharlength)
     end
   end
 end
 self.tabs[tabname].maxwidth = maxwidth
 self.tabs[tabname].maxlinecharlength = maxcharlength
 timer_end('miniwin:convert_tab:' .. tabname)
end

-- create the window and do things before text is drawn
function Miniwin:pre_create_window_internal(height, width, x, y)
  timer_start('miniwin:pre_create_window_internal')
  if self.activetab == nil then
    return
  end

  if not self.activetab.convtext or (self.activetab.header and not self.activetab.convheader) or not self.activetab.maxwidth then
    self:convert_tab(self.activetab.tabname)
  end

  if self.activetab.startline == nil then
    self.activetab.startline = 1
  end

  if self.activetab.build_data == nil then
    self.activetab.build_data = {}
  end
  self.activetab.build_data.actual_header_start_line = nil
  self.activetab.build_data.actual_header_end_line = nil
  self.activetab.build_data.actual_text_start_line = nil
  self.activetab.build_data.actual_text_end_line = nil
  self.activetab.build_data.titlebarlinenum = -1
  self.activetab.build_data.tablinenum = -1
  self.activetab.build_data.drawscrollbar = false
  self.activetab.build_data.textarea = {}

  local height = 0
  local tempdata = {}
  local header = {}
  local text = {}
  local linenum = 0

  self.activetab.build_data.maxlinewidth = 0

  if self.titlebar then
    linenum = linenum + 1
    local titlebar = self:buildtitlebar()
    self.activetab.build_data.titlebarlinenum = linenum
    self.activetab.titlebarconv = self:convert_line(titlebar, 2, 2, 1, 'titlebarline')[1]
  end

  if self:counttabs() > 1 then
    linenum = linenum + 1
    local tabline = self:buildtabline()
    self.activetab.build_data.tabbarlinenum = linenum
    self.activetab.tabbarlineconv = self:convert_line(tabline, 1, 0, 0, 'tabbarline')[1]
    self.activetab.maxwidthwithtabline = math.max(self.activetab.maxwidth, self.activetab.tabbarlineconv.width)
  end

  -- at this point everything has been converted

  if self.width > 0 then
    self.activetab.build_data.actualwindowwidth = self.width
    self.activetab.build_data.textarea.left = 0 + self.window_border_width
    if self.maxlines > 0 and #self.activetab.convtext > self.maxlines then
      self.activetab.build_data.textarea.right = self.width - self.window_border_width - self.width_padding - self.scrollbarwidth - 1
    else
      self.activetab.build_data.textarea.right = self.width - self.window_border_width - self.width_padding
    end
  else
    local maxwidth = self.activetab.maxwidth
    if self.showtabline and self.activetab.maxwidthwithtabline then
      maxwidth = math.max(self.activetab.maxwidth, self.activetab.maxwidthwithtabline)
    end
    self.activetab.build_data.actualwindowwidth =  maxwidth + self.width_padding + self.window_border_width
    self.activetab.build_data.textarea.right = maxwidth + self.width_padding
    self.activetab.build_data.textarea.left = 0 + self.window_border_width
    if self.maxlines > 0 and #self.activetab.convtext > self.maxlines then
      self.activetab.build_data.actualwindowwidth = self.activetab.build_data.actualwindowwidth + self.scrollbarwidth + 1
    end
  end


  self.activetab.build_data.textstart = self.window_border_width + self.width_padding
  self.activetab.build_data.textend = self.activetab.build_data.actualwindowwidth - self.window_border_width - self.width_padding

  -- build initial window here and justify lines
  linenum = 0
  local top = self.window_border_width

  if self.titlebar then
    linenum = linenum + 1
    self.activetab.build_data[linenum] = self:justify_line(self.activetab.titlebarconv, top, linenum, 'titlebarline')
    top = self.activetab.build_data[linenum].linebottom
  end

  if self:counttabs() > 1  and self.showtabline then
    linenum = linenum + 1
    self.activetab.build_data[linenum] = self:justify_line(self.activetab.tabbarlineconv, top, linenum, 'titlebarline')
    top = self.activetab.build_data[linenum].linebottom
  end

  for i,v in ipairs(self.activetab.convheader) do
    linenum = linenum + 1
    if i == 1 then
      top = top + 1
      self.activetab.build_data.actual_header_start_line = linenum
      self.activetab.build_data.actual_header_end_line = linenum + #self.activetab.convheader - 1
    end
    self.activetab.build_data[linenum] = self:justify_line(v, top, linenum, 'headerline')
    top = self.activetab.build_data[linenum].linebottom
  end

  local lastlinebeforetext = linenum

  for i,v in ipairs(self.activetab.convtext) do
    linenum = linenum + 1
    if i == 1 then
      if linenum ~= 1 then
        top = top + 1
      end
      self.activetab.build_data.textstartline = linenum
      --self.activetab.build_data.textendline = linenum + #self.activetab.convtext - 1
    end
    local tline = self:justify_line(v, top, linenum, '', self.activetab.build_data.textarea.left, self.activetab.build_data.textarea.right)
    self.activetab.build_data[linenum] = tline
    top = self.activetab.build_data[linenum].linebottom
  end

  if self.height > 0 then
    self.activetab.build_data.actualwindowheight = self.height
  else
    if self.maxlines > 0 and #self.activetab.convtext > self.maxlines then
      top = (self.activetab.build_data[lastlinebeforetext].linebottom +
             (self.maxlines * (self.fonts[self.default_font_id].height + 1)))
      self.activetab.build_data.drawscrollbar = true
    end
    self.activetab.build_data.actualwindowheight = top + self.height_padding + self.window_border_width
  end

  -- figure this out somehow
  self.activetab.build_data.textarea.top = self.activetab.build_data[self.activetab.build_data.textstartline].linetop - 1
  self.activetab.build_data.textarea.bottom = top + 1
  timer_end('miniwin:pre_create_window_internal')
end

function Miniwin:removetextareahotspots()
  for i,v in ipairs(self.textareahotspots) do
    WindowDeleteHotspot(self.winid, v)
    WindowScrollwheelHandler(self.winid, v, "")
  end
  self.textareahotspots = {}
end

function Miniwin:drawtext(tabname)
  self:removetextareahotspots()

  WindowRectOp(self.winid, 2, self.activetab.build_data.textarea.left, self.activetab.build_data.textarea.top + 1,
                           self.activetab.build_data.textarea.right, self.activetab.build_data.textarea.bottom,
               self:get_colour('bg_colour'))

  -- find top
  local linenum = self.activetab.build_data.textstartline - 1
  local top = self.activetab.build_data.textarea.top + 1
  for i=self.activetab.startline,#self.activetab.convtext do
    -- adjust the line then display it
    -- eventually check against bottom of textarea and stop then, don't count lines
    linenum = linenum + 1
    self.activetab.build_data[linenum] = self:justify_line(self.activetab.convtext[i], top, linenum, '', self.activetab.build_data.textarea.left, self.activetab.build_data.textarea.right)
    if self.activetab.build_data[linenum].linebottom > self.activetab.build_data.textarea.bottom then
      break
    end
    top = self.activetab.build_data[linenum].linebottom
    self:displayline(self.activetab.build_data[linenum]) -- pass in top and return top in displayline
  end
  if self.activetab.build_data.textarea.left and self.activetab.build_data.textarea.top and
    self.activetab.build_data.textarea.right and self.activetab.build_data.textarea.bottom then
    self:addhotspot("ztextarea", self.activetab.build_data.textarea.left, self.activetab.build_data.textarea.top,
                              self.activetab.build_data.textarea.right, self.activetab.build_data.textarea.bottom,
                              empty, empty, empty, empty, empty, "", 0)
    self:addscrollwheelhandler("ztextarea", self.wheelmove)
  end
  self:drawshuttle()
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
  local wfunction = WindowText
  if lengthonly then
    wfunction = WindowTextWidth
  end

  if Text:match ("@") then
    local x = Left  -- current x position
    local need_caps = Capitalize

    Text = Text:gsub ("@%-", "~") -- fix tildes
    Text = Text:gsub ("@@", "\0") -- change @@ to 0x00
    Text = Text:gsub ("@x([^%d])","%1") -- strip invalid xterm codes
    Text = Text:gsub ("@[^xcmyrgbwCMYRGBWD]", "")  -- rip out hidden garbage

    -- make sure we start with @ or gsub doesn't work properly
    if Text:sub (1, 1) ~= "@" then
      Text =  DEFAULT_TEXTCOLOUR .. Text
    end -- if

    for colour, text in Text:gmatch ("@(%a)([^@]+)") do
      local text = text:gsub ("%z", "@") -- put any @ characters back

      if colour == "x" then -- xterm 256 colors
        code,text = text:match("(%d%d?%d?)(.*)")
        colour = colour..code
      end

      if need_caps then
        local count
        text, count = text:gsub ("%a", string.upper, 1)
        need_caps = count == 0 -- if not done, still need to capitalize yet
      end -- if

      if #text > 0 then
        x = x + wfunction (self.winid, font_id, text, x, Top, Right, Bottom,
                               atletter_to_color_value[colour] or self.text_colour)
      end -- some text to display

    end -- for each colour run

    return x
  end -- if

  if Capitalize then
    Text = Text:gsub ("%a", string.upper, 1)
  end -- if leading caps wanted

  return wfunction (self.winid, font_id, Text, Left, Top, Right, Bottom,
                    self.text_colour)

end -- colourtext

-- display a single line that has been converted and adjusted
function Miniwin:displayline (styles, redo)
  --self:mdebug('Displaying', styles)
  local def_font_id = self.default_font_id
  local def_colour = self:get_colour("text_colour")
  local def_bg_colour = self:get_colour("bg_colour")

  if redo then
    WindowRectOp (self.winid, 2, styles.linestart, styles.linetop, styles.lineend, styles.linebottom, def_bg_colour )
  end
  if not self.shaded and styles.linebottom > (WindowInfo(self.winid, 4) - self.window_border_width - self.height_padding) then
    styles.bottom = WindowInfo(self.winid, 4) - self.window_border_width - self.height_padding
  end

  if styles.backcolour then
    WindowRectOp (self.winid, 2, styles.linestart, styles.linetop, styles.lineend, styles.linebottom, self:get_colour(styles.backcolour) )
  end
  if styles.gradient then
    if styles.colour1 == styles.colour2 then
      WindowRectOp (self.winid, 2, styles.linestart, styles.linetop, styles.lineend, styles.linebottom, self:get_colour(styles.colour1) )
    else
      WindowGradient (self.winid, styles.linestart, styles.linetop, styles.lineend, styles.linebottom, self:get_colour(styles.colour1), self:get_colour(styles.colour2), 2)
    end
  end
  for i,v in ipairs (styles.text) do

    if v.backcolour and not (v.backcolour == 'bg_colour') then
      -- draw background rectangle
      local bcolour = self:get_colour(v.backcolour, def_bg_colour)
      if v.fillall then
        WindowRectOp (self.winid, 2, v.textstart, styles.linetop, v.textstart + v.stylelen, styles.linebottom, bcolour)
      else
        WindowRectOp (self.winid, 2, v.textstart, styles.celltop, v.textstart + v.stylelen, styles.cellbottom, bcolour)
      end
    end
    if v.image and v.image.name then
      print('displayline: Got Image')
    elseif v.circleOp and v.circleOp.height then
      print('displayline: Got CircleOp')
    else
      if v.nocolourconvert then
        local tcolour = self:get_colour(v.textcolour or self.text_colour)
        stylelen = WindowText (self.winid, v.font_id, v.text,
                    v.textstart, v.texttop, 0, 0, tcolour)
      elseif v.textcolour ~= nil then
        local tcolour = self:get_colour(v.textcolour)
        stylelen = 0
        if v.text then
          stylelen = WindowText (self.winid, v.font_id, strip_colours(v.text),
                    v.textstart, v.texttop, 0, 0, tcolour)
        end
      else
        stylelen = self:colourtext(v.font_id, v.text, v.textstart, v.texttop, 0, 0)
      end
    end
    local tborderwidth = v.borderwidth or 1
    local tborderstyle = v.borderstyle or 0
    if v.cellborder then
       if tborderstyle == 0 then
         tborderstyle = 1
       end
         WindowRectOp (self.winid, tborderstyle, v.textstart, styles.celltop, v.textend, styles.cellbottom,
                          self:get_colour(v.bordercolour), self:get_colour(v.bordercolour2))
    else

      if v.topborder then
          WindowLine (self.winid, v.textstart, styles.celltop, v.textend, styles.celltop, self:get_colour (v.bordercolour), tborderstyle, tborderwidth)
      end
      if v.bottomborder then
          WindowLine (self.winid, v.textstart, styles.cellbottom, v.textend, styles.cellbottom, self:get_colour (v.bordercolour), tborderstyle, tborderwidth)
      end
      if v.leftborder then
          WindowLine (self.winid, v.textstart, styles.celltop, v.textstart, styles.cellbottom, self:get_colour (v.bordercolour), tborderstyle, tborderwidth)
      end
      if v.rightborder then
          WindowLine (self.winid, v.textend - 1, styles.celltop, v.textend - 1, styles.cellbottom, self:get_colour (v.bordercolour), tborderstyle, tborderwidth)
      end
    end
    if v.mousedown ~= nil or
       v.cancelmousedown ~= nil or
       v.mouseup ~= nil or
       v.mouseover ~= nil or
       v.cancelmouseover ~= nil then
      self:buildhotspot(v, v.textstart, styles.celltop, v.textend, styles.cellbottom)
    end
  end -- for each style run

  local tbordercolour = styles.bordercolour
  local tborderwidth = styles.borderwidth or 1
  local tborderstyle = styles.borderstyle or 0
   if styles.lineborder then
       if tborderstyle == 0 then
         tborderstyle = 1
       end
         WindowRectOp (self.winid, tborderstyle, self.window_border_width, styles.linetop, styles.lineend, styles.linebottom,
                self:get_colour(styles.bordercolour), self:get_colour(styles.bordercolour2))
   else

    if styles.topborder then
        WindowLine (self.winid, styles.linestart, styles.linetop, styles.lineend, styles.linetop,
                                             self:get_colour (tbordercolour), tborderstyle, tborderwidth)
    end
    if styles.bottomborder then
        WindowLine (self.winid, styles.linestart, styles.linebottom, styles.lineend, styles.linebottom,
                                             self:get_colour (tbordercolour), tborderstyle, tborderwidth)
    end
    if styles.leftborder then
        WindowLine (self.winid, styles.linestart, styles.linetop, styles.linestart, styles.linebottom, self:get_colour (tbordercolour), tborderstyle, tborderwidth)
    end
    if styles.rightborder then
        WindowLine (self.winid, styles.lineend - 1, styles.linetop, styles.lineend - 1, styles.linebottom, self:get_colour (tbordercolour), tborderstyle, tborderwidth)
    end
  end

--  return start, top, left, bottom

end -- displayline


function Miniwin:create_window(height, width, x, y)
  local height = height or self.activetab.build_data.actualwindowheight
  local width = width or self.activetab.build_data.actualwindowwidth

  local tx = x or self.x
  local ty = y or self.y

  if WindowInfo(self.winid, 1) ~= nil then
    --print('window exists, resizing and repositioning')
    WindowResize(self.winid, width, height, self:get_colour("bg_colour"))
    if tx >= 0 and ty >= 0 then
      WindowPosition(self.winid, tx, ty, 0, 2)
    else
      WindowPosition(self.winid, 0, 0, self.windowpos, 0)
    end
    WindowRectOp(self.winid, 2, 0, 0, -1, -1, self:get_colour("bg_colour"))
  else
    --print('window does not exist, creating')
    -- recreate the window the correct size
    if tx >= 0 and ty >= 0 then
      check (WindowCreate (self.winid,
                  tx, ty,   -- left, top (auto-positions)
                  width,     -- width
                  height,  -- height
                  0,
                  2,  -- flags
                  self:get_colour("bg_colour")) )
    else
      check (WindowCreate (self.winid,
                  0, 0,   -- left, top (auto-positions)
                  width,     -- width
                  height,  -- height
                  self.windowpos,
                  0,  -- flags
                  self:get_colour("bg_colour")) )
    end
    if IsPluginInstalled("462b665ecb569efbf261422f") and self.dontuseaardz == false then
      --print(self.cname, 'registering window in create_window')
      CallPlugin("462b665ecb569efbf261422f", "registerMiniwindow", self.winid)
    end
  end

  self.dragscrolling = false
  WindowDeleteAllHotspots (self.winid)

  self.hyperlink_functions['mousedown'] = {}
  self.hyperlink_functions['cancelmousedown'] = {}
  self.hyperlink_functions['mouseup'] = {}
  self.hyperlink_functions['mouseover'] = {}
  self.hyperlink_functions['cancelmouseover'] = {}
  self.hyperlink_functions['releasecallback'] = {}
  self.hyperlink_functions['movecallback'] = {}
  self.hyperlink_functions['wheelcallback'] = {}

  if not self.shaded or self.shade_with_header then
    local htop = 0
    local hbottom = 0
    if self.activetab.build_data.actual_header_start_line ~= nil and self.activetab.build_data.actual_header_end_line ~= nil then
      local htop = self.activetab.build_data[self.activetab.build_data.actual_header_start_line].linetop + 1
      local hbottom = self.activetab.build_data[self.activetab.build_data.actual_header_end_line + 1].linetop - 1

      -- header colour
      check (WindowRectOp (self.winid, 2, 3, htop + 1, -3, hbottom, self:get_colour("header_bg_colour"))) -- self:get_colour("header_bg_colour")))
      --check (WindowRectOp (self.winid, 1, 2, htop + 1, -2, hbottom, self:get_colour("black"))) -- self:get_colour("header_bg_colour")))

    end

  end

  if self.shaded or self.titlebar then
    if self.titlebar then
      local top = self.activetab.build_data[1].linetop
      local bottom = self.activetab.build_data[1].linebottom

      -- add windowdraghandler
      if not self.lockwindow then
        self:addhotspot('drag_hotspot', self.window_border_width, top, width - self.window_border_width, bottom,
                      empty,
                      empty,
                      empty,
                      empty,
                      empty,
                      'Click and Drag to move window', 1)
        self:adddraghandler('drag_hotspot', self.dragmove, self.dragrelease, 0)
      end
    end
  end

  --check (WindowRectOp (self.winid, 2, 0, 0, 0, 0, 0x575757))

end

-- do stuff after the text has been drawn
function Miniwin:post_create_window_internal()
  if not self.titlebar then
    self:addhotspot('mousemenu', self.window_border_width, self.window_border_width, self.window_border_width + 5, self.window_border_width + 5,
                   nil, nil, function (win, flags, hotspotid)
                        win:menuclick(flags)
                      end,
                   nil, nil, 'Show Menu')
  end

  if self.maxlines > 0 and #self.activetab.convtext > self.maxlines then
    if self.activetab.build_data.textarea.left and self.activetab.build_data.textarea.top and
      self.activetab.build_data.textarea.right and self.activetab.build_data.textarea.bottom then
      self:addhotspot("ztextarea", self.activetab.build_data.textarea.left, self.activetab.build_data.textarea.top,
                                self.activetab.build_data.textarea.right, self.activetab.build_data.textarea.bottom,
                                empty, empty, empty, empty, empty, "", 0)
      self:addscrollwheelhandler("ztextarea", self.wheelmove)
    end
  end

  if self.activetab.build_data.drawscrollbar then
    self.activetab.build_data.upbutton = {}
    self.activetab.build_data.upbutton.top = self.activetab.build_data.textarea.top
    self.activetab.build_data.upbutton.bottom = self.activetab.build_data.upbutton.top + self.scrollbarwidth
    self.activetab.build_data.upbutton.left = self.activetab.build_data.actualwindowwidth - self.scrollbarwidth - self.window_border_width
    self.activetab.build_data.upbutton.right = self.activetab.build_data.actualwindowwidth - self.window_border_width

    self.activetab.build_data.downbutton = {}
    self.activetab.build_data.downbutton.bottom = self.activetab.build_data.textarea.bottom
    self.activetab.build_data.downbutton.top = self.activetab.build_data.downbutton.bottom - self.scrollbarwidth
    self.activetab.build_data.downbutton.left = self.activetab.build_data.actualwindowwidth - self.scrollbarwidth - self.window_border_width
    self.activetab.build_data.downbutton.right = self.activetab.build_data.actualwindowwidth - self.window_border_width

    self.activetab.build_data.shuttle = {}


    local downbutton = self.activetab.build_data.downbutton
    local upbutton = self.activetab.build_data.upbutton
    self:drawshuttle()

    WindowRectOp(self.winid, 5, upbutton.left, upbutton.top, upbutton.right, upbutton.bottom, 5, 15 + 0x800) -- top scroll button
    WindowRectOp(self.winid, 5, downbutton.left, downbutton.top, downbutton.right, downbutton.bottom, 5,  15 + 0x800) -- bottom scroll button

    -- draw triangle in up button
    local points = string.format ("%i,%i,%i,%i,%i,%i", upbutton.left + 3, upbutton.top + 9,
	                      upbutton.left + 7, upbutton.top + 5, upbutton.left + 11, upbutton.top + 9)
    WindowPolygon (self.winid, points,
        ColourNameToRGB("black"), 0, 1,   -- pen (solid, width 1)
        ColourNameToRGB("black"), 0, --brush (solid)
        true, --close
        false)  --alt fill

    -- draw triangle in down button
    local points = string.format ("%i,%i,%i,%i,%i,%i", downbutton.left + 3, downbutton.bottom - 11,
	                   downbutton.left + 7, downbutton.bottom - 7, downbutton.left + 11,
			   downbutton.bottom - 11)
    WindowPolygon (self.winid, points,
        ColourNameToRGB("black"), 0, 1,   -- pen (solid, width 1)
        ColourNameToRGB("black"), 0, --brush (solid)
        true, --close
        false) --alt fill


    local tfunction = function(win, flags, hotspotid)
                        win.keepscrolling = false
                      end

    -- scroll bar up/down buttons
    self:addhotspot('upbutton', upbutton.left, upbutton.top, upbutton.right, upbutton.bottom,
                     tfunction,
                     tfunction,
                     function(win, flags, hotspotid)
                        win:scrollup(1, hotspotid)
                     end,
                     tfunction,
                     tfunction,
                     'Scroll Up')

    self:addhotspot('downbutton', downbutton.left, downbutton.top, downbutton.right, downbutton.bottom,
                     tfunction,
                     tfunction,
                     function(win, flags, hotspotid)
                        win:scrolldown(1, hotspotid)
                     end,
                     tfunction,
                     tfunction,
                     'Scroll Down')

  end

  self:createwindowborder()

end

function Miniwin:buildresizewindow(x, y, width, height)
  WindowCreate(self.resizewinid, x, y, width, height, 0, 6, self:get_colour('bg_colour'))
  WindowRectOp(self.resizewinid, 2, 0, 0, 0, 0, self:get_colour('bg_colour'))
  WindowRectOp(self.resizewinid, 1, 0, 0, 0, 0, ColourNameToRGB("white"))
  WindowShow(self.resizewinid, 1)
end

function Miniwin:destroymovewindow()
  WindowDelete(self.resizewinid)
end

function Miniwin:resizemousedown()
  self:buildresizewindow(WindowInfo(self.winid, 10), WindowInfo(self.winid, 11), WindowInfo(self.winid, 3), WindowInfo(self.winid, 4) )
  self.mousestartx = WindowInfo (self.winid, 17)
  self.mousestarty = WindowInfo (self.winid, 18)
end

function Miniwin:resizemovecallback(flags, hotspot_id)
  local mousex = WindowInfo (self.winid, 17) -- where mouse is relative to output window (X)
  local mousey = WindowInfo (self.winid, 18) -- where mouse is relative to output window (Y)
  self.newwidth = WindowInfo(self.winid, 3)
  self.newheight = WindowInfo(self.winid, 4)
  self.newx = WindowInfo(self.winid, 10)
  self.newy = WindowInfo(self.winid, 11)
  if hotspot_id:find("right") then
    self.newwidth = mousex - WindowInfo(self.winid, 10)
    if self.newwidth < 30 then
      self.newwidth = 30
    end
  end
  if hotspot_id:find("bottom") then
    self.newheight = mousey - WindowInfo(self.winid, 11)
    if self.newheight < 30 then
      self.newheight = 30
    end
  end
  if hotspot_id:find("left") then
    self.newwidth = WindowInfo(self.winid, 12) - mousex
    self.newx = mousex
    if self.newx - self.mousestartx > WindowInfo(self.winid, 3) - 30 then
      self.newx = WindowInfo(self.winid, 3) - 30 + self.mousestartx
    end
    if self.newwidth < 30 then
      self.newwidth = 30
    end
  end
  if hotspot_id:find("top") then
    self.newheight = WindowInfo(self.winid, 13) - mousey
    self.newy = mousey
    if self.newy - self.mousestarty > WindowInfo(self.winid, 4) - 30 then
      self.newy = self.mousestarty + WindowInfo(self.winid, 4) - 30
    end
    if self.newheight < 30 then
      self.newheight = 30
    end
  end
  self:buildresizewindow(self.newx, self.newy, self.newwidth, self.newheight)
end

function Miniwin:resizereleasecallback(flags, hotspot_id)
  self:destroymovewindow()
  self.width = self.newwidth
  self.height = self.newheight
  self.newwidth = -1
  self.newheight = -1
  self.x = self.newx
  self.y = self.newy
  self.newx = -1
  self.newy = -1
  SaveState()
  WindowResize(self.winid, self.width, self.height, self:get_colour('bg_colour'))
  self:resettabs()
end

function Miniwin:createwindowborder()
  -- DrawEdge rectangle
  for i=1,self.window_border_width do
    local num = i - 1
    check (WindowRectOp (self.winid, 1, num, num, 0 - num, 0 - num, self:get_colour('window_border_colour')))
  end
  --check (WindowRectOp (self.winid, 1, 1, 1, -1, -1, self:get_colour('window_border_colour')))

  if not self.shaded and (self.resizable and self.showresize) then
    local cornerwidth = 10

    -- add 8 corner hotspots
    -- add 2 top left corner hotspots
    self:addhotspot('lefttopresize', 0, 0, cornerwidth, self.window_border_width,
                      empty,
                      empty,
                      function(win, flags, hotspotid)
                         self:resizemousedown(flags, hotspotid)
                      end,
                      empty,
                      empty,
                      'Resize Window',
                      6)
    self:adddraghandler("lefttopresize", self.resizemovecallback, self.resizereleasecallback, 0)
    self:addhotspot('topleftresize', 0, self.window_border_width, self.window_border_width, cornerwidth,
                      empty,
                      empty,
                      function(win, flags, hotspotid)
                         self:resizemousedown(flags, hotspotid)
                      end,
                      empty,
                      empty,
                      'Resize Window',
                      6)
    self:adddraghandler("topleftresize", self.resizemovecallback, self.resizereleasecallback, 0)

    -- add 2 bottom left corner hotspots
    self:addhotspot('leftbottomresize', 0, self.activetab.build_data.actualwindowheight - self.window_border_width,
                      cornerwidth, self.activetab.build_data.actualwindowheight,
                      empty,
                      empty,
                      function(win, flags, hotspotid)
                         self:resizemousedown(flags, hotspotid)
                      end,
                      empty,
                      empty,
                      'Resize Window',
                      7)
    self:adddraghandler("leftbottomresize", self.resizemovecallback, self.resizereleasecallback, 0)
    self:addhotspot('bottomleftresize', 0, self.activetab.build_data.actualwindowheight - self.window_border_width - cornerwidth,
                      self.window_border_width, self.activetab.build_data.actualwindowheight - self.window_border_width,
                      empty,
                      empty,
                      function(win, flags, hotspotid)
                         self:resizemousedown(flags, hotspotid)
                      end,
                      empty,
                      empty,
                      'Resize Window',
                      7)
    self:adddraghandler("bottomleftresize", self.resizemovecallback, self.resizereleasecallback, 0)
    -- add 2 top right corner hotspots
    self:addhotspot('righttopresize', self.activetab.build_data.actualwindowwidth - cornerwidth, 0,
                      self.activetab.build_data.actualwindowwidth, self.window_border_width,
                      empty,
                      empty,
                      function(win, flags, hotspotid)
                         self:resizemousedown(flags, hotspotid)
                      end,
                      empty,
                      empty,
                      'Resize Window',
                      7)
    self:adddraghandler("righttopresize", self.resizemovecallback, self.resizereleasecallback, 0)
    self:addhotspot('toprightresize', self.activetab.build_data.actualwindowwidth - self.window_border_width, 0 + self.window_border_width,
                      self.activetab.build_data.actualwindowwidth, 0 + self.window_border_width + cornerwidth,
                      empty,
                      empty,
                      function(win, flags, hotspotid)
                         self:resizemousedown(flags, hotspotid)
                      end,
                      empty,
                      empty,
                      'Resize Window',
                      7)
    self:adddraghandler("toprightresize", self.resizemovecallback, self.resizereleasecallback, 0)
    -- add 2 bottom right corner hotspots
    self:addhotspot('rightbottomresize', self.activetab.build_data.actualwindowwidth - cornerwidth, self.activetab.build_data.actualwindowheight - self.window_border_width,
                      self.activetab.build_data.actualwindowwidth, self.activetab.build_data.actualwindowheight,
                      empty,
                      empty,
                      function(win, flags, hotspotid)
                         self:resizemousedown(flags, hotspotid)
                      end,
                      empty,
                      empty,
                      'Resize Window',
                      6)
    self:adddraghandler("rightbottomresize", self.resizemovecallback, self.resizereleasecallback, 0)

    self:addhotspot('bottomrightresize', self.activetab.build_data.actualwindowwidth - self.window_border_width,  self.activetab.build_data.actualwindowheight - self.window_border_width - cornerwidth,
                      self.activetab.build_data.actualwindowwidth, self.activetab.build_data.actualwindowheight,
                      empty,
                      empty,
                      function(win, flags, hotspotid)
                         self:resizemousedown(flags, hotspotid)
                      end,
                      empty,
                      empty,
                      'Resize Window',
                      6)
    self:adddraghandler("bottomrightresize", self.resizemovecallback, self.resizereleasecallback, 0)
    -- add 4 border hotspots
    -- create top border hotspot
    self:addhotspot('topresize', cornerwidth, 0, self.activetab.build_data.actualwindowwidth - cornerwidth, self.window_border_width,
                      empty,
                      empty,
                      function(win, flags, hotspotid)
                         self:resizemousedown(flags, hotspotid)
                      end,
                      empty,
                      empty,
                      'Resize Window',
                      9)
    self:adddraghandler("topresize", self.resizemovecallback, self.resizereleasecallback, 0)

    -- create bottom border hotspot
    self:addhotspot('bottomresize', cornerwidth, self.activetab.build_data.actualwindowheight - self.window_border_width, self.activetab.build_data.actualwindowwidth - cornerwidth, self.activetab.build_data.actualwindowheight,
                      empty,
                      empty,
                      function(win, flags, hotspotid)
                         self:resizemousedown(flags, hotspotid)
                      end,
                      empty,
                      empty,
                      'Resize Window',
                      9)
    self:adddraghandler("bottomresize", self.resizemovecallback, self.resizereleasecallback, 0)
    -- create left border hotspot
    self:addhotspot('leftresize', 0, 0 + cornerwidth, self.window_border_width, self.activetab.build_data.actualwindowheight - cornerwidth,
                      empty,
                      empty,
                      function(win, flags, hotspotid)
                         self:resizemousedown(flags, hotspotid)
                      end,
                      empty,
                      empty,
                      'Resize Window',
                      8)
    self:adddraghandler("leftresize", self.resizemovecallback, self.resizereleasecallback, 0)
    -- create right border hotspot
    self:addhotspot('rightresize', self.activetab.build_data.actualwindowwidth - self.window_border_width, 0 + cornerwidth, self.activetab.build_data.actualwindowwidth, self.activetab.build_data.actualwindowheight - cornerwidth,
                      empty,
                      empty,
                      function(win, flags, hotspotid)
                         self:resizemousedown(flags, hotspotid)
                      end,
                      empty,
                      empty,
                      'Resize Window',
                      8)
    self:adddraghandler("rightresize", self.resizemovecallback, self.resizereleasecallback, 0)
  end
end

function Miniwin:drawshuttle()
    local downbutton = self.activetab.build_data.downbutton
    local upbutton = self.activetab.build_data.upbutton
    if not upbutton or not downbutton then
      print('error on upbutton or downbutton in drawshuttle')
      return
    end
    local shuttle = self.activetab.build_data.shuttle
    local sliderheight = downbutton.top - upbutton.bottom
    shuttle.top = math.ceil(upbutton.bottom + ((sliderheight / #self.activetab.convtext) * (self.activetab.startline - 1)))
    shuttle.left = upbutton.left
    shuttle.right = upbutton.right
    local percentage = self.maxlines/#self.activetab.convtext
    local scrollbarheight = downbutton.top - upbutton.bottom
    shuttle.height = math.ceil(scrollbarheight * percentage)
    shuttle.bottom = shuttle.top + shuttle.height

    WindowRectOp(self.winid, 2, upbutton.left, upbutton.bottom, downbutton.right, downbutton.top, ColourNameToRGB ("#E8E8E8")) -- scroll bar background
    WindowRectOp(self.winid, 1, upbutton.left + 1, upbutton.bottom + 1, downbutton.right - 1, downbutton.top - 1, ColourNameToRGB ("black")) -- scroll bar background inset rectangle

    WindowRectOp(self.winid, 5, shuttle.left, shuttle.top, shuttle.right, shuttle.bottom, 5, 15 + 0x800)
    if not self.dragscrolling then
          local tfunction = function(win, flags, hotspotid)
                        win.keepscrolling = false
                      end

--(id, left, top, right, bottom, mouseover, cancelmouseover, mousedown,
--                   cancelmousedown, mouseup, hint, cursor)
      self:addhotspot("abovescroller", shuttle.left, upbutton.bottom, shuttle.right, shuttle.top,
                      nil,
                      nil,
                      nil,
                      nil,
                      function(win, flags, hotspotid)
                         self:abovescrollermouseup(flags, hotspotid)
                      end)

      self:addhotspot("scroller", shuttle.left, shuttle.top, shuttle.right, shuttle.bottom,
                      tfunction,
                      tfunction,
                      function(win, flags, hotspotid)
                         self:scrollermousedown(flags, hotspotid)
                      end,
                      tfunction,
                      tfunction)
      self:adddraghandler("scroller", self.scrollermovecallback, self.scrollerreleasecallback, 0)

      self:addhotspot("belowscroller", shuttle.left, shuttle.bottom, shuttle.right, downbutton.top,
                      nil,
                      nil,
                      nil,
                      nil,
                      function(win, flags, hotspotid)
                         self:belowscrollermouseup(flags, hotspotid)
                      end)

    end
end

-- draw the window
function Miniwin:drawwin()
--  timer_start('miniwin:drawwin')
  if self.activetab == nil then
    return
  end
  if self.activetab.build_data == nil or self.activetab.build_data[1] == nil then
    self:pre_create_window_internal()
  else
    self:redrawtabline()
  end
  local endline = #self.activetab.build_data
  local window_height = 0
  if self.shaded and self.titlebar then
    local tx = self.x or WindowInfo(self.winid, 10)
    local ty = self.y or WindowInfo(self.winid, 11)

    -- create the window shaded
    endline = 1
    window_height = self.activetab.build_data[1].linebottom + self.window_border_width
    if self.shade_with_header and self.activetab.build_data.actual_header_start_line ~= nil and self.activetab.build_data.actual_header_end_line ~= nil then
      window_height = self.activetab.build_data[self.activetab.build_data.actual_header_end_line].linebottom + self.window_border_width
      endline = self.activetab.build_data.actual_header_end_line
    end
    self:create_window(window_height, nil, tx, ty)
    -- figure out last line to draw
    -- different for shade_with_header compared to just shaded
  else
    self:create_window()
    -- figure out last line to draw
  end
  local textbottom = self.activetab.build_data.textarea.bottom
  for i=1,endline do
    if self.activetab.build_data[i].linebottom > textbottom then
      break
    end
    top = self:displayline (self.activetab.build_data[i], top)
  end -- for
  self:post_create_window_internal()
  if self.activetab.startline ~= 1 then
    if not self:setstartline(self.activetab.startline) then
      self:drawtext(self.activetab)
    end
  end
--  timer_end('miniwin:drawwin')
end

function Miniwin:scrollermousedown(flags, hotspot_id)
 self.clickdelta = WindowInfo (self.winid, 15)
 self.startlineatdrag = self.activetab.startline
 self.dragscrolling = true
end

function Miniwin:scrollerreleasecallback(flags, hotspot_id)
  self.dragscrolling = false
  self:redraw(true)
end

function Miniwin:scrollermovecallback(flags, hotspot_id)
  local mouselocation =  WindowInfo(self.winid, 18) - WindowInfo(self.winid, 11)
  local mousediff = mouselocation - self.clickdelta
  local sliderheight = self.activetab.build_data.downbutton.top - self.activetab.build_data.upbutton.bottom
  local pixperline = math.ceil(sliderheight / #self.activetab.convtext - 1)
  local linediff = math.ceil(mousediff / pixperline)
  self:setstartline(self.startlineatdrag + linediff)

end

function Miniwin:abovescrollermouseup(flags, hotspot_id)
  local mouselocation = WindowInfo(self.winid, 15)
  local slidertop = self.activetab.build_data.upbutton.bottom
  local difference = mouselocation - slidertop
  local sliderheight = self.activetab.build_data.downbutton.top - self.activetab.build_data.upbutton.bottom
  local pixperline = math.ceil(sliderheight / #self.activetab.convtext)
  local linenum = math.ceil(difference / pixperline)
  self:setstartline(linenum)

end

function Miniwin:belowscrollermouseup(flags, hotspot_id)
  local mouselocation = WindowInfo(self.winid, 15)
  local slidertop = self.activetab.build_data.upbutton.bottom
  local difference = mouselocation - slidertop
  local sliderheight = self.activetab.build_data.downbutton.top - self.activetab.build_data.upbutton.bottom
  local pixperline = math.ceil(sliderheight / (#self.activetab.convtext))
  local linenum = math.ceil(difference / pixperline)
  self:setstartline(linenum)

end

function Miniwin:scrollbar(calledBy)
    wait.make (function()
        while self.keepscrolling == true do
            if calledBy == "upbutton" then
                self:scrollup(1)
            elseif calledBy == "downbutton" then
                self:scrolldown(1)
            end
            wait.time(0.1)
        end
    end)
end

function Miniwin:scrollup(numlines, hotspot_id)
  local numlines = numlines or 1
  local hotspot_id = hotspot_id or None
  if self.maxlines > #self.activetab.convtext then
    return
  end
  if self.activetab.startline > numlines then
    if hotspot_id == "upbutton" then
      self.keepscrolling = true
      self:scrollbar(hotspot_id)
    else
      self:setstartline(self.activetab.startline - numlines)
    end
  else
    self.keepscrolling = false
  end
end

function Miniwin:scrolldown(numlines, hotspot_id)
  -- scrolled down
  local numlines = numlines or 1
  local hotspot_id = hotspot_id or None
  if self.maxlines > #self.activetab.convtext then
    return
  end
  if self.activetab.startline + self.maxlines + numlines > #self.activetab.convtext then
    self:setstartline(self.activetab.startline + numlines)
  elseif self.activetab.startline >= 1 then
    if hotspot_id == "downbutton" then
      self.keepscrolling = true
      self:scrollbar(hotspot_id)
    else
      self:setstartline(self.activetab.startline + numlines)
    end
  else
    self.keepscrolling = false
  end
end

function Miniwin:setstartline(line)
  if self.activetab.startline == line or line <= 0 or line > #self.activetab.convtext then
    return false
  end
  if line + self.maxlines > #self.activetab.convtext + 1 then
    if self.activetab.startline ~= #self.activetab.convtext - self.maxlines then
      line = #self.activetab.convtext - self.maxlines + 1
      self.keepscrolling = false
    else
      return false
    end
  end
  self.activetab.startline = line
  self:redraw(true)
  return true
end

function Miniwin:wheelmove (flags, hotspot_id)
  if bit.band (flags, 0x100) ~= 0 then
    -- wheel scrolled down (towards you)
    self:scrolldown()
  else
    -- wheel scrolled up (away from you)
    self:scrollup()
  end -- if

  return 0
end -- drag_move

-- the function to drag and move the window
function Miniwin:dragmove(flags, hotspot_id)

  -- find where it is now
  local posx, posy = WindowInfo (self.winid, 17),
                     WindowInfo (self.winid, 18)

  self.x = posx - self.startx
  self.y = posy - self.starty
  if self.x < 0 then
    self.x = 0
  end
  if self.y < 0 then
    self.y = 0
  end

  -- move the window to the new location
  WindowPosition(self.winid, self.x, self.y, 0, 2);

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
  local newx, newy = WindowInfo (self.winid, 17), WindowInfo (self.winid, 18)

  -- don't let them drag it out of view
  if newx < 0 then
    newx = 0
  end
  if newy < 0 then
    newy = 0
  end
  if newx > GetInfo (281) or
     newy > GetInfo (280) then
     -- put it back
    if self.x ~= -1 and self.y ~= -1 then
      WindowPosition(self.winid, self.origx, self.origy, 0, 2)
    else
      WindowPosition(self.winid, 0, 0, self.windowpos, 0)
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
    td.pluginid = GetPluginID()
    td.objectid = self.id
    td.name = self.cname
    td.winid = self.winid
    td.text = ttext
    if self.tabcolour then
      td.tabcolour = self.tabcolour
    end
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
      td.pluginid = GetPluginID()
      td.objectid = self.id
      td.name = self.cname
      td.winid = self.winid
      local wins = serialize.save( "windowstuff", td )
      self:broadcast(5001, wins, wins)
    end
  end
end

function Miniwin:OnPluginBroadcast(msg, id, name, text)
  super(self, msg, id, name, text)

  if id == "eee96e233d11e6910f1d9e8e" and msg == -2 then
    if not self.disabled then
      self:tabbroadcast(true)
    end
  elseif id == "eee8dcaf925c1bbb534ef093" and msg == 1002 then
    newset = assert (loadstring ('return ' .. text or ""))()
    if not self.disabled then
      self:onSettingChange(newset)
    end
  elseif (id == "462b665ecb569efbf261422f" and msg==996 and text == "re-register z" and self.dontuseaardz == false) then
    --print(self.cname, 'registering window broadcast')
    CallPlugin("462b665ecb569efbf261422f", "registerMiniwindow", self.winid)
  end
end

function Miniwin:OnPluginDisable()
  super(self)
  WindowDelete(self.winid)
end

-- empty function for hyperlinks
function empty(flags, hotspot_id)

end

-- create a popup style with another miniwindow
function popup_style(win, text, colour, mousebutton)
  local style = {}
  style.text = text
  style.textcolour = colour
  style.mouseover = function (window, flags, hotspotid)
                      win:show(true)
                    end
  style.cancelmouseover = function (window, flags, hotspotid)
                      if not win.clickshow then
                        win:show(false)
                      end
                    end
  style.mousedown = function (window, flags, hotspotid)
                      if mousebutton then
                        if bit.band(flags, mousebutton) ~= 0 then
                          win.clickshow = not win.clickshow
                        end
                      else
                        win.clickshow = not win.clickshow
                      end
                    end
  return style
end
