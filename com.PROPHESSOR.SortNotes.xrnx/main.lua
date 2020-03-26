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
function sort(patterntrack,selection,trk_idx,seq_idx)
  local is_sorting_pattern = true
  local track = rns.tracks[trk_idx]

  local collect_mode = xVoiceRunner.COLLECT_MODE.SELECTION
  self.runner:collect(patterntrack,collect_mode,self.selection,trk_idx,seq_idx)

  local voice_runs = self.runner.voice_runs
  if table.is_empty(voice_runs) then
    return true
  end

  -- optimize: skip sorting when using particular methods
  -- on a single column (result would be identical anyway)
  if (#table.keys(voice_runs) == 1)
    and ((self.sort_method == xVoiceSorter.SORT_METHOD.NORMAL)
      or (self.sort_method == xVoiceSorter.SORT_METHOD.COMPACT))
  then
    LOG("Skip sorting single column with normal/compact method")
    return true
  end

  -- prepare for unique sorting
  if (self.sort_method == xVoiceSorter.SORT_METHOD.UNIQUE) then

    -- build map of unique notes 
    for k,v in pairs(self.runner.unique_notes) do
      for k2,v2 in pairs(v) do
        table.insert(self.unique_map,{
          note_value = k,
          instrument_value = self.unique_instrument and k2 or nil
        })
      end
    end
    if (#self.runner.unique_notes > xVoiceSorter.MAX_NOTE_COLUMNS) then
      self.required_cols = table.rcopy(self.unique_map)
      return false,xVoiceSorter.ERROR_CODE.TOO_MANY_COLS
    end
    -- TODO merge with sort_line_runs()
    table.sort(self.unique_map,function(e1,e2)
      if (self.sort_mode == xVoiceSorter.SORT_MODE.LOW_TO_HIGH) then
        if (e1.note_value == e2.note_value) 
          and (e1.instrument_value)
          and (e2.instrument_value)
        then
          return e1.instrument_value < e2.instrument_value
        else
          return e1.note_value < e2.note_value
        end
      elseif (self.sort_mode == xVoiceSorter.SORT_MODE.HIGH_TO_LOW) then
        if (e1.note_value == e2.note_value) 
          and (e1.instrument_value)
          and (e2.instrument_value)
        then
          return e1.instrument_value > e2.instrument_value
        else
          return e1.note_value > e2.note_value
        end
      end
    end)

  end

  -- sort - iterate through lines...
  for line_idx = self.selection.start_line,self.selection.end_line do

    local rslt,err = nil,nil
    local line_runs = xVoiceRunner.get_runs_on_line(voice_runs,line_idx)

    if (self.sort_method == xVoiceSorter.SORT_METHOD.NORMAL) then
      rslt,err = self:sort_by_note(line_runs,line_idx)
    elseif (self.sort_method == xVoiceSorter.SORT_METHOD.COMPACT) then
      rslt,err = self:sort_compact(line_runs,line_idx) 
    elseif (self.sort_method == xVoiceSorter.SORT_METHOD.UNIQUE) then
      rslt,err = self:sort_unique(line_runs,line_idx) 
      if (#self.unique_map > xVoiceSorter.MAX_NOTE_COLUMNS) then
        self.required_cols = table.rcopy(self.unique_map)
        return false,xVoiceSorter.ERROR_CODE.TOO_MANY_COLS
      end
    end

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
    local selection_column_span = 1+self.selection.end_column-self.selection.start_column
    column_shift = math.abs(num_sorted_cols-selection_column_span)
    if (column_shift > 0) then
      xColumns.shift_note_columns(
        patterntrack,
        shift_from,
        column_shift,
        self.selection.start_line,
        self.selection.end_line)
    end
  end

  self.selection.end_column = math.max(visible_note_columns,self.selection.start_column+#self.temp_runs-1)
  if (self.selection.end_column > 12) then
    return false,xVoiceSorter.ERROR_CODE.CANT_PRESERVE_EXISTING
  end

    -- align with the left side of selection by inserting empty columns 
    -- (not written to pattern - selection is masking them out)
  local start_column = self.selection.start_column
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

  self.runner:write(patterntrack,self.selection,trk_idx)
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