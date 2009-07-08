-- $Id$

require 'miniwin'
require 'tprint'

class "Togglewin"(Miniwin)


function Togglewin:initialize(args)
  args['show_hyperlinks'] = 1
  super(args)   -- notice call to superclass's constructor
  self.ishidden = tonumber (GetVariable ("ishidden"..self.name)) or args.ishidden or 0
end


function Togglewin:show(flag)
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


function Togglewin:savestate()
  super()
  SetVariable ("ishidden"..self.name, self.ishidden)
end

function Togglewin:enable()
  self.disabled = 0
  if not self.winhide then
     self.winhide = HideToggleWin:new{parent=self,name=self.name.."showwin"}
     self.winhide:createwin({" "})
  end
  self:show()
end

function Togglewin:disable()
  self.disabled = 1
  if not self.winhide then
     self.winhide = HideToggleWin{parent=self,name=self.name.."showwin"}
     self.winhide:createwin({" "})
  end
  self.winhide:show(false)
  WindowShow(self.win, false)
end

function Togglewin:mousedown (flags, hotspotid)
  if not self.winhide then
     self.winhide = HideToggleWin{parent=self,name=self.name.."showwin"}
     self.winhide:createwin({" "})
  end

  found = super(flags, hotspotid)
  if found then
    return true
  end

  if not found then
    f = self.winhide.hyperlink_functions[hotspotid]
    if f then
      f(self)
      return true
    end
  end -- function found

  print("could not find hotspot id: "..hotspotid)
  return false

end -- mousedown


function Togglewin:togglewindow()
  if self.disabled == 1 then
    return
  end
  if not self.winhide then
     self.winhide = HideToggleWin:new{parent=self,name=self.name.."showwin"}
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

function Togglewin:set(option, value)
  retfunc = super(option, value)
  self.winhide:drawwin()
  self:show()
  return retfunc
end

class "HideToggleWin"(Miniwin)

function HideToggleWin:initialize(args)
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

function HideToggleWin:drawwin()
  super(false)
  WindowDeleteAllHotspots (self.win)

  self:make_hyperlink (self.default_text, "showwin", self.width_padding, self:get_top_of_line(1), nil, nil,
                    self.parent.togglewindow, self.default_text)

end

function HideToggleWin:calc_width(minwidth)
  local mwidth = WindowTextWidth (self.win, self.font_id, self.default_text)  + (self.width_padding * 2)

  return super(mwidth)
end

function HideToggleWin:get_colour(colour, default, return_original)
  return self.parent:get_colour(colour, default, return_original)
end
