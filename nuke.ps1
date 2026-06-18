# --- CONFIGURATION ---
$LogPath  = "C:\temp\CorruptFiles.txt"
$Throttle = 12 # Deletion is fast, 12 threads is solid.
# ---------------------

if (-not (Test-Path $LogPath)) {
    Write-Error "Target log file not found. Run Phase 1 first."
    exit
}

# Load the hit list
$FilesToNuke = Get-Content -Path $LogPath
$TotalFiles  = $FilesToNuke.Count

if ($TotalFiles -eq 0) {
    Write-Host "Log file is empty. Nothing to delete." -ForegroundColor Green
    exit
}

Write-Host "WARNING: Ready to permanently delete $TotalFiles files." -ForegroundColor Red
Read-Host "Press ENTER to confirm the purge or CTRL+C to abort"

Write-Host "Executing purge..." -ForegroundColor Cyan
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Create a thread-safe integer array to track progress across the parallel runspace
$Counter = [System.Int32[]]::new(1)

$FilesToNuke | ForEach-Object -Parallel {
    $File = $_
    
    # Nuke the file
    if (Test-Path $File) {
        try {
            [System.IO.File]::Delete($File)
        }
        catch {
            Write-Warning "Failed to delete file (In use or permission error): $File"
        }
    }

    # Safely increment the shared counter across all active threads
    $LocalCounter = $using:Counter
    $Current = [System.Threading.Interlocked]::Increment([ref]$LocalCounter[0])
    
    # Update the console every 500 files, or when hitting the absolute end
    if ($Current % 500 -eq 0 -or $Current -eq $using:TotalFiles) {
        $Percent = [math]::Round(($Current / $using:TotalFiles) * 100, 1)
        Write-Host " [>>] Purged $Current of $($using:TotalFiles) files... ($Percent%)" -ForegroundColor Yellow
    }

} -ThrottleLimit $Throttle

$Stopwatch.Stop()
Write-Host "Purge complete! Time elapsed: $($Stopwatch.Elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor Green