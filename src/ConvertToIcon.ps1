# Convert-ImageToIcon.ps1
# Function to download and convert image to high-quality ICO format

function Convert-ImageToIcon {
    param(
        [string]$ImageUrl,
        [string]$OutputPath
    )
    
    try {
        # Download the image with proper headers for faster download
        Write-Host "  [1/3] Downloading image... (Might take a bit)" -ForegroundColor Gray
        $downloadTimer = [System.Diagnostics.Stopwatch]::StartNew()
        
        $tempImage = [System.IO.Path]::GetTempFileName() + ".png"
        # $headers = @{
        #     'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        # }
        Invoke-WebRequest -Uri $ImageUrl -OutFile $tempImage -Headers $headers -UseBasicParsing
        
        $downloadTimer.Stop()
        Write-Host "  Downloaded in $([math]::Round($downloadTimer.Elapsed.TotalSeconds, 2))s" -ForegroundColor Gray
        
        # Load System.Drawing assembly
        Add-Type -AssemblyName System.Drawing
        
        Write-Host "  [2/3] Converting to ICO format..." -ForegroundColor Gray
        $convertTimer = [System.Diagnostics.Stopwatch]::StartNew()
        
        # Load the original image
        $originalImage = [System.Drawing.Image]::FromFile($tempImage)
        
        # Use fewer sizes for faster conversion - just the essential ones (256, 48, 32, 16)
        $sizes = @(256, 48, 32, 16)
        
        # Create MemoryStream for ICO
        $memoryStream = New-Object System.IO.MemoryStream
        $binaryWriter = New-Object System.IO.BinaryWriter($memoryStream)
        
        # ICO header
        $binaryWriter.Write([UInt16]0)      # Reserved (must be 0)
        $binaryWriter.Write([UInt16]1)      # Image type (1 = ICO)
        $binaryWriter.Write([UInt16]$sizes.Length)  # Number of images
        
        # Store image data
        $imageDataList = @()
        
        foreach ($size in $sizes) {
            # Create bitmap with high quality settings
            $bitmap = New-Object System.Drawing.Bitmap $size, $size
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            
            # Set high quality rendering
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            
            # Draw the resized image
            $graphics.DrawImage($originalImage, 0, 0, $size, $size)
            $graphics.Dispose()
            
            # Save bitmap to PNG in memory
            $pngStream = New-Object System.IO.MemoryStream
            $bitmap.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
            $imageData = $pngStream.ToArray()
            $pngStream.Dispose()
            $bitmap.Dispose()
            
            $imageDataList += @{
                Size = $size
                Data = $imageData
            }
        }
        
        # Calculate offset for first image data
        $offset = 6 + ($sizes.Length * 16)
        
        # Write image directory entries
        foreach ($imageInfo in $imageDataList) {
            $size = $imageInfo.Size
            $data = $imageInfo.Data
            
            # Width and height (0 means 256)
            $sizeValue = if ($size -eq 256) { 0 } else { $size }
            
            $binaryWriter.Write([Byte]$sizeValue)                   # Width (0 = 256)
            $binaryWriter.Write([Byte]$sizeValue)                   # Height (0 = 256)
            $binaryWriter.Write([Byte]0)                            # Color palette (0 = no palette)
            $binaryWriter.Write([Byte]0)                            # Reserved
            $binaryWriter.Write([UInt16]1)                          # Color planes
            $binaryWriter.Write([UInt16]32)                         # Bits per pixel
            $binaryWriter.Write([UInt32]$data.Length)               # Size of image data
            $binaryWriter.Write([UInt32]$offset)                    # Offset to image data
            
            $offset += $data.Length
        }
        
        # Write image data
        foreach ($imageInfo in $imageDataList) {
            $binaryWriter.Write($imageInfo.Data)
        }
        
        # Save to file
        $binaryWriter.Flush()
        [System.IO.File]::WriteAllBytes($OutputPath, $memoryStream.ToArray())
        
        $convertTimer.Stop()
        Write-Host "  Converted in $([math]::Round($convertTimer.Elapsed.TotalSeconds, 2))s" -ForegroundColor Gray
        Write-Host "  [3/3] Cleaning up..." -ForegroundColor Gray
        
        # Cleanup
        $binaryWriter.Close()
        $memoryStream.Close()
        $originalImage.Dispose()
        Remove-Item $tempImage -Force
        
        return $true
    }
    catch {
        Write-Warning "Failed to convert image to icon: $_"
        Remove-Item $tempImage -Force -ErrorAction SilentlyContinue
        return $false
    }
}
