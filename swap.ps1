$gameDir = "C:\Program Files (x86)\Steam\steamapps\common\GIRLS' FRONTLINE\GrilsFrontLine_Data\StreamingAssets\Res\Pc"
$fileNamePattern = "*assettextavg.ab"
$processName = "GrilsFrontLine"

Write-Host "Searching for asset file in game directory using pattern: '$fileNamePattern'..."
$targetFileObject = Get-ChildItem -Path $gameDir -Filter $fileNamePattern

if ($null -eq $targetFileObject) {
    Write-Host "ERROR: No asset file matching '$fileNamePattern' was found in the game directory." -ForegroundColor Red
    Write-Host "The game may have updated, or the directory is incorrect."
    Read-Host -Prompt "Press Enter to exit."
    exit
}
if ($targetFileObject.Count -gt 1) {
    Write-Host "ERROR: Found multiple files matching the pattern. Please ensure only one exists in the game directory:" -ForegroundColor Red
    $targetFileObject.Name | ForEach-Object { Write-Host " - $_" }
    Read-Host -Prompt "Press Enter to exit."
    exit
}

$fileName = $targetFileObject.Name
Write-Host "Found target asset file: $fileName" -ForegroundColor Green

$scriptDir = $PSScriptRoot
$sourceFile = Join-Path -Path $scriptDir -ChildPath $fileName
$destinationFile = Join-Path -Path $gameDir -ChildPath $fileName
$backupFile = "$destinationFile.bak"


if (-not (Test-Path $sourceFile)) {
    Write-Host "ERROR: The game wants to replace '$fileName', but this file was not found in the script's directory." -ForegroundColor Red
    Write-Host "Please rename your new file to '$fileName' and place it in the same folder as this script."
    Read-Host -Prompt "Press Enter to exit."
    exit
}

Write-Host "Checking for game process: '$processName.exe'..."
$gameProcess = Get-Process -Name $processName -ErrorAction SilentlyContinue

while (-not $gameProcess) {
    Write-Host "Game is not running. Please start the game. Checking again in 5 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    $gameProcess = Get-Process -Name $processName -ErrorAction SilentlyContinue
}

Write-Host "Game process has been detected!" -ForegroundColor Green

if (Test-Path $backupFile) {
    Write-Host "A backup file was found. Restoring it now to ensure a clean state..."
    Move-Item -Path $backupFile -Destination $destinationFile -Force
    Write-Host "Backup has been restored." -ForegroundColor Green
} else {
    Write-Host "No backup file found. Game will start with its current file."
}

Read-Host -Prompt "Please fully log in to the game. AFTER you are logged in, answer this prompt by pressing Enter to apply the new file..."

Write-Host "Proceeding with file swap..."

if (Test-Path $destinationFile) {
    Write-Host "Backing up current live file to '$($backupFile.Split('\')[-1])'..."
    Move-Item -Path $destinationFile -Destination $backupFile -Force
    Write-Host "Backup complete." -ForegroundColor Green
}

Write-Host "Copying new file ('$fileName') to game directory..."
Copy-Item -Path $sourceFile -Destination $destinationFile -Force
Write-Host "New file has been copied successfully." -ForegroundColor Green

Write-Host ""
Write-Host "Script finished. The new file is now active."
Read-Host -Prompt "Press Enter to exit."