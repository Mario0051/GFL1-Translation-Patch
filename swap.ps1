$gameDir = "C:\Program Files (x86)\Steam\steamapps\common\GIRLS' FRONTLINE\GrilsFrontLine_Data\StreamingAssets\Res\Pc"

$fileNamePattern = "*assettextavg.ab"

$processName = "GrilsFrontLine"

$scriptDir = $PSScriptRoot
$modApplied = $false
$handledProcessId = $null

Write-Host "Script started. Now continuously monitoring for '$processName.exe'..." -ForegroundColor Cyan
Write-Host "It will automatically detect if the game restores the original file and prompt you." -ForegroundColor Cyan
Write-Host "It will automatically create a new backup if it detects a game update." -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------------------------"

$targetFileObject = Get-ChildItem -Path $gameDir -Filter $fileNamePattern
if ($null -eq $targetFileObject -or $targetFileObject.Count -gt 1) {
    Write-Host "FATAL ERROR: Could not find a unique target file matching '$fileNamePattern' in '$gameDir'." -ForegroundColor Red
    Write-Host "Please check the path and pattern. The script will now exit." -ForegroundColor Red
    Read-Host -Prompt "Press Enter to exit..."
    exit
}
$fileName = $targetFileObject.Name
$destinationFile = $targetFileObject.FullName

$sourceFile = Join-Path -Path $scriptDir -ChildPath $fileName
$backupFile = "$destinationFile.original.bak"

if (-not (Test-Path $sourceFile)) {
    Write-Host "FATAL ERROR: The mod file '$fileName' was not found in the script's directory." -ForegroundColor Red
    Write-Host "Please add the file to the same folder as this script. The script will now exit." -ForegroundColor Red
    Read-Host -Prompt "Press Enter to exit..."
    exit
}

if (-not (Test-Path $backupFile)) {
    Write-Host "No permanent backup found. Creating one now..." -ForegroundColor Yellow
    Copy-Item -Path $destinationFile -Destination $backupFile -Force
    Write-Host "Backup created: '$($backupFile.Split('\')[-1])'" -ForegroundColor Green
}

$modFileHash = (Get-FileHash $sourceFile).Hash
$backupFileHash = (Get-FileHash $backupFile).Hash

while ($true) {
    $gameProcess = Get-Process -Name $processName -ErrorAction SilentlyContinue

    if ($gameProcess) {
        if ($gameProcess.Id -ne $handledProcessId) {
            Write-Host ""
            Write-Host "New game instance detected (PID: $($gameProcess.Id)). Starting monitoring procedure..." -ForegroundColor Cyan
            $handledProcessId = $gameProcess.Id
            $modApplied = $false
        }

        $liveFileHash = (Get-FileHash -Path $destinationFile -ErrorAction SilentlyContinue).Hash

        if ($liveFileHash -ne $modFileHash) {
            
            if ($liveFileHash -ne $backupFileHash) {
                Write-Host ""
                Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!! GAME UPDATE DETECTED !!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Yellow
                Write-Host "The live game file has been updated. A new backup will be created automatically." -ForegroundColor Yellow
                
                Write-Host "Overwriting old backup with the new game file..."
                Copy-Item -Path $destinationFile -Destination $backupFile -Force
                Write-Host "New backup created successfully." -ForegroundColor Green
                Write-Host ""
                Write-Host "----------- ACTION REQUIRED -----------" -ForegroundColor Red
                Write-Host "The script will now HALT because your mod file is likely INCOMPATIBLE." -ForegroundColor Red
                Write-Host "Please get an updated version of the mod file that matches the new game version." -ForegroundColor Red
                Write-Host "Once you have the new mod file, you can run this script again."
                Read-Host -Prompt "Press Enter to exit..."
                exit
            }

            $modApplied = $false
            Write-Host ""
            Write-Host "ACTION REQUIRED: Game is using the original file." -ForegroundColor Yellow
            Write-Host "This is normal on launch or after an integrity check/error." -ForegroundColor Yellow
            
            Read-Host -Prompt "Please fully log in to the game. AFTER you are logged in, press Enter here to apply the modded file..."

            Write-Host "Proceeding with file swap..."
            Copy-Item -Path $sourceFile -Destination $destinationFile -Force
            
            if (((Get-FileHash $destinationFile).Hash) -eq $modFileHash) {
                Write-Host "Mod file applied successfully. This game session is now handled." -ForegroundColor Green
                Write-Host "------------------------------------------------------------------------------------"
                Write-Host "Monitoring for any changes by the game..."
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
            Write-Host "Game process has closed. Restoring original file from backup..." -ForegroundColor Yellow
            Copy-Item -Path $backupFile -Destination $destinationFile -Force
            Write-Host "Original file restored. Resetting and waiting for a new launch..." -ForegroundColor Green
            Write-Host "------------------------------------------------------------------------------------"
            $handledProcessId = $null
            $modApplied = $false
        }
        Write-Host -NoNewline "."
    }

    Start-Sleep -Seconds 5
}
