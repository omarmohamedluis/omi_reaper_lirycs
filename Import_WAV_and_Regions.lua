--[[
  Reaper Script: Import WAV and Create Regions from CSV
  Author: Antigravity
  Description: 
    1. Prompts user for a folder path (or uses a default).
    2. Finds the first .wav file and imports it to Track 1 (clearing it first).
    3. Finds the first .csv file and creates regions based on Columns A (Name), L (Start), M (End).
    
  CSV Format Expected:
    - Column A: Region Name
    - Column L: Start Time (HH:MM:SS.ms)
    - Column M: End Time (HH:MM:SS.ms)
    - Separator: Comma (,) or Semicolon (;) depending on locale, script attempts to detect or assumes comma.
]]

function msg(m)
  reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

-- Function to parse time string "HH:MM:SS.ms" to seconds
function parse_time(str)
  if not str then return 0 end
  -- Remove quotes if present
  str = str:gsub('"', '')
  
  -- Try to match HH:MM:SS.ms or MM:SS.ms
  local h, m, s, ms = str:match("(%d+):(%d+):(%d+)%.(%d+)")
  
  if not h then
     -- Try without ms
     h, m, s = str:match("(%d+):(%d+):(%d+)")
     ms = 0
  end
  
  if not h then
    return 0 -- Could not parse
  end
  
  local total_seconds = (tonumber(h) * 3600) + (tonumber(m) * 60) + tonumber(s)
  if ms then
    -- Handle variable ms length (e.g. .5 vs .500)
    local ms_val = tonumber(ms)
    if #tostring(ms) == 1 then ms_val = ms_val / 10 end
    if #tostring(ms) == 2 then ms_val = ms_val / 100 end
    if #tostring(ms) >= 3 then ms_val = ms_val / (10^#tostring(ms)) end
    
    -- Actually, a simpler way for decimal part:
    -- The regex separates the dot. So if we have 12.345, ms is 345.
    -- We need to add 0.345.
    -- Let's just re-parse the seconds part as a float if possible, but the ":" makes it hard.
    -- Let's stick to the manual calc.
    total_seconds = total_seconds + (tonumber("0." .. ms))
  end
  
  return total_seconds
end

-- Function to split CSV line
function split_csv_line(line, sep)
  local res = {}
  local pos = 1
  sep = sep or ','
  while true do 
    local c = string.sub(line, pos, pos)
    if (c == "") then break end
    if (c == '"') then
      -- quoted value (ignore separator within quotes)
      local txt = ""
      repeat
        local startp,endp = string.find(line, '^%b""', pos)
        txt = txt .. string.sub(line, startp+1, endp-1)
        pos = endp + 1
        c = string.sub(line, pos, pos) 
        if (c == '"') then txt = txt..'"' end 
        -- check first char AFTER quoted string, if it is another quote, then it means escaped quote
      until (c ~= '"')
      table.insert(res, txt)
      if (c == sep) then pos = pos + 1 end
    else
      -- no quotes
      local startp, endp = string.find(line, sep, pos)
      if (startp) then 
        table.insert(res, string.sub(line, pos, startp-1))
        pos = endp + 1
      else
        -- no separator found -> last field
        table.insert(res, string.sub(line, pos))
        break
      end 
    end
  end
  return res
end

-- Simplified split for standard CSVs without complex quoting
function simple_split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

function main()
  reaper.ClearConsole()
  
  -- 1. Get Path
  local retval, path = reaper.JS_Dialog_BrowseForFolder("Select folder with WAV and CSV", "")
  if retval ~= 1 then
    -- Fallback if JS_ API not installed or cancelled: ask for text input
    retval, path = reaper.GetUserInputs("Path", 1, "Folder Path:", "")
    if not retval or path == "" then return end
  end
  
  -- Ensure path ends with separator
  if string.sub(path, -1) ~= "\\" and string.sub(path, -1) ~= "/" then
    path = path .. "\\" -- Assume Windows based on user OS
  end
  
  msg("Scanning: " .. path)
  
  -- 2. Find Files
  local wav_file = nil
  local csv_file = nil
  
  -- Enumerate files (Reaper API)
  local i = 0
  repeat
    local file = reaper.EnumerateFiles(path, i)
    if file then
      local ext = file:match("^.+(%..+)$")
      if ext then ext = ext:lower() end
      
      if ext == ".wav" and not wav_file then
        wav_file = file
      elseif ext == ".csv" and not csv_file then
        csv_file = file
      end
    end
    i = i + 1
  until not file
  
  if not wav_file then msg("Error: No .wav file found.") return end
  if not csv_file then msg("Error: No .csv file found.") return end
  
  msg("Found WAV: " .. wav_file)
  msg("Found CSV: " .. csv_file)
  
  reaper.Undo_BeginBlock()
  
  -- 3. Import WAV to Track 1
  local track = reaper.GetTrack(0, 0)
  if not track then
    -- Create track if none exists
    reaper.InsertTrackAtIndex(0, true)
    track = reaper.GetTrack(0, 0)
  end
  
  -- Clear Track 1 items
  local item_count = reaper.CountTrackMediaItems(track)
  for j = item_count-1, 0, -1 do
    local item = reaper.GetTrackMediaItem(track, j)
    reaper.DeleteTrackMediaItem(track, item)
  end
  
  -- Insert new WAV
  reaper.SetEditCurPos(0, false, false)
  reaper.InsertMedia(path .. wav_file, 0) -- 0 = add to current track
  
  -- 4. Process CSV
  local f = io.open(path .. csv_file, "r")
  if not f then msg("Could not open CSV.") return end
  
  local line_idx = 0
  for line in f:lines() do
    line_idx = line_idx + 1
    -- Skip header if it looks like one (optional, but user said "fila n", implying data starts somewhere)
    -- We'll assume row 1 is header if it contains "Español" or similar, or just parse everything and fail gracefully on bad times.
    
    -- Detect separator (comma or semicolon)
    local sep = ","
    if line:find(";") then sep = ";" end
    
    local cols = simple_split(line, sep)
    
    -- User said:
    -- Col A (1) = Name
    -- Col L (12) = Start
    -- Col M (13) = End
    
    if #cols >= 13 then
      local name = cols[1]
      local start_str = cols[12]
      local end_str = cols[13]
      
      local start_time = parse_time(start_str)
      local end_time = parse_time(end_str)
      
      if start_time > 0 and end_time > 0 then
        -- Create Region
        -- AddProjectMarker2(proj, isrgn, pos, rgnend, name, idx, color)
        reaper.AddProjectMarker2(0, true, start_time, end_time, name, -1, 0)
      end
    end
  end
  
  f:close()
  
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Import WAV and Regions", -1)
  msg("Done!")
end

main()
