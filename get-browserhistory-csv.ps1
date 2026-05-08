# Generates a CSV file containing the browser history for all user profiles from the last X days
# Profile details are in the "Local State" file in the Chromium browser's User Data folder
# Can scan multiple chromium-based browsers by adding to the $browsers array (e.g. "Google\Chrome", "Microsoft\Edge")
# Requires the SQLite data library to query history. This can be downloaded from https://www.sqlite.org/download.html
# I recommend using the latest version of the "sqlite-dll-win64-v64*.zip"

[CmdletBinding()]
param (
    [switch]$EnableDebug
)

$previousDebugPreference = $DebugPreference
if ($EnableDebug) { $DebugPreference = 'Continue' }

$days = 180
$browsers = @(
    "Google\Chrome",
    "Microsoft\Edge"
)

# Add a reference to the SQLite data library.
Add-Type -Path "C:\Users\ivanw\OneDrive - SharePoint Gurus\Documents\Downloads\sqlite\System.Data.SQLite.dll"

# Location to copy browser history files and to generate the CSV file
$appDirectory = "C:\Users\ivanw\OneDrive - SharePoint Gurus\Documents"

# Specify the location of the CSV file to populate with the profile history details. Delete this file if it already exists
$csvHistory = "$appDirectory\history.csv"
Remove-Item -Path $csvHistory -Force -ErrorAction SilentlyContinue

# Specify the path to backup each profile history to. This avoids database lock issues with the source history file
$backupHistory = "$appDirectory\history.bak"

# Define the SQL connection that will be used to connect to each profile history file
$con = New-Object -TypeName System.Data.SQLite.SQLiteConnection

# Loop through each browser
foreach ($browser in $browsers) {

    # Location where chromium browsers store the Local State file and profile subdirectories
    $browserData = "$env:LOCALAPPDATA\$browser\User Data"

    if (-not (Test-Path "$browserData\Local State")) {
        Write-Warning "Browser data not found, skipping: $browser"
        continue
    }

    # Get the display name for this browser (last segment of the path, e.g. "Chrome", "Edge")
    $browserName = Split-Path $browser -Leaf

    # Read the localState JSON file into a hash table. This contains details of each profile set up in the browser
    $localState = Get-Content -Path "$browserData\Local State" -Raw -Encoding utf8
    $hashLocalState = ConvertFrom-Json -AsHashtable $localState

    # Loop through each profile defined in the Local State file
    foreach ($browserProfile in $hashLocalState.profile.info_cache.GetEnumerator()) {

        Write-Debug "$browserName - $($browserProfile.Value.name)"

        # Specify the path to the current profile's history database (SQLite)
        $history = "$browserData\$($browserProfile.Name)\History"

        if (-not (Test-Path $history)) {
            Write-Warning "No history file found for profile '$($browserProfile.Value.name)' in $browserName, skipping."
            continue
        }

        # Copy the history to the backup directory to avoid database lock issues
        Copy-Item $history -Destination $backupHistory -Force

        # Connect to the backup of the history database
        $con.ConnectionString = "Data Source=$backupHistory"
        $con.Open()

        try {
            # Define the query to run against the database
            $SourceSQLCommand = $con.CreateCommand()
            $SourceSQLCommand.CommandText = "select '$browserName - $($browserProfile.Value.name)' as 'Profile', u.url, u.title, datetime(v.visit_time/1000000-11644473600, 'unixepoch', 'localtime') as 'visit_time', datetime(v.visit_time/1000000-11644473600, 'unixepoch', 'localtime', 'start of day') as 'visit_date', v.visit_duration from urls as u join visits as v on u.id = v.url where (datetime(v.visit_time/1000000-11644473600, 'unixepoch', 'localtime', 'start of day') > date('now','-$days day')) "
            # Configure the data adapter and run the query. Store results in $data
            $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $SourceSQLCommand
            $data = New-Object System.Data.DataSet
            [void]$adapter.Fill($data)
            # Append the query results to the CSV file
            $data.Tables[0] | Export-Csv $csvHistory -NoTypeInformation -Append
        } finally {
            $SourceSQLCommand.Dispose()
            $adapter.Dispose()
            $con.Close()
        }
    }
}

$DebugPreference = $previousDebugPreference

#start-sleep 60
