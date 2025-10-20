# Roblox Game Shortcut Creator
# Simple script that creates desktop shortcuts for Roblox games, as if they were real apps installed on your PC.

# Import the png->ico conversion function
. "$PSScriptRoot\ConvertToIcon.ps1"

# Function to get game information from Roblox API with retry logic
function Get-RobloxGameInfo {
    param(
        [string]$GameId,
        [int]$MaxRetries = 3,
        [int]$RetryDelaySeconds = 2
    )
    
    $attempt = 0
    while ($attempt -lt $MaxRetries) {
        try {
            $attempt++
            if ($attempt -gt 1) {
                Write-Host "Retry attempt $attempt of $MaxRetries..." -ForegroundColor Yellow
                Start-Sleep -Seconds $RetryDelaySeconds
            }
            
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
            if ($attempt -ge $MaxRetries) {
                Write-Error "Failed to fetch game information after $MaxRetries attempts: $_"
                return $null
            }
            Write-Warning "Attempt $attempt failed: $_"
        }
    }
    return $null
}

# Function to create a single shortcut
function New-RobloxShortcut {
    param(
        [string]$GameId,
        [string]$OutputPath,
        [string]$CustomName = "",
        [string]$PrivateServerCode = ""
    )
    
    Write-Host "Fetching game information for ID: $GameId..." -ForegroundColor Yellow
    
    # Fetch game info with retry logic
    $gameInfo = Get-RobloxGameInfo -GameId $GameId
    
    if (-not $gameInfo) {
        Write-Error "Failed to retrieve game information for ID: $GameId. Skipping..."
        return $false
    }
    
    Write-Host "Game found: $($gameInfo.Name)" -ForegroundColor Green
    
    # Determine shortcut name
    if ([string]::IsNullOrWhiteSpace($CustomName)) {
        $safeName = $gameInfo.Name
    }
    else {
        $safeName = $CustomName
    }
    
    # Sanitize filename: Remove emojis, brackets, and invalid characters
    # Step 1: Remove non-ASCII characters (emojis)
    $safeName = $safeName -replace '[^\x00-\x7F]', ''
    
    # Step 2: Remove empty brackets [] that result from emoji removal
    $safeName = $safeName -replace '\[\s*\]', ''
    
    # Step 3: Remove leading brackets with content (e.g., [FALL], [UPDATE])
    $safeName = $safeName -replace '^\s*\[[^\]]*\]\s*', ''
    
    # Step 4: Remove invalid filename characters
    $safeName = $safeName -replace '[\\/:*?"<>|]', '_'
    
    # Step 5: Clean up multiple spaces/underscores and trim
    $safeName = $safeName -replace '\s+', ' ' -replace '_+', '_' -replace '^\s+|\s+$', ''
    
    if ([string]::IsNullOrWhiteSpace($safeName)) {
        $safeName = "RobloxGame_$GameId"
    }
    
    $shortcutPath = Join-Path $OutputPath "$safeName.lnk"
    
    # Check for duplicate shortcut
    if (Test-Path $shortcutPath) {
        Write-Warning "Shortcut already exists: $safeName.lnk"
        $overwrite = Read-Host "  Overwrite? (Y/N) [Default: N]"
        if ($overwrite -ne "Y" -and $overwrite -ne "y") {
            Write-Host "  Skipped." -ForegroundColor Yellow
            return $false
        }
        Write-Host "  Overwriting..." -ForegroundColor Yellow
    }
    
    $iconPath = Join-Path $env:TEMP "$safeName.ico"
    
    # Download and convert icon
    Write-Host "Downloading game icon..." -ForegroundColor Yellow
    $iconSuccess = Convert-ImageToIcon -ImageUrl $gameInfo.IconUrl -OutputPath $iconPath
    
    # Create shortcut
    Write-Host "Creating shortcut..." -ForegroundColor Yellow
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcutPath)
    
    # Build target URL with optional private server code
    if ([string]::IsNullOrWhiteSpace($PrivateServerCode)) {
        $Shortcut.TargetPath = "roblox://placeId=$($gameInfo.PlaceId)"
    }
    else {
        $Shortcut.TargetPath = "roblox://placeId=$($gameInfo.PlaceId)&linkCode=$PrivateServerCode"
    }
    
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
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null
    
    Write-Host "[SUCCESS] $safeName.lnk created!" -ForegroundColor Green
    Write-Host "Location: $shortcutPath" -ForegroundColor Cyan
    Write-Host ""
    
    return $true
}

# ----------------- Main script ---------------------
Write-Host "====================================" -ForegroundColor Red
Write-Host "=== Roblox Game Shortcut Creator ===" -ForegroundColor Red
Write-Host "====================================" -ForegroundColor Red
Write-Host ""

# Ask for batch or single mode
$batchMode = Read-Host "Create multiple shortcuts? (Y/N) [Default: N]"
$isBatchMode = ($batchMode -eq "Y" -or $batchMode -eq "y")

# Get Game IDs
if ($isBatchMode) {
    Write-Host ""
    Write-Host "Enter Game IDs separated by commas (e.g., 123456,789012,345678)" -ForegroundColor Cyan
    $GameIdsInput = Read-Host "Game IDs"
    $GameIds = $GameIdsInput -split ',' | ForEach-Object { $_.Trim() }
}
else {
    $GameId = Read-Host "Enter Roblox Game ID (from game URL)"
    $GameIds = @($GameId)
}

# Get output path
Write-Host ""
$useDesktop = Read-Host "Save to Desktop? (Y/N) [Default: Y]"
if ($useDesktop -eq "" -or $useDesktop -eq "Y" -or $useDesktop -eq "y") {
    $OutputPath = [Environment]::GetFolderPath("Desktop")
}
else {
    $OutputPath = Read-Host "Enter full path where shortcuts should be saved"
    if (-not (Test-Path $OutputPath)) {
        Write-Warning "Path does not exist. Creating directory..."
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
}

Write-Host ""

# Validate all Game IDs
$validGameIds = @()
foreach ($id in $GameIds) {
    if ($id -match '^\d+$') {
        $validGameIds += $id
    }
    else {
        Write-Warning "Invalid Game ID skipped: $id"
    }
}

if ($validGameIds.Count -eq 0) {
    Write-Error "No valid Game IDs provided."
    exit 1
}

Write-Host "Processing $($validGameIds.Count) game(s)..." -ForegroundColor Cyan
Write-Host ""

# Process each game
$successCount = 0
$failCount = 0

foreach ($gameId in $validGameIds) {
    Write-Host "--- Processing Game ID: $gameId ---" -ForegroundColor Magenta
    
    # Ask for custom name and private server
    $customName = ""
    $privateServer = ""
    
    if (-not $isBatchMode) {
        $customName = Read-Host "Custom shortcut name? (Leave blank to use game name)"
        $privateServer = Read-Host "Private server link code? (Leave blank for public server)"
    }
    
    $result = New-RobloxShortcut -GameId $gameId -OutputPath $OutputPath -CustomName $customName -PrivateServerCode $privateServer
    
    if ($result) {
        $successCount++
    }
    else {
        $failCount++
    }
    
    Write-Host ""
}

# Summary
Write-Host "========== SUMMARY ==========" -ForegroundColor Cyan
Write-Host "Total processed: $($validGameIds.Count)" -ForegroundColor White
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor Red
Write-Host ""
Write-Host "Note: Icon files are saved in: $env:TEMP" -ForegroundColor Gray
Write-Host "      Keep these files to maintain custom icons." -ForegroundColor Gray