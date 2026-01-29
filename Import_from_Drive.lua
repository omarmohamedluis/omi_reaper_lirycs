--[[
  Reaper Script: Import Regions from Google Drive (Folder Selection)
  Author: Antigravity
]]

function msg(m)
  reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
local python_script = script_path .. "sheets_bridge.py"

-- Default Root Link (User provided)
local DEFAULT_ROOT = "https://drive.google.com/drive/folders/1iB9EVvTVrNrPU1Fy_KOU8dG_D_ceKV7G?usp=drive_link"

function run_python(cmd, arg1)
  local temp_file = script_path .. "py_out.txt"
  -- Use --output-file argument to let Python write UTF-8 directly, avoiding shell redirection issues
  -- NOTE: Global arguments must come BEFORE the subcommand for argparse!
  local command = string.format('python "%s" --output-file "%s" %s "%s"', python_script, temp_file, cmd, arg1)
  os.execute(command)
  
  local f = io.open(temp_file, "r")
  if not f then return nil end
  local content = f:read("*all")
  f:close()
  os.remove(temp_file)
  return content
end

function parse_time(str)
  if not str then return 0 end
  str = tostring(str):gsub('"', '')
  
  -- Check if it's just a number (seconds)
  if tonumber(str) then
    return tonumber(str)
  end

  local h, m, s, ms = str:match("(%d+):(%d+):(%d+)%.(%d+)")
  if not h then
     h, m, s = str:match("(%d+):(%d+):(%d+)")
     ms = 0
  end
  if not h then return 0 end
  local total = (tonumber(h) * 3600) + (tonumber(m) * 60) + tonumber(s)
  if ms then total = total + (tonumber("0." .. ms)) end
  return total
end

function main()
  reaper.ClearConsole()
  
  -- 1. Use Default Root Folder
  local root_link = DEFAULT_ROOT
  
  msg("Listing folders in Drive... (please wait)")
  
  -- 2. List Folders via Python
  local json_list_str = run_python("list", root_link)
  
  -- Parse JSON List: [{"id": "...", "name": "..."}, ...]
  -- Simple regex parser for flat list
  local folders = {}
  for id, name in json_list_str:gmatch('"id":%s*"(.-)",%s*"name":%s*"(.-)"') do
    table.insert(folders, {id=id, name=name})
  end
  
  if #folders == 0 then
    msg("No subfolders found or error occurred.")
    msg("Raw output: " .. tostring(json_list_str))
    return
  end
  
  -- 3. Show Selection UI
  msg("\n--- Select a Song ---")
  for i, f in ipairs(folders) do
    msg(string.format("%d. %s", i, f.name))
  end
  msg("---------------------")
  
  local retval, num_str = reaper.GetUserInputs("Select Song", 1, "Enter Number (1-"..#folders.."):", "")
  if not retval then return end
  
  local num = tonumber(num_str)
  if not num or num < 1 or num > #folders then
    msg("Invalid selection.")
    return
  end
  
  local selected_folder = folders[num]
  msg("Selected: " .. selected_folder.name)
  msg("Downloading data...")
  
  -- 4. Get Data for Selected Folder
  local json_str = run_python("get", selected_folder.id)
  
  if json_str:match("error") then
    msg("Error: " .. json_str)
    return
  end
  
  -- Extract Sheet ID and Name
  local sheet_id = json_str:match('"sheet_id":%s*"(.-)"')
  local sheet_name = json_str:match('"sheet_name":%s*"(.-)"')
  
  if sheet_id then
    reaper.SetProjExtState(0, "GoogleSheets", "SheetID", sheet_id)
    
    -- Save to persistent JSON file as requested
    local config_file = script_path .. "active_sheet.json"
    local f = io.open(config_file, "w")
    if f then
      -- Simple JSON construction
      local name_val = sheet_name or "Unknown"
      f:write('{"sheet_id": "' .. sheet_id .. '", "sheet_name": "' .. name_val .. '"}')
      f:close()
    end
  end

  -- Extract WAV Path
  local wav_path = json_str:match('"wav_path":%s*"(.-)"')
  if wav_path then wav_path = wav_path:gsub("\\\\", "\\") end

  reaper.Undo_BeginBlock()

  -- Configure Project Settings (Time Format, FPS, Snap)
  msg("--- Applying Project Settings ---")
  
  -- 1. Time Format: Hours:Minutes:Seconds:Frames
  msg("Setting Time Format to H:M:S:F (Cmd 40035)")
  reaper.Main_OnCommand(40035, 0)
  
  -- 2. Disable Secondary Time Unit (Set to None)
  msg("Setting Secondary Time Unit to None (Cmd 42358)")
  reaper.Main_OnCommand(42358, 0)

  -- 3. Enable Snap (if disabled)
  local snap_state = reaper.GetToggleCommandState(1157)
  msg("Snap State: " .. tostring(snap_state))
  if snap_state == 0 then
    msg("Enabling Snap (Cmd 1157)")
    reaper.Main_OnCommand(1157, 0)
  else
    msg("Snap already enabled.")
  end

  -- 4. Set Project FPS to 25
  msg("Setting Project FPS to 25 (Cmd 40925)")
  reaper.Main_OnCommand(40925, 0)
  
  msg("--- Settings Applied ---")
  
  -- Import WAV
  if wav_path and wav_path ~= "null" and reaper.file_exists(wav_path) then
      local track = reaper.GetTrack(0, 0)
      if not track then
        reaper.InsertTrackAtIndex(0, true)
        track = reaper.GetTrack(0, 0)
      end
      
      -- Clear Track 1
      local item_count = reaper.CountTrackMediaItems(track)
      for j = item_count-1, 0, -1 do
        local item = reaper.GetTrackMediaItem(track, j)
        reaper.DeleteTrackMediaItem(track, item)
      end
      
      -- Insert WAV
      reaper.SetEditCurPos(0, false, false)
      reaper.InsertMedia(wav_path, 0)
      msg("Imported WAV: " .. wav_path)
  else
      msg("No WAV file found/downloaded.")
  end
  
  -- Clear Regions (Robust Method)
  local retval, num_markers, num_regions = reaper.CountProjectMarkers(0)
  local total_count = num_markers + num_regions
  for i = total_count - 1, 0, -1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
    if isrgn then
        reaper.DeleteProjectMarkerByIndex(0, i)
    end
  end
  
  -- Create Regions
  local count = 0
  -- Try to match regions. 
  -- Regex assumes JSON format: "name": "...", "start": "...", "end": "..."
  for name, start_str, end_str in json_str:gmatch('"name":%s*"(.-)",%s*"start":%s*"(.-)",%s*"end":%s*"(.-)"') do
      local start_time = parse_time(start_str)
      local end_time = parse_time(end_str)
      
      if start_time and end_time then
        reaper.AddProjectMarker2(0, true, start_time, end_time, name, -1, 0)
        count = count + 1
      end
  end
  
  if count == 0 then
      msg("Warning: No regions found in data.")
      msg("Data received: " .. json_str)
  else
      msg("Created " .. count .. " regions.")
  end
  
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Import Drive Song", -1)
  msg("Done!")
end

main()
