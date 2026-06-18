# --- CONFIGURATION ---
$LogFolder    = "C:\temp\logs"         # Folder containing your copied Sonarr/Radarr logs
$OutputFile   = "C:\temp\CorruptFiles.txt" # Where to save the hit list
$DockerMount  = "/tv/"                    # The base path Sonarr uses
$WindowsDrive = "D:\Media\"      # Your StableBit DrivePool path
# ---------------------

if (Test-Path $OutputFile) { Remove-Item $OutputFile }

$LogFiles = Get-ChildItem -Path $LogFolder -File
$TotalLogs = $LogFiles.Count

if ($TotalLogs -eq 0) {
    Write-Host "No log files found in $LogFolder. Check your path." -ForegroundColor Red
    exit
}

Write-Host "Found $TotalLogs log files. Starting scan..." -ForegroundColor Magenta

# Regex to catch the exact file path from the "Unable to parse media info" error
$Regex = "Unable to parse media info from file:\s+(.+?\.(mp4|mkv|avi))"
$CorruptList = [System.Collections.Generic.HashSet[string]]::new()
$CurrentLog = 0

foreach ($Log in $LogFiles) {
    $CurrentLog++
    
    # FIXED: Isolated $TotalLogs from the colon using ${TotalLogs}
    Write-Host " [>>] Parsing log $CurrentLog of ${TotalLogs}: $($Log.Name)..." -NoNewline -ForegroundColor DarkCyan
    
    $InitialCount = $CorruptList.Count

    # Read the log file line by line to keep memory low
    $StreamReader = [System.IO.StreamReader]::new($Log.FullName)
    while ($null -ne ($Line = $StreamReader.ReadLine())) {
        
        if ($Line -match $Regex) {
            $LinuxPath = $Matches[1]
            
            # Translate the Docker path to the Windows path
            $WindowsPath = $LinuxPath.Replace($DockerMount, $WindowsDrive).Replace("/", "\")
            
            # Add to HashSet to automatically filter out duplicates
            [void]$CorruptList.Add($WindowsPath)
        }
    }
    $StreamReader.Close()

    $NewHits = $CorruptList.Count - $InitialCount
    Write-Host " (Found $NewHits new targets | Total Unique Hits: $($CorruptList.Count))" -ForegroundColor Yellow
}

Write-Host "`n--------------------------------------------------" -ForegroundColor Cyan

if ($CorruptList.Count -gt 0) {
    $CorruptList | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Host "Success. Harvested $($CorruptList.Count) unique corrupted files." -ForegroundColor Green
    Write-Host "Hit list saved to: $OutputFile" -ForegroundColor Green
} else {
    Write-Host "No corrupt media errors found in the provided logs." -ForegroundColor Green
}