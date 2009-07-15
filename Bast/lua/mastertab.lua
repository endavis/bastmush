-- $Id: miniwin.lua 47 2009-02-09 18:00:51Z endavis $

require 'miniwin'
require 'tprint'

class "Mastertabwin"(Miniwin)
--string.gsub(tests, "[a-zA-z]", " ")
-- add hide all and show all menu items

function Mastertabwin:initialize(args)
  super(args)   -- notice call to superclass's constructor
  self.show_hyperlinks = tonumber (GetVariable ("show_hyperlink"..self.name)) or args.show_hyperlink or 1
  self.tabs = {}
  self.header_height = 1
  self.tab_padding = 8
  self.text = {"   "}
  self:add_setting( 'orientation', {type="number", help="orientation of the tabs, 0 = horizontal, 1 = vertical", low=0, high=1, default=0, sortlev=44})

  local td = {}
  td.id = GetPluginID()
  td.text = "Show All"
  td.func = self.showall
  td.name = 'z1Show all'
  td.win = self.win .. 'ShowAll'
  td.popup = "Show all Windows"
  self:addtab(td)
  td = {}
  td.id = GetPluginID()
  td.text = "Hide All"
  td.func = self.hideall
  td.name = 'z2Hide all'
  td.win = self.win .. 'HideAll'
  td.popup = "Hide all Windows"
  self:addtab(td)
end

function Mastertabwin:hideall()
  for i,v in pairs(self.tabs) do
    WindowShow(v.win, false)
  end
end

function Mastertabwin:showall()
  for i,v in pairs(self.tabs) do
    WindowShow(v.win, true)
  end
end

function Mastertabwin:addtab(args)
  self.tabs[args.win] = args
  self:drawwin()
end

function Mastertabwin:removetab(args)
  self.tabs[args.win] = nil
  self:drawwin()
end

function Mastertabwin:drawtab(key, start, i)
  height = self:calc_height()
  local popup = ''
  if self.tabs[key].popup then
    popup = self.tabs[key].popup
  else
    popup = "Toggle " .. self.tabs[key].name
  end
  if self.tabs[key].func then
    nleft = self:make_hyperlink_from_text(self.tabs[key].text, key, 1, start, self.tabs[key].func, popup, nil, true)
  else
    nleft = self:make_hyperlink_from_text(self.tabs[key].text, key, 1, start, self.toggletab, popup, nil, true)
  end
  WindowLine (self.win, nleft + self.tab_padding / 2, 0, nleft + self.tab_padding / 2, height, ColourNameToRGB ("white"), 0, 1)
  nleft = nleft + self.tab_padding

  return nleft
end

function Mastertabwin:toggletab(flags, hotspot_id)
  WindowShow(hotspot_id, not (WindowInfo(hotspot_id, 5)))
end

function Mastertabwin:drawtabs()
  start = self.tab_padding / 2
  keys = sort_table_keys(self.tabs, 'name')
  for i,v in pairs(keys) do
    start = self:drawtab(v, start, i)
  end
end

function Mastertabwin:calc_width(minwidth)
  width = 0
  for i,v in pairs(self.tabs) do
    twidth = self:calc_text_width(v.text)
    width = width + twidth + self.tab_padding
  end
  return width
end

function Mastertabwin:drawwin(tshow)
--  if not next(self.text) then
--    return
--  end
  if self.tabs == nil or not next(self.tabs) then
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

  self:drawtabs()
  WindowShow(self.win, true)
end

function sort_table_keys(ttable, sortkey)
  --[[
     sort the keys of the options table
  --]]
  local function sortfunc (a, b)
    return (ttable[a][sortkey] < ttable[b][sortkey])
  end


  local t2 = {}
  for i,v in pairs(ttable) do
    table.insert(t2, i)
  end
  table.sort(t2, sortfunc)

  return t2

end
