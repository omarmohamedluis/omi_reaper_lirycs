--[[
  Reaper Script: Export Regions to Google Sheets (via Python)
  Author: Antigravity
]]

function msg(m)
  reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
local python_script = script_path .. "sheets_bridge.py"
local json_file = script_path .. "regions_export.json"

function format_time(seconds)
  -- Format to seconds with 2 decimal places (centésimas)
  return string.format("%.2f", seconds)
end

function main()
  reaper.ClearConsole()
  
  -- Try to get ID and Name from persistent file
  local config_file = script_path .. "active_sheet.json"
  local f = io.open(config_file, "r")
  local sheet_name = "Unknown Sheet"
  
  if f then
    local content = f:read("*all")
    f:close()
    local file_id = content:match('"sheet_id":%s*"(.-)"')
    local file_name = content:match('"sheet_name":%s*"(.-)"')
    
    if file_id and file_id ~= "" then
      sheet_id = file_id
    end
    if file_name and file_name ~= "" then
      sheet_name = file_name
    end
  end

  if not sheet_id or sheet_id == "" then
     sheet_id = reaper.GetProjExtState(0, "GoogleSheets", "SheetID")
  end
  
  if not sheet_id or sheet_id == "" then
    local retval, input = reaper.GetUserInputs("Sheet ID Required", 1, "Google Sheet ID:", "")
    if not retval or input == "" then return end
    sheet_id = input
  end
  
  -- CONFIRMATION DIALOG
  local confirm = reaper.ShowMessageBox("Vas a subir los tiempos a:\n" .. sheet_name .. "\n\n¿Estás seguro?", "Confirmar Exportación", 4) -- 4 = Yes/No
  if confirm == 7 then -- 7 = No
    return
  end
  
  msg("Exporting regions to: " .. sheet_name)
  
  -- 1. Collect Regions
  local regions = {}
  local i = 0
  repeat
    local ret, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
    if ret > 0 and isrgn then
      table.insert(regions, {
        name = name,
        start_time = format_time(pos),
        end_time = format_time(rgnend)
      })
    end
    i = i + 1
  until ret == 0
  
  -- 2. Write JSON
  local f = io.open(json_file, "w")
  if not f then msg("Error writing temp JSON.") return end
  
  f:write("[\n")
  for idx, r in ipairs(regions) do
    f:write(string.format('  {"name": "%s", "start": "%s", "end": "%s"}', r.name, r.start_time, r.end_time))
    if idx < #regions then f:write(",\n") else f:write("\n") end
  end
  f:write("]\n")
  f:close()
  
  -- 3. Call Python and Capture Output
  local temp_out = script_path .. "export_out.txt"
  -- Redirect stderr to stdout to capture crashes (2>&1)
  local command = string.format('python "%s" update "%s" "%s" > "%s" 2>&1', python_script, sheet_id, json_file, temp_out)
  
  local exit_code = os.execute(command)
  
  local f = io.open(temp_out, "r")
  local output_str = ""
  if f then
    output_str = f:read("*all")
    f:close()
    os.remove(temp_out)
  end
  
  if output_str:match("success") then
      local count = output_str:match('"updatedCells":%s*(%d+)')
      msg("Success! Updated " .. (count or "?") .. " cells in Google Sheets.")
  else
      msg("Error or Warning during export:")
      msg(output_str)
  end
  
  -- Cleanup temp JSON
  os.remove(json_file)
end

main()
