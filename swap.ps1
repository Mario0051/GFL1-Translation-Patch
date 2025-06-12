$gameDir = "C:\Program Files (x86)\Steam\steamapps\common\GIRLS' FRONTLINE\GrilsFrontLine_Data\StreamingAssets\Res\Pc"
$fileNamePattern = "*assettextavg.ab"
$processName = "GrilsFrontLine"

$handledProcessId = $null

Write-Host "Script started. Now continuously monitoring for '$processName.exe'..." -ForegroundColor Cyan
Write-Host "You can leave this window open. It will act automatically when a new game process starts." -ForegroundColor Cyan
Write-Host "------------------------------------------------------------------------------------"

while ($true) {
    $gameProcess = Get-Process -Name $processName -ErrorAction SilentlyContinue

    if ($gameProcess) {
        if ($gameProcess.Id -ne $handledProcessId) {
            Write-Host ""
            Write-Host "New game instance detected (PID: $($gameProcess.Id)). Starting procedure..." -ForegroundColor Cyan

            $targetFileObject = Get-ChildItem -Path $gameDir -Filter $fileNamePattern
            if ($null -eq $targetFileObject -or $targetFileObject.Count -gt 1) {
                Write-Host "ERROR: Could not find a unique target file. Check previous error messages. Skipping..." -ForegroundColor Red
                Start-Sleep -Seconds 10 # Wait before next check
                continue # Skip to the next iteration of the while loop
            }
            $fileName = $targetFileObject.Name
            Write-Host "Found target asset file: $fileName" -ForegroundColor Green

            $scriptDir = $PSScriptRoot
            $sourceFile = Join-Path -Path $scriptDir -ChildPath $fileName
            $destinationFile = Join-Path -Path $gameDir -ChildPath $fileName
            $backupFile = "$destinationFile.bak"

            if (-not (Test-Path $sourceFile)) {
                Write-Host "ERROR: Game wants to replace '$fileName', but this file was not found in the script's directory." -ForegroundColor Red
                Write-Host "Please add the file and the script will try again on the next game launch."
                $handledProcessId = $gameProcess.Id # Mark as handled to prevent spamming this error
                continue
            }

            if (Test-Path $backupFile) {
                Write-Host "A backup file was found. Restoring it now..."
                Move-Item -Path $backupFile -Destination $destinationFile -Force
                Write-Host "Backup restored." -ForegroundColor Green
            }

            Read-Host -Prompt "Please fully log in to the game. AFTER you are logged in, press Enter here to apply the new file..."

            Write-Host "Proceeding with file swap..."
            if (Test-Path $destinationFile) {
                Write-Host "Backing up current live file..."
                Move-Item -Path $destinationFile -Destination $backupFile -Force
                Write-Host "Backup complete." -ForegroundColor Green
            }
            Write-Host "Copying new file ('$fileName') to game directory..."
            Copy-Item -Path $sourceFile -Destination $destinationFile -Force
            Write-Host "New file copied successfully. This game session is now handled." -ForegroundColor Green

            $handledProcessId = $gameProcess.Id
            Write-Host "------------------------------------------------------------------------------------"
            Write-Host "Monitoring for game closure or a new instance..."
        }
    }
    else {
        if ($handledProcessId -ne $null) {
            Write-Host ""
            Write-Host "Game process has closed. Resetting and waiting for a new launch..." -ForegroundColor Yellow
            $handledProcessId = $null
        }
        Write-Host -NoNewline "."
    }

    Start-Sleep -Seconds 5
}
