$gameDir = "C:\Program Files (x86)\Steam\steamapps\common\GIRLS' FRONTLINE\GrilsFrontLine_Data\StreamingAssets\Res\Pc"
$modFileName = "assettextavg.ab"
$targetFilePattern = "*assettextavg.ab"
$processName = "GrilsFrontLine"
$scriptDir = $PSScriptRoot
$modApplied = $false
$handledProcessId = $null
Write-Host "Script started. Now continuously monitoring for '$processName.exe'..." -ForegroundColor Cyan
Write-Host "This script will smartly copy '$modFileName' and rename it to match the game's file." -ForegroundColor Cyan
Write-Host "------------------------------------------------------------------------------------"
$sourceFilePath = Join-Path -Path $scriptDir -ChildPath $modFileName
if (-not (Test-Path $sourceFilePath)) {
    Write-Host "FATAL ERROR: The mod file ('$modFileName') was not found in this script's directory." -ForegroundColor Red
    Read-Host -Prompt "Press Enter to exit..."
    exit
}
$sourceFile = Get-Item $sourceFilePath
$modFileHash = (Get-FileHash $sourceFile.FullName).Hash
while ($true) {
    $gameProcess = Get-Process -Name $processName -ErrorAction SilentlyContinue

    if ($gameProcess) {
        if ($gameProcess.Id -ne $handledProcessId) {
            Write-Host ""
            Write-Host "New game instance detected (PID: $($gameProcess.Id)). Starting monitoring procedure..." -ForegroundColor Cyan
            $handledProcessId = $gameProcess.Id
            $modApplied = $false
        }
        $targetFileObjects = Get-ChildItem -Path $gameDir -Filter $targetFilePattern
        if ($null -eq $targetFileObjects) {
            Write-Host -NoNewline "`rWaiting for game file to become accessible... "
            Start-Sleep -Seconds 1
            continue
        }
        if ($targetFileObjects.Count -gt 1) {
             Write-Host "WARNING: Found multiple possible game files. Using the first one: $($targetFileObjects[0].Name)" -ForegroundColor Yellow
        }
        $targetFile = $targetFileObjects[0]
        $destinationFile = $targetFile.FullName
        $liveFileHash = (Get-FileHash -Path $destinationFile -ErrorAction SilentlyContinue).Hash
        if ($null -eq $liveFileHash) {
            Write-Host -NoNewline "`rWaiting for game file lock to be released... "
            Start-Sleep -Seconds 1
            continue
        }
        if ($liveFileHash -ne $modFileHash) {
            $modApplied = $false
            Write-Host ""
            Write-Host "ACTION REQUIRED: The mod is not currently active." -ForegroundColor Yellow

            $backupFile = "$destinationFile.bak"
            if (-not (Test-Path $backupFile)) {
                Write-Host "No backup found for '$($targetFile.Name)'. Creating one now..." -ForegroundColor Yellow
                Copy-Item -Path $destinationFile -Destination $backupFile -Force
                Write-Host "Backup created: '$($backupFile)'" -ForegroundColor Green
            }

            Write-Host "Restoring your original backup to ensure a clean login..."
            Copy-Item -Path $backupFile -Destination $destinationFile -Force

            Read-Host -Prompt "Please fully log in to the game. AFTER you are logged in, press Enter here to apply the mod..."
            Write-Host "Applying mod: Copying '$($sourceFile.Name)' and renaming it to '$($targetFile.Name)'..." -ForegroundColor Cyan
            Copy-Item -Path $sourceFile.FullName -Destination $destinationFile -Force

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
            $targetFileObject = Get-ChildItem -Path $gameDir -Filter $targetFilePattern -ErrorAction SilentlyContinue
            if ($null -ne $targetFileObject) {
                $destinationFile = $targetFileObject.FullName
                $backupFile = "$destinationFile.bak"
                if(Test-Path $backupFile) {
                    Write-Host "Restoring original file from backup..."
                    Move-Item -Path $backupFile -Destination $destinationFile -Force
                    Write-Host "Original file restored successfully."
                }
            }

            Write-Host "Resetting and waiting for a new game launch..."
            Write-Host "------------------------------------------------------------------------------------"
            $handledProcessId = $null
            $modApplied = $false
        }
        Write-Host -NoNewline "."
    }

    Start-Sleep -Seconds 5
}