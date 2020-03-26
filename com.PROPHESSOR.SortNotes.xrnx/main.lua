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

function getTrackInSequenceSelection(pattern, trkidx)
  local track = renoise.song().tracks[trkidx]

  if not pattern or not track
  then print("Can't get pattern of track") end

  return {
    start_line = 1,
    start_track = trkidx,
    start_column = 1,
    end_line = pattern.number_of_lines,
    end_track = trkidx,
    end_column = track.visible_note_columns + track.visible_effect_columns,
  }
end

--[[

function sort_line(table, line_idx)
  table.sort(table, function(e1, e2)
    return e1.voice_run[line_idx].note_value < e2.voice_run[line_idx].note_value
  end)

end

function sort_by_note(line_runs, line_idx, selection)
  local sorted = table.rcopy(line_runs)
  self:sort_line(sorted, line_idx)

  local low_col, high_col = selection.start_column, selection.end_column

  for k, voice in ipairs(sorted) do

    local num_lines = voice.voice_run.number_of_lines
    local notecol = xVoiceRunner.get_initial_notecol(voice.voice_run)


    local found_room,col_idx,upwards = self:find_note_column(notecol.note_value,line_idx,num_lines)

    if found_room then
      cTable.expand(self.temp_runs,col_idx)
      table.insert(self.temp_runs[col_idx],voice.voice_run)
      self:set_high_low_column(col_idx,notecol.note_value,notecol.note_value)
    else
      local initial_column = not col_idx
      local exact_match = false
      if initial_column then
        col_idx = 1
      else
        local v = self.high_low_columns[col_idx]
        if v then 
          exact_match = (notecol.note_value == v.low_note)
            and (notecol.note_value == v.high_note)
        end
      end

      -- create column (but wait with assign...)
      self:insert_temp_column(col_idx)

      -- shift existing notes?
      if not initial_column and not exact_match then
        local source_col_idx = upwards and col_idx-1 or col_idx
        local target_col_idx = upwards and col_idx or col_idx+1
        local shifted = self:shift_runs(notecol.note_value,source_col_idx,target_col_idx,line_idx-1) 
        if shifted then -- check where we've got room 
          found_room,col_idx = self:find_note_column(notecol.note_value,line_idx,num_lines)
        end
      end
      self:insert_note_run(col_idx,voice.voice_run,line_idx)
    end

  end

end

function sort(patterntrack,selection,trk_idx,seq_idx)
  local is_sorting_pattern = true
  local track = rns.tracks[trk_idx]

  local collect_mode = xVoiceRunner.COLLECT_MODE.SELECTION
  self.runner:collect(patterntrack,collect_mode,selection,trk_idx,seq_idx)

  local voice_runs = self.runner.voice_runs
  if table.is_empty(voice_runs) then
    return true
  end

  if (#table.keys(voice_runs) == 1) then
    print("Skip sorting single column")
    return true
  end

  -- sort - iterate through lines...
  for line_idx = selection.start_line,selection.end_line do

    local rslt,err = nil,nil
    local line_runs = xVoiceRunner.get_runs_on_line(voice_runs,line_idx)

    rslt,err = self:sort_by_note(line_runs,line_idx)

    if err then
      return false,err
    end

  end

  -- check which columns to merge into the result
  -- (unselected columns on either side)
  local low_col,high_col = cTable.bounds(voice_runs)
  local num_sorted_cols = #table.keys(self.temp_runs)
  local unsorted_cols = {}
  local sorted_count = 0
  local column_shift = 0
  local shift_from = nil
  local visible_note_columns
  if is_sorting_pattern then
    visible_note_columns = track.visible_note_columns
  else
    visible_note_columns = patterntrack.visible_note_columns
  end
  for k = 1,visible_note_columns do
    if (k < selection.start_column)
      or (k > selection.end_column)
    then
      unsorted_cols[k] = true
      if not shift_from and (sorted_count > 0) then
        shift_from = k
      end
    else
      unsorted_cols[k] = false
      sorted_count = sorted_count+1
    end
  end

  -- columns with content on the right-hand side of the selection
  -- are shifted sideways before we write the output...
  if shift_from then
    -- shift amount is equal to left side of selection + 
    local selection_column_span = 1+selection.end_column-selection.start_column
    column_shift = math.abs(num_sorted_cols-selection_column_span)
    if (column_shift > 0) then
      xColumns.shift_note_columns(
        patterntrack,
        shift_from,
        column_shift,
        selection.start_line,
        selection.end_line)
    end
  end

  selection.end_column = math.max(visible_note_columns,selection.start_column+#self.temp_runs-1)
  if (selection.end_column > 12) then
    return false,xVoiceSorter.ERROR_CODE.CANT_PRESERVE_EXISTING
  end

    -- align with the left side of selection by inserting empty columns 
    -- (not written to pattern - selection is masking them out)
  local start_column = selection.start_column
  if (start_column > 1) then
    repeat
      table.insert(self.temp_runs,1,{})
      start_column=start_column-1
    until (start_column == 1)
  end

  self.runner.voice_runs = self.temp_runs

  if shift_from then
    local num_cols = visible_note_columns + column_shift
    if is_sorting_pattern then
      track.visible_note_columns = math.min(12,math.max(num_cols,track.visible_note_columns))
    else
      patterntrack.visible_note_columns = math.min(12,math.max(num_cols,patterntrack.visible_note_columns))
    end
  end

  self.runner:write(patterntrack,selection,trk_idx)
  self.runner:purge_voices()

  return true

end
]]--

class 'SortNotes'
  function SortNotes:__init()
    addMenuEntry("Sort", self.sort)
  end

  function SortNotes:sort()
    print("Sorting...")

    local seqidx = renoise.song().selected_sequence_index
    local trackidx = renoise.song().selected_track_index

    print('SortNotes:sort(): Sequence =', seqidx, 'Track =', trackidx)

    local patidx = renoise.song().sequencer:pattern(seqidx)
    local pattern = renoise.song().patterns[patidx]

    local selection = getTrackInSequenceSelection(pattern, trackidx)

    local patterntrack = pattern.tracks[trackidx]
    -- start_line, start_track, start_column, end_line, end_track, end_column
  end

local sn = SortNotes()