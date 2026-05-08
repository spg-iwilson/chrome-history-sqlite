# Generates a CSV file containing the browser history for all user profiles from the last X days
# Profile details are in the "Local State" file in the Chromium browser's User Data folder
# Requires the SQLite data library to query history. This can be downloaded from https://www.sqlite.org/download.html
# I recommend using the latest version of the "sqlite-dll-win64-v64*.zip"

$days = 180
$browser = "Google\Chrome" 
#$browser = "Microsoft\Edge" # Uncomment this line and comment the line above to run for Edge instead of Chrome

# Add a reference to the SQLite data library.
Add-Type -Path "C:\Users\ivanw\OneDrive - SharePoint Gurus\Documents\Downloads\sqlite\System.Data.SQLite.dll"

# Location to copy browser history files and to generate the CSV file
$appDirectory = "C:\Users\ivanw\OneDrive - SharePoint Gurus\Documents"

# Location where chromium browsers stores the Local State file and profile subdirectories
$browserData = "$env:LOCALAPPDATA\$browser\User Data"

# Read the localState JSON file into a hash table. This contains details of each profile set up in the browser
$localState = get-content -path "$browserData\Local State" -raw -encoding utf8
$hashLocalState = ConvertFrom-Json -AsHashtable $localState 

# Specify the location of the CSV file to populate with the profile history details. Delete this file if it already exists
$csvHistory = "$appDirectory\history.csv"
remove-item -Path $csvHistory -Force -ErrorAction SilentlyContinue

# Specify the path to backup each profile history to. This avoids database lock issues with the source history file
$backupHistory = "$appDirectory\history.bak"

# Define the SQL connection that will be used to connect to each profile history file
$con = New-Object -TypeName System.Data.SQLite.SQLiteConnection

# Loop through each profile defined in the Local State file
foreach($profile in $hashLocalState.profile.info_cache.GetEnumerator()) {
    
    Write-debug $profile.Value.name
    # specify the path to the current profile's history database (SQLite)
    $history = $browserData+"\"+$profile.Name+"\History"
    # copy the history to the backup directory
    copy-item $history -Destination $backupHistory -force
    # Connect to the backup of the history database
    $con.ConnectionString="Data Source="+$backupHistory
    $con.Open()

    # Define the query to run against the database
    $SourceSQLCommand = $con.CreateCommand()
    $SourceSQLCommand.CommandText = "select '"+ $profile.Value.name + "' as 'Profile', u.url, u.title, datetime(v.visit_time/1000000-11644473600, 'unixepoch', 'localtime') as 'visit_time', datetime(v.visit_time/1000000-11644473600, 'unixepoch', 'localtime', 'start of day') as 'visit_date', v.visit_duration from urls as u join visits as v on u.id = v.url where (visit_date > date('now','-$days day')) "
    # Configure the data adapter and run the query. Store results in $data 
    $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $SourceSQLCommand
    $data = New-Object System.Data.DataSet
    [void]$adapter.Fill($data)
    # Append the query results to the CSV file
    $data.Tables[0] | export-csv $csvHistory -NoTypeInformation -Append
    $con.Close()
    
}

#start-sleep 60
