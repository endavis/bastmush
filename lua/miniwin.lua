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
--]]

require 'class'
require 'tprint'
require 'verify'
require 'pluginhelper'

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

  -- below are things that can be kept as settings
  self.disabled = tonumber (GetVariable ("disabled"..self.name)) or args.disabled or 0 
  self.header_height = tonumber (GetVariable ("header_height"..self.name)) or args.header_height or 1
  self.header_padding = 2

  self.set_options = {
    bg_colour = {type="colour", help="background colour for this window", default=0x00220E, sortlev=40},
    header_bg_colour = {type="colour", help="header colour for this window", default=0x696969, sortlev=41},
    header_text_colour = {type="colour", help="header text colour for this window", default=0x00FF00, sortlev=41},
    hyperlink_colour = {type="colour", help="hyperlink colour for this window", default=0x00FFFF},
    text_colour = {type="colour", help="text colour for this window", default=0xDCDCDC, sortlev=40},
    font_size = {type="number", help="font_size for this window", low=2, high=30, default=8, sortlev=43},
    font = {type="string", help="change the font for this window", default="Dina", sortlev=43},
    height_padding = {type="number", help="height padding for this window", low=0, high=30, default=5, sortlev=44},
    width_padding = {type="number", help="width padding for this window", low=0, high=30, default=5, sortlev=44},
    windowpos = {type="number", help="position for this window: see http://www.gammon.com.au/scripts/function.php?name=WindowCreate", low=0, high=13, default=6,sortlev=39},
    show_hyperlinks = {type="number", help="show the default hyperlinks", low=0, high=1, default=0},
    footer_bg_colour = {type="colour", help="footer colour for this window", default=0x696969, sortlev=42},
    footer_text_colour = {type="colour", help="footer text colour for this window", default=0x00FF00, sortlev=42},
    width = {type="number", help="width of this window, 0 = auto", low=0, high=100, default=0, sortlev=44},
    height = {type="number", help="height of this window, 0 = auto", low=0, high=140, default=0, sortlev=44},
  }
  
  for i,v in pairs(self.set_options) do
    local tvalue = (GetVariable (i..self.name)) or args[i]
    if tvalue ~= nil then
      tvalue = verify(tvalue, v.type, {low=v.low, high=v.high, silent=true}) 
    end
    self[i] = tvalue or v.default
  end

  self.default_font = nil
  self:getdefaultfont()
  self.skeys = sort_settings(self.set_options)

  self:changefont(self.font, true) 
  
end

function Miniwin:savestate()
  for i,v in pairs(self.set_options) do
    SetVariable(i .. self.name, self[i])
  end
  SetVariable ("disabled"..self.name, self.disabled)  
  SetVariable ("header_height"..self.name, self.header_height)
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


function Miniwin:display()
  self:show(true)
end


function Miniwin:show(flag)
  if self.disabled == 1 then
    WindowShow(self.win, false)
    return
  end
  WindowShow(self.win, flag)
end

function Miniwin:enable()
  self.disabled = 0
  self:show(true)
end

function Miniwin:disable()
  self.disabled = 1
  WindowShow(self.win, false)
end


function Miniwin:mousedown (flags, hotspotid)
  local f = self.hyperlink_functions[hotspotid]
  if f then
    f(self, flags, hotspotid)
  end -- function found
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


function Miniwin:make_hyperlink (text, id, left, top, action, hint)

  local right = left + WindowTextWidth (self.win, self.font_id, text)
  local bottom = top + self.font_height

  WindowAddHotspot(self.win, id,  
                    left, top, right, bottom, 
                   "", -- mouseover
                   "", -- cancelmouseover
                   "mousedown",
                   "", -- cancelmousedown
                   "", -- mouseup
                   hint,                 
                   1, 0)
                   
  local retval = WindowText (self.win, self.font_id, text, left, top, right, bottom, self.hyperlink_colour)
  self.hyperlink_functions [id] = action
      
  return right
            
end -- make_hyperlink

function Miniwin:createwin (text)
  if not next(text) then
    return
  end
  self.text = text
  self:drawwin()
end

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

