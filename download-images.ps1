# Vehicle Image Downloader
# This downloads all vehicle images from Discord URLs in vehicle-images.json, then adds them to a folder for easy uploading to your own file hosting (Public git-hub repo).
# Place this script in the vehicle-image-generator folder and run it

# Get the script's directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptPath

$jsonFile = "vehicle-images.json"
$outputFolder = "downloaded-images"

# Create output folder if it doesn't exist
if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
    Write-Host "Created folder: $outputFolder" -ForegroundColor Green
}

# Read the JSON file
if (-not (Test-Path $jsonFile)) {
    Write-Host "ERROR: $jsonFile not found!" -ForegroundColor Red
    Write-Host "Make sure this script is in the vehicle-image-generator folder" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit
}

try {
    $json = Get-Content $jsonFile -Raw | ConvertFrom-Json
    $vehicles = $json.PSObject.Properties
}
catch {
    Write-Host "ERROR: Failed to read $jsonFile" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

Write-Host "`nFound $($vehicles.Count) vehicles in $jsonFile" -ForegroundColor Cyan
Write-Host "Starting download...`n" -ForegroundColor Cyan

$downloaded = 0
$skipped = 0
$failed = 0

foreach ($vehicle in $vehicles) {
    $model = $vehicle.Name
    $imageUrl = $vehicle.Value.imageUrl
    
    if (-not $imageUrl) {
        Write-Host "Skipping $model (no image URL)" -ForegroundColor Gray
        $skipped++
        continue
    }
    
    $fileName = "$model.webp"
    $filePath = Join-Path $outputFolder $fileName
    
    # Skip if already exists
    if (Test-Path $filePath) {
        Write-Host "Skipping $fileName (already exists)" -ForegroundColor Gray
        $skipped++
        continue
    }
    
    try {
        Write-Host "Downloading: $fileName" -ForegroundColor Yellow
        Invoke-WebRequest -Uri $imageUrl -OutFile $filePath -ErrorAction Stop
        $downloaded++
        Write-Host "  Success!" -ForegroundColor Green
    }
    catch {
        $failed++
        Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n======================================" -ForegroundColor Cyan
Write-Host "Download Complete!" -ForegroundColor Green
Write-Host "Downloaded: $downloaded" -ForegroundColor Green
Write-Host "Skipped: $skipped" -ForegroundColor Yellow
Write-Host "Failed: $failed" -ForegroundColor Red
Write-Host "Location: $((Resolve-Path $outputFolder).Path)" -ForegroundColor Cyan
Write-Host "======================================`n" -ForegroundColor Cyan

Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Upload the 'downloaded-images' folder to your file hosting" -ForegroundColor White
Write-Host "2. Update your vehicle shop config with the image URLs" -ForegroundColor White
Write-Host "3. Use the export function to get URLs:" -ForegroundColor White
Write-Host "   exports['vehicle-image-generator']:GetVehicleImage('vehiclename')`n" -ForegroundColor Gray

Read-Host "Press Enter to exit"
