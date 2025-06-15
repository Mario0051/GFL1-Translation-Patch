$gameDir = "C:\Program Files (x86)\Steam\steamapps\common\GIRLS' FRONTLINE\GrilsFrontLine_Data\StreamingAssets\Res\Pc"
$fileNamePattern = "*assettextavg.ab"
$processName = "GrilsFrontLine"

$scriptDir = $PSScriptRoot
$modApplied = $false
$handledProcessId = $null
$waitingForFile = $false

Write-Host "Script started. Now continuously monitoring for '$processName.exe'..." -ForegroundColor Cyan
Write-Host "This version is designed to wait for temporary file locks to be released." -ForegroundColor Cyan
Write-Host "------------------------------------------------------------------------------------"

$sourceFileObject = Get-ChildItem -Path $scriptDir -Filter $fileNamePattern
if ($null -eq $sourceFileObject) {
    Write-Host "FATAL ERROR: The mod file ('$fileNamePattern') was not found in the script's directory." -ForegroundColor Red
    Read-Host -Prompt "Press Enter to exit..."
    exit
}
$sourceFile = $sourceFileObject.FullName
$modFileHash = (Get-FileHash $sourceFile).Hash

while ($true) {
    $gameProcess = Get-Process -Name $processName -ErrorAction SilentlyContinue

    if ($gameProcess) {
        if ($gameProcess.Id -ne $handledProcessId) {
            Write-Host ""
            Write-Host "New game instance detected (PID: $($gameProcess.Id)). Starting monitoring procedure..." -ForegroundColor Cyan
            $handledProcessId = $gameProcess.Id
            $modApplied = $false
        }

        $targetFileObject = Get-ChildItem -Path $gameDir -Filter $fileNamePattern
        if ($null -eq $targetFileObject) {
            Write-Host -NoNewline "`rWaiting for game file to become accessible... "
            $waitingForFile = $true
            Start-Sleep -Seconds 1
            continue
        }
        
        if ($waitingForFile) { Write-Host ""; $waitingForFile = $false; }
        
        $destinationFile = $targetFileObject.FullName
        $liveFileHash = (Get-FileHash -Path $destinationFile -ErrorAction SilentlyContinue).Hash
        
        if ($null -eq $liveFileHash) {
            Write-Host -NoNewline "`rWaiting for game file lock to be released... "
            $waitingForFile = $true
            Start-Sleep -Seconds 1
            continue 
        }

        if ($liveFileHash -ne $modFileHash) {
            
            $modApplied = $false
            Write-Host ""
            Write-Host "ACTION REQUIRED: The mod is not currently active." -ForegroundColor Yellow
            
            $backupFile = "$destinationFile.bak"

            if (-not (Test-Path $backupFile)) {
                Write-Host "No backup found for '$($targetFileObject.Name)'. Creating one now..." -ForegroundColor Yellow
                Copy-Item -Path $destinationFile -Destination $backupFile -Force
                Write-Host "Backup created." -ForegroundColor Green
            }
            
            Write-Host "Restoring your original backup to ensure a clean login..."
            Copy-Item -Path $backupFile -Destination $destinationFile -Force

            Read-Host -Prompt "Please fully log in to the game. AFTER you are logged in, press Enter here to apply the modded file..."

            Write-Host "Proceeding with file swap..."
            Copy-Item -Path $sourceFile -Destination $destinationFile -Force
            
            if (((Get-FileHash $destinationFile).Hash) -eq $modFileHash) {
                Write-Host "Mod file applied successfully. Monitoring for changes..." -ForegroundColor Green
                Write-Host "------------------------------------------------------------------------------------"
                $modApplied = $true
            } else {
                Write-Host "ERROR: File swap failed. Hashes do not match after copy. Check permissions." -ForegroundColor Red
            }
        }
        else {
            if (-not $modApplied) {
                Write-Host ""
                Write-Host "Mod is active. Monitoring for changes..." -ForegroundColor Green
                $modApplied = $true
            }
        }
    }
    else {
        if ($handledProcessId -ne $null) {
            Write-Host ""
            Write-Host "Game process has closed." -ForegroundColor Yellow
            
            $targetFileObject = Get-ChildItem -Path $gameDir -Filter $fileNamePattern
            if ($null -ne $targetFileObject) {
                $destinationFile = $targetFileObject.FullName
                $backupFile = "$destinationFile.original.bak"
                if(Test-Path $backupFile) {
                    Write-Host "Restoring original file from backup..."
                    Copy-Item -Path $backupFile -Destination $destinationFile -Force
                    Write-Host "Original file restored."
                }
            }
            
            Write-Host "Resetting and waiting for a new launch..."
            Write-Host "------------------------------------------------------------------------------------"
            $handledProcessId = $null
            $modApplied = $false
        }
        Write-Host -NoNewline "."
    }

    Start-Sleep -Seconds 5
}