function Miniwin:Display_Line (line, styles)
  local id = self.font_id
  local colour = self:get_colour("text_colour")
  local bg_colour = self:get_colour("bg_colour")
  local left = self.width_padding
  local top = self:get_top_of_line(line)
  if line <= self.header_height then
    id = self.font_id_bold
    colour = self:get_colour("header_text_colour")
    bg_colour = self:get_colour("header_bg_colour")
  end
  
  if type(styles) == "table" then
    for _, v in ipairs (styles) do
      if v.start then
        if v.start == "mid" then
          local tlength = WindowTextWidth (self.win, self.font_id, v.text)
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
        local tlength = WindowTextWidth (self.win, self.font_id, v.text)  
        WindowRectOp (self.win, 2, left, top, left + tlength, top + self.font_height, bcolour)
      end
      left = left +  WindowText (self.win, id, v.text,
                             left, top, 0, 0, tcolour)
    end -- for each style run    
  else
    WindowText (self.win, id, styles, left, top, 0, 0, colour)        
  end

end -- Display_Line

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
  if self.height == 0 then
     return (#self.text) * self.font_height + (self.height_padding * 2) + self.header_padding
  else
     return self.height * self.font_height + (self.height_padding * 2) + self.header_padding
  end  
end

function Miniwin:drawwin(tshow)
  --print("Got past text check")
  tshow = tshow or true
  if not next(self.text) then
    return
  end
  local height = self:calc_height()
  local width = self:calc_width()
  
  -- recreate the window the correct size
  check (WindowCreate (self.win, 
                 0, 0,   -- left, top (auto-positions)
                 width,     -- width
                 height,  -- height
                 self.windowpos,
                 0,  -- flags
                 self:get_colour("bg_colour")) )
                 
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
    self:make_hyperlink ("?", "bg_colour", width - (2 * self.font_width), self:get_top_of_line(-1), 
                    self.hyperlink_configure_background, "Choose background colour")

    if self.header_height > 0 then 
      self:make_hyperlink ("?", "header_bg_colour", width - (2 * self.font_width), self:get_top_of_line(self.header_height), 
                    self.hyperlink_configure_header, "Choose header background colour")

      self:make_hyperlink ('-', "hidewin", width - (3 * self.font_width), self:get_top_of_line(self.header_height), 
                    self.togglewindow, 'Hide Window')
    else
      self:make_hyperlink ('-', "hidewin", width - (3 * self.font_width), self:get_top_of_line(-1), 
                    self.togglewindow, 'Hide Window')
    end    
  end
  
  if tshow then
    self:show(true)
  end
end


function Miniwin:set(option, value)
  local function changedsetting(toption, tvarstuff, cvalue)
    ColourNote("", "", "")    
    ColourNote(RGBColourToName(var.plugin_colour), "black", GetPluginInfo(GetPluginID (),1) .. " ",
             RGBColourToName(var.plugin_colour), "black", GetPluginInfo(GetPluginID (),19) ,
             "white", "black", " Settings")    
    ColourNote("white", "black", "-----------------------------------------------")  
    if tvarstuff.type == "colour" then
      colourname = RGBColourToName(self:get_colour(cvalue))
      ColourNote("orange", "black", toption .. " set to : ",
             colourname, "black", colourname)    
    else
      colourname = RGBColourToName(var.plugin_colour)
      ColourNote("orange", "black", toption .. " set to : ",
             colourname, "black", cvalue)    
    end
    ColourNote("", "", "")      
  end

  varstuff = self.set_options[option]
  if not varstuff then
    return false
  end
  tvalue = verify(value, varstuff.type, {low=varstuff.low, high=varstuff.high, window=self})
  if tvalue == nil then
    ColourNote("red", "", "That is not a valid value for " .. option)
    return true
  end
  if option == "font" then
    if not self:changefont(tvalue) then
      ColourNote("red", "", "Could not find font " .. tvalue)
      self:drawwin()
      return true
    end
  elseif string.find(option, "font") then
    self[option] = tvalue
    self:changefont(self.font)
  else
    self[option] = tvalue
  end
  self:drawwin()
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
    print_setting_helper(v, value, self.set_options[v].help, self.set_options[v].type)
  end
end


function Miniwin:add_setting(name, setting)
  local tvalue = (GetVariable (name..self.name)) or setting.default
  self[name] = tvalue
  self.set_options[name] = setting
  self.skeys = sort_settings(self.set_options)
end
