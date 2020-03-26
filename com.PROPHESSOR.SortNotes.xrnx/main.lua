--[[============================================================================
com.PROPHESSOR.SortNotes.xrnx/main.lua
============================================================================]]--

CTXNAME = 'SortNotes' -- Name in context menu

function addMenuEntry(name, callback)
  renoise.tool():add_menu_entry({
    name = 'Pattern Editor:'..CTXNAME..':'..name,
    invoke = callback
  })
end

class 'SortNotes'
  function SortNotes:__init()
    addMenuEntry("Sort", self.sort)
  end

  function SortNotes:sort()
    print("Sorting...")
  end

local sn = SortNotes()