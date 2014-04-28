--https://raw.githubusercontent.com/endavis/bastmush/r2093/Bast/BastmushChanges.txt
--https://raw.githubusercontent.com/endavis/bastmush/<release>/Bast/BastmushChanges.txt
SLAXML = require 'xml.slaxdom'

function string:split(sep)
  local sep, fields = sep or ":", {}
  local pattern = string.format("([^%s]+)", sep)
  self:gsub(pattern, function(c) fields[#fields+1] = c end)
  return fields
end

function findvaluedoc(value, el)
  local n = {}
  for _,n in ipairs(el.kids) do
    if n.name == value[1] and n.type == 'element' then
      if #value == 1 then
        return n.kids[1].value
      else
        table.remove(value, 1)
        if value[1] == 'attr' then
          for _,attr in ipairs(n.attr) do
            if attr.name == value[2] then
              return attr.value
            end
          end
          return nil
        else
          return findvaluedoc(value, n)
        end
      end
    end
  end
  return nil
end

function findvalue(value, xmlstuff)
  valuelist = value:split('.')

  doc = SLAXML:dom(xmlstuff)

  return findvaluedoc(valuelist, doc)
end

function parse_feed(feed)

  doc = SLAXML:dom(feed)

  versionloc = 'feed.entry.title'
  urlloc = 'feed.entry.link.attr.href'

  version = findvaluedoc(versionloc:split('.'), doc)
  url = findvaluedoc(urlloc:split('.'), doc)

  return version, url
end
