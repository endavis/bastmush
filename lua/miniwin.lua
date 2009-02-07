
require 'window'
require 'tprint'

class "Miniwindow"(Window)


function Miniwindow:initialize(args)
  super(args)   -- notice call to superclass's constructor
  self.ishidden = tonumber (GetVariable ("ishidden"..self.name)) or args.ishidden or 0
  self.show_hyperlinks = tonumber (GetVariable ("show_hyperlink"..self.name)) or args.show_hyperlink or 1  
end


function Miniwindow:show(flag)
   if self.disabled == 1 then
     self.winhide:show(false)
     WindowShow(self.win, false)
   elseif self.ishidden == 1 then
     self.winhide:show(true)
     WindowShow(self.win, false)
   else
     self.winhide:show(false)
     WindowShow(self.win, true)
   end
end


function Miniwindow:savestate()
  super()
  SetVariable ("ishidden"..self.name, self.ishidden)
end

function Miniwindow:enable()
  self.disabled = 0
  if not self.winhide then
     self.winhide = Winshow:new{parent=self,name=self.name.."showwin"}
     self.winhide:createwin({" "})
  end
  self:show()
end

function Miniwindow:disable()
  self.disabled = 1
  if not self.winhide then
     self.winhide = Winshow{parent=self,name=self.name.."showwin"}
     self.winhide:createwin({" "})
  end
  self.winhide:show(false)
  WindowShow(self.win, false)
end

function Miniwindow:mousedown (flags, hotspotid)
  if not self.winhide then
     self.winhide = Winshow{parent=self,name=self.name.."showwin"}
     self.winhide:createwin({" "})
  end
  local f = self.hyperlink_functions[hotspotid]
  if f then
    f(self)
  else
    f = self.winhide.hyperlink_functions[hotspotid]
    if f then
      f(self)
    else
      print("could not find hotspot id: "..hotspotid)
    end
  end -- function found
end -- mousedown


function Miniwindow:togglewindow()
  if self.disabled == 1 then
    return
  end
  if not self.winhide then
     self.winhide = Winshow:new{parent=self,name=self.name.."showwin"}
     self.winhide:createwin({" "})
  end
  if self.text == nil then
    self.ishidden = 1
  elseif next(self.text) == nil then
    self.ishidden = 1
  elseif self.ishidden == 1 then
    self.ishidden = 0
  else
    self.ishidden = 1
  end
  self:show()
end
  
function Miniwindow:set(option, value)
  super(option, value)
  self.winhide:drawwin()
end

class "Winshow"(Window)

function Winshow:initialize(args)
  super(args)
  self.name = self.parent.name.."showwin"
  self.win = GetPluginID()..self.name
  self.windowpos = self.parent.windowpos
  self.width_padding = 10
  self.height_padding = 1
  self.bg_colour = self.header_bg_colour
  self.text_colour = self.parent.text_colour
  self.header_height = 1
  self.show_hyperlinks = false
  self.default_text = "Show " .. self.parent.name
end

function Winshow:drawwin()
  super(false)
  WindowDeleteAllHotspots (self.win)
  
  self:make_hyperlink (self.default_text, "showwin", self.width_padding, self:get_top_of_line(1), 
                    self.parent.togglewindow, self.default_text)
                 
end

function Winshow:calc_width(minwidth)
  local mwidth = WindowTextWidth (self.win, self.font_id, self.default_text)  + (self.width_padding * 2)
  
  return super(mwidth)
end

function Winshow:get_colour(colour, default, return_original)
  return self.parent:get_colour(colour, default, return_original)
end
