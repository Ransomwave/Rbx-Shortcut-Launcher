# Roblox Shortcut Updater
# Updates existing Roblox game shortcuts with latest game info (name, icon)

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

# Function to extract Game ID from shortcut
function Get-GameIdFromShortcut {
    param([string]$ShortcutPath)
    
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
        $targetPath = $Shortcut.TargetPath
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null
        
        # Extract placeId from roblox://placeId=123456 or roblox://placeId=123456&linkCode=...
        if ($targetPath -match 'roblox://placeId=(\d+)') {
            return $Matches[1]
        }
        return $null
    }
    catch {
        Write-Warning "Failed to read shortcut: $_"
        return $null
    }
}

# Function to update a shortcut
function Update-RobloxShortcut {
    param(
        [string]$ShortcutPath,
        [switch]$UpdateIcon = $true,
        [switch]$UpdateDescription = $true
    )
    
    Write-Host "Processing: $([System.IO.Path]::GetFileName($ShortcutPath))" -ForegroundColor Cyan
    
    # Extract Game ID
    $gameId = Get-GameIdFromShortcut -ShortcutPath $ShortcutPath
    if (-not $gameId) {
        Write-Warning "  Could not extract Game ID. Skipping."
        return $false
    }
    
    Write-Host "  Game ID: $gameId" -ForegroundColor Gray
    
    # Fetch latest game info
    Write-Host "  Fetching latest game information..." -ForegroundColor Yellow
    $gameInfo = Get-RobloxGameInfo -GameId $gameId
    
    if (-not $gameInfo) {
        Write-Warning "  Failed to retrieve game information. Skipping."
        return $false
    }
    
    Write-Host "  Current game name: $($gameInfo.Name)" -ForegroundColor Green
    
    # Read existing shortcut
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    
    $updated = $false
    
    # Update description
    if ($UpdateDescription) {
        $newDescription = "Launch $($gameInfo.Name) on Roblox"
        if ($Shortcut.Description -ne $newDescription) {
            $Shortcut.Description = $newDescription
            Write-Host "  Description updated!" -ForegroundColor Green
            $updated = $true
        }
    }
    
    # Update icon
    if ($UpdateIcon) {
        $safeName = $gameInfo.Name -replace '[\\/:*?"<>|]', '_'
        $safeName = $safeName -replace '[^\x00-\x7F]', ''
        $safeName = $safeName -replace '\s+', ' ' -replace '_+', '_' -replace '^\s+|\s+$', ''
        
        if ([string]::IsNullOrWhiteSpace($safeName)) {
            $safeName = "RobloxGame_$gameId"
        }
        
        $iconPath = Join-Path $env:TEMP "$safeName.ico"
        
        Write-Host "  Downloading latest icon..." -ForegroundColor Yellow
        $iconSuccess = Convert-ImageToIcon -ImageUrl $gameInfo.IconUrl -OutputPath $iconPath
        
        if ($iconSuccess -and (Test-Path $iconPath)) {
            $Shortcut.IconLocation = $iconPath
            Write-Host "  Icon updated!" -ForegroundColor Green
            $updated = $true
        }
        else {
            Write-Warning "  Could not update icon."
        }
    }
    
    # Save if anything changed
    if ($updated) {
        $Shortcut.Save()
        Write-Host "  [SUCCESS] Shortcut updated!" -ForegroundColor Green
    }
    else {
        Write-Host "  No changes needed." -ForegroundColor Gray
    }
    
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null
    Write-Host ""
    
    return $updated
}

# ----------------- Main script ---------------------
Write-Host "====================================" -ForegroundColor Red
Write-Host "=== Roblox Shortcut Updater =======" -ForegroundColor Red
Write-Host "====================================" -ForegroundColor Red
Write-Host ""

# Ask for directory or specific file
$mode = Read-Host "Update (1) Specific shortcut or (2) All shortcuts in a folder? [Default: 1]"

$shortcuts = @()

if ($mode -eq "2") {
    $folderPath = Read-Host "Enter folder path (Leave blank for Desktop)"
    if ([string]::IsNullOrWhiteSpace($folderPath)) {
        $folderPath = [Environment]::GetFolderPath("Desktop")
    }
    
    if (-not (Test-Path $folderPath)) {
        Write-Error "Folder not found: $folderPath"
        exit 1
    }
    
    Write-Host "Searching for Roblox shortcuts in: $folderPath" -ForegroundColor Cyan
    $allShortcuts = Get-ChildItem -Path $folderPath -Filter "*.lnk" -File
    
    # Filter only Roblox shortcuts
    foreach ($shortcut in $allShortcuts) {
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($shortcut.FullName)
        $target = $Shortcut.TargetPath
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null
        
        if ($target -match '^roblox://') {
            $shortcuts += $shortcut.FullName
        }
    }
    
    if ($shortcuts.Count -eq 0) {
        Write-Warning "No Roblox shortcuts found in $folderPath"
        exit 0
    }
    
    Write-Host "Found $($shortcuts.Count) Roblox shortcut(s)" -ForegroundColor Green
}
else {
    $shortcutPath = Read-Host "Enter full path to shortcut file"
    
    if (-not (Test-Path $shortcutPath)) {
        Write-Error "Shortcut not found: $shortcutPath"
        exit 1
    }
    
    $shortcuts += $shortcutPath
}

Write-Host ""

# Process shortcuts
$updatedCount = 0
$skippedCount = 0

foreach ($shortcut in $shortcuts) {
    $result = Update-RobloxShortcut -ShortcutPath $shortcut -UpdateIcon -UpdateDescription
    if ($result) {
        $updatedCount++
    }
    else {
        $skippedCount++
    }
}

# Summary
Write-Host "========== SUMMARY ==========" -ForegroundColor Cyan
Write-Host "Total processed: $($shortcuts.Count)" -ForegroundColor White
Write-Host "Updated: $updatedCount" -ForegroundColor Green
Write-Host "Skipped/Failed: $skippedCount" -ForegroundColor Yellow