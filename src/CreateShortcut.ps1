# Roblox Game Shortcut Creator
# Simple script that creates desktop shortcuts for Roblox games, as if they were real apps installed on your PC.

# Import the png->ico conversion function
. "$PSScriptRoot\ConvertToIcon.ps1"

# Function to get game information from Roblox API
function Get-RobloxGameInfo {
    param([string]$GameId)
    
    try {
        $headers = @{
            'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        }
        
        # The ID from the URL is the Place ID, use it directly
        # Get place details which will give us the universe ID
        $placeUrl = "https://apis.roblox.com/universes/v1/places/$GameId/universe"
        $placeResponse = Invoke-RestMethod -Uri $placeUrl -Method Get -Headers $headers -UseBasicParsing
        
        $universeId = $placeResponse.universeId
        
        # Get game details using Universe ID
        $gameUrl = "https://games.roblox.com/v1/games?universeIds=$universeId"
        $gameResponse = Invoke-RestMethod -Uri $gameUrl -Method Get -Headers $headers -UseBasicParsing
        
        if ($gameResponse.data.Count -eq 0) {
            throw "Game not found with ID: $GameId"
        }
        
        $gameData = $gameResponse.data[0]
        $gameName = $gameData.name
        
        # Get game icon using Universe ID
        $iconUrl = "https://thumbnails.roblox.com/v1/games/icons?universeIds=$universeId&returnPolicy=PlaceHolder&size=256x256&format=Png&isCircular=false"
        $iconResponse = Invoke-RestMethod -Uri $iconUrl -Method Get -Headers $headers -UseBasicParsing
        
        $iconImageUrl = $iconResponse.data[0].imageUrl
        
        return @{
            Name    = $gameName
            IconUrl = $iconImageUrl
            PlaceId = $GameId
        }
    }
    catch {
        Write-Error "Failed to fetch game information: $_"
        return $null
    }
}

# ----------------- Main script ---------------------
Write-Host "====================================" -ForegroundColor Red
Write-Host "=== Roblox Game Shortcut Creator ===" -ForegroundColor Red
Write-Host "====================================" -ForegroundColor Red
Write-Host ""

# Get Game ID from user
$GameId = Read-Host "Enter Roblox Game ID (from game URL)"

# Get output path from user
Write-Host ""
$useDesktop = Read-Host "Save to Desktop? (Y/N) [Default: Y]"
if ($useDesktop -eq "" -or $useDesktop -eq "Y" -or $useDesktop -eq "y") {
    $OutputPath = [Environment]::GetFolderPath("Desktop")
}
else {
    $OutputPath = Read-Host "Enter full path where shortcut should be saved"
    if (-not (Test-Path $OutputPath)) {
        Write-Warning "Path does not exist. Creating directory..."
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
}

Write-Host ""

# Validate Game ID
if (-not ($GameId -match '^\d+$')) {
    Write-Error "Invalid Game ID. Please enter a numeric value."
    exit 1
}

Write-Host "Fetching game information..." -ForegroundColor Yellow

# Fetch game info
$gameInfo = Get-RobloxGameInfo -GameId $GameId

if (-not $gameInfo) {
    Write-Error "Failed to retrieve game information. Please check the Game ID and try again."
    exit 1
}

Write-Host "Game found: $($gameInfo.Name)" -ForegroundColor Green
Write-Host ""

# Ask for custom shortcut name
$customName = Read-Host "Custom shortcut name? (Leave blank to use game name)"
if ([string]::IsNullOrWhiteSpace($customName)) {
    $safeName = $gameInfo.Name
}
else {
    $safeName = $customName
}

# Remove invalid characters and emojis
$safeName = $safeName -replace '[\\/:*?"<>|]', '_'
$safeName = $safeName -replace '[^\x00-\x7F]', ''
$safeName = $safeName -replace '\s+', ' ' -replace '_+', '_' -replace '^\s+|\s+$', '' # Trim spaces and underscores

if ([string]::IsNullOrWhiteSpace($safeName)) {
    $safeName = "RobloxGame_$GameId"
}

$shortcutPath = Join-Path $OutputPath "$safeName.lnk"

# Check for duplicate shortcut
if (Test-Path $shortcutPath) {
    Write-Warning "Shortcut already exists at: $shortcutPath"
    $overwrite = Read-Host "Do you want to overwrite it? (Y/N) [Default: N]"
    if ($overwrite -ne "Y" -and $overwrite -ne "y") {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit 0
    }
    Write-Host "Overwriting existing shortcut..." -ForegroundColor Yellow
}
$iconPath = Join-Path $env:TEMP "$safeName.ico"

# Download and convert icon from png to ico
Write-Host "Downloading game icon..." -ForegroundColor Yellow
$iconSuccess = Convert-ImageToIcon -ImageUrl $gameInfo.IconUrl -OutputPath $iconPath

# Create shortcut
Write-Host "Creating shortcut..." -ForegroundColor Yellow
$WshShell = New-Object -ComObject WScript.Shell # Create COM object
$Shortcut = $WshShell.CreateShortcut($shortcutPath) # Use that same COM object to create the shortcut

# Set shortcut properties
$Shortcut.TargetPath = "roblox://placeId=$($gameInfo.PlaceId)"
$Shortcut.Description = "Launch $($gameInfo.Name) on Roblox"
$Shortcut.WorkingDirectory = $OutputPath

# Set icon if downloaded
if ($iconSuccess -and (Test-Path $iconPath)) {
    $Shortcut.IconLocation = $iconPath
    Write-Host "Icon applied successfully" -ForegroundColor Green
}
else {
    Write-Warning "Could not apply custom icon. Using default icon."
}

# Save shortcut
$Shortcut.Save()

Write-Host ""
Write-Host "[SUCCESS] Shortcut created successfully!" -ForegroundColor Green
Write-Host "Location: $shortcutPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Note: The icon file is saved at: $iconPath" -ForegroundColor Gray
Write-Host "      Keep this file to maintain the custom icon." -ForegroundColor Gray

# Cleanup shortcut creation COM object to avoid memory leaks
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null
