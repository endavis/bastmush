-- $Id: aardutils.lua 845 2010-09-28 15:47:29Z endavis $
--[[
http://code.google.com/p/bastmush
 - Documentation and examples

functions in this module


data structures in this module
spelltarget_table 
 - map target from slist to a string

spelltype_table
 - map type from slist to a string
--]]


spelltarget_table = {}
spelltarget_table[0] = 'special'
spelltarget_table[1] = 'attack'
spelltarget_table[2] = 'spellup'
spelltarget_table[3] = 'selfonly'
spelltarget_table[4] = 'object'

spelltype_table = {'spell', 'skill'}

