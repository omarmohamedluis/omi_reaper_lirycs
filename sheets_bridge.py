import os
import sys
import warnings
warnings.filterwarnings("ignore")
import json
import re
import argparse
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaIoBaseDownload
import io

# If modifying these scopes, delete the file token.json.
SCOPES = [
    'https://www.googleapis.com/auth/drive.readonly',
    'https://www.googleapis.com/auth/spreadsheets'
]

# Get absolute path to the script's directory
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TOKEN_PATH = os.path.join(SCRIPT_DIR, 'token.json')
CREDS_PATH = os.path.join(SCRIPT_DIR, 'credentials.json')

def get_creds():
    creds = None
    if os.path.exists(TOKEN_PATH):
        creds = Credentials.from_authorized_user_file(TOKEN_PATH, SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists(CREDS_PATH):
                print(f"Error: credentials.json not found at {CREDS_PATH}. Please download it from Google Cloud Console.")
                sys.exit(1)
            flow = InstalledAppFlow.from_client_secrets_file(
                CREDS_PATH, SCOPES)
            creds = flow.run_local_server(port=0)
        with open(TOKEN_PATH, 'w') as token:
            token.write(creds.to_json())
    return creds

def parse_drive_link(link):
    match = re.search(r'folders/([a-zA-Z0-9_-]+)', link)
    if match:
        return match.group(1)
    return link

def list_folders(root_link, printer=print):
    creds = get_creds()
    service = build('drive', 'v3', credentials=creds)
    root_id = parse_drive_link(root_link)
    
    query = f"'{root_id}' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false"
    results = service.files().list(q=query, pageSize=50, fields="files(id, name)").execute()
    items = results.get('files', [])
    
    printer(items)

def get_data(folder_link, output_dir=None, printer=print):
    creds = get_creds()
    drive_service = build('drive', 'v3', credentials=creds)
    sheets_service = build('sheets', 'v4', credentials=creds)

    folder_id = parse_drive_link(folder_link)
    
    # 1. Find Spreadsheet and WAV in Folder
    query = f"'{folder_id}' in parents and trashed=false"
    results = drive_service.files().list(q=query, fields="files(id, name, mimeType)").execute()
    items = results.get('files', [])

    if not items:
        printer({"error": "Folder is empty or not accessible."})
        return

    sheet_id = None
    sheet_name = None
    wav_id = None
    wav_name = None

    for item in items:
        if item['mimeType'] == 'application/vnd.google-apps.spreadsheet':
            sheet_id = item['id']
            sheet_name = item['name']
        elif item['name'].lower().endswith('.wav'):
            wav_id = item['id']
            wav_name = item['name']

    if not sheet_id:
        printer({"error": "No Google Sheet found in the folder."})
        return

    # Download WAV if found and output_dir is provided
    local_wav_path = None
    if wav_id and output_dir:
        # Sanitize filename
        safe_name = "".join([c for c in wav_name if c.isalpha() or c.isdigit() or c in " ._-"]).strip()
        local_wav_path = os.path.join(output_dir, safe_name)
        
        # Handle file locking (PermissionError) by renaming if needed
        import time
        try:
            # Try opening to check write permission
            with open(local_wav_path, 'a'):
                pass
        except PermissionError:
            # File is locked, append timestamp
            name, ext = os.path.splitext(safe_name)
            local_wav_path = os.path.join(output_dir, f"{name}_{int(time.time())}{ext}")

        request = drive_service.files().get_media(fileId=wav_id)
        
        fh = io.FileIO(local_wav_path, 'wb')
        downloader = MediaIoBaseDownload(fh, request)
        done = False
        while done is False:
            status, done = downloader.next_chunk()
        fh.close()

    # 2. Read Data
    result = sheets_service.spreadsheets().values().get(
        spreadsheetId=sheet_id, range="A:M").execute()
    rows = result.get('values', [])

    output_data = {
        "sheet_id": sheet_id,
        "sheet_name": sheet_name,
        "wav_path": local_wav_path,
        "regions": []
    }

    # Skip header? Let's try to detect.
    start_idx = 0
    in_col_idx = 11
    out_col_idx = 12
    
    if rows and len(rows) > 0:
        # Safe header check
        header = [str(c).lower() for c in rows[0]]
        if header and ("español" in header or "in" in header):
            start_idx = 1
            if "in" in header:
                in_col_idx = header.index("in")
            if "out" in header:
                out_col_idx = header.index("out")

    for i in range(start_idx, len(rows)):
        row = rows[i]
        # Ensure row has enough columns to cover our target indices
        max_idx = max(in_col_idx, out_col_idx)
        if len(row) > max_idx:
            name = row[0]
            start = row[in_col_idx]
            end = row[out_col_idx]
            
            if start and end:
                output_data["regions"].append({
                    "name": name,
                    "start": start,
                    "end": end,
                    "row_index": i + 1
                })

    printer(output_data)

def col_to_letter(n):
    string = ""
    while n >= 0:
        string = chr((n % 26) + 65) + string
        n = (n // 26) - 1
    return string

def update_data(sheet_id, regions_json_path, printer=print):
    creds = get_creds()
    service = build('sheets', 'v4', credentials=creds)

    with open(regions_json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Read the header row to find 'in' and 'out' columns
    header_values = service.spreadsheets().values().get(
        spreadsheetId=sheet_id, range="A1:Z1").execute().get('values', [])
    
    in_col_letter = "L"
    out_col_letter = "M"

    if header_values and header_values[0]:
        header = [str(c).lower() for c in header_values[0]]
        if "in" in header:
            in_col_letter = col_to_letter(header.index("in"))
        if "out" in header:
            out_col_letter = col_to_letter(header.index("out"))

    current_values = service.spreadsheets().values().get(
        spreadsheetId=sheet_id, range="A:A").execute().get('values', [])
    
    # Map Name -> List of Row Indices (1-based) to handle duplicates
    name_to_rows = {}
    for idx, row in enumerate(current_values):
        if row:
            name = row[0]
            if name not in name_to_rows:
                name_to_rows[name] = []
            name_to_rows[name].append(idx + 1)

    data_to_update = []
    
    for region in data:
        name = region['name']
        start = region['start']
        end = region['end']
        
        # Round values to 1 decimal place and force dot separator
        try:
            # Format as string with 1 decimal place, forcing dot
            start = "{:.1f}".format(float(start))
            end = "{:.1f}".format(float(end))
        except (ValueError, TypeError):
            # Keep original if not a number
            pass
        
        # Get the next available row index for this name
        if name in name_to_rows and name_to_rows[name]:
            row_idx = name_to_rows[name].pop(0) # Consume the index
            
            # Add updates for IN and OUT columns separately since they might not be adjacent
            data_to_update.append({
                'range': f"{in_col_letter}{row_idx}",
                'values': [[start]]
            })
            data_to_update.append({
                'range': f"{out_col_letter}{row_idx}",
                'values': [[end]]
            })

    if data_to_update:
        body = {
            'valueInputOption': 'USER_ENTERED',
            'data': data_to_update
        }
        result = service.spreadsheets().values().batchUpdate(
            spreadsheetId=sheet_id, body=body).execute()
        printer({"status": "success", "updatedCells": result.get('totalUpdatedCells')})
    else:
        printer({"status": "no_changes"})

if __name__ == '__main__':
    # Force UTF-8 output for Windows consoles
    sys.stdout.reconfigure(encoding='utf-8')

    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest='command')

    get_parser = subparsers.add_parser('get')
    get_parser.add_argument('folder_link', help='Google Drive Folder Link')

    list_parser = subparsers.add_parser('list')
    list_parser.add_argument('root_link', help='Root Folder Link')

    update_parser = subparsers.add_parser('update')
    update_parser.add_argument('sheet_id', help='Google Sheet ID')
    update_parser.add_argument('json_path', help='Path to JSON file with new regions')
    
    # Global output argument
    parser.add_argument('--output-file', help='Path to write output JSON to (avoids console encoding issues)', default=None)

    args = parser.parse_args()

    # Helper to print JSON
    def print_output(data):
        json_str = json.dumps(data, ensure_ascii=False)
        if args.output_file:
            with open(args.output_file, 'w', encoding='utf-8') as f:
                f.write(json_str)
        else:
            print(json_str)

    # Monkey patch print used for JSON output
    # checking where print is used: lines 58, 73, 90, 164, 208, 210
    # I will replace the main logic calls to redirect their output or modify functions to return data instead of printing.
    # Actually, easier to let functions print but intercept it? No, better to pass the printer or change functions.
    # Let's change the functions to return data or accept a callback?
    # Minimal change: Update the functions to use a global printer or just change the print calls in them?
    # I can't easily change all print calls with one replace_file_content if they are scattered.
    # I will redefine the functions in the original file to use the new output mechanism.
    # Wait, I can just modify the functions.

    if args.command == 'get':
        # Use SCRIPT_DIR to avoid writing to ProgramData
        get_data(args.folder_link, SCRIPT_DIR, printer=print_output)
    elif args.command == 'list':
        list_folders(args.root_link, printer=print_output)
    elif args.command == 'update':
        update_data(args.sheet_id, args.json_path, printer=print_output)


