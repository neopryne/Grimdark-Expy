# Build.ps1

# Variables
$relativeFile = "Grimdark_Expy.zip"
$absolutePath = "C:\Users\GunBuild-1\Documents\Workspace\ftlman-x86_64-pc-windows-gnu\ftlman\mods\$relativeFile"
$tempZipDir = Join-Path $env:TEMP "zip_temp"
$filesToInclude = @("data", "mod-appendix", "img", "audio")

# Prepare temporary folder
if (-Not (Test-Path $tempZipDir)) {
    New-Item -ItemType Directory -Path $tempZipDir | Out-Null
}

# Copy files and folders
foreach ($item in $filesToInclude) {
    if (Test-Path $item) {
        $dest = Join-Path $tempZipDir (Split-Path $item -Leaf)
        if ((Get-Item $item).PSIsContainer) {
            Copy-Item -Recurse -Force $item -Destination $dest
        } else {
            Copy-Item -Force $item -Destination $tempZipDir
        }
    } else {
        Write-Host "File or folder not found: $item"
    }
}

# Create zip
$zipPath = Join-Path (Get-Location) $relativeFile
Compress-Archive -Force -Path "$tempZipDir\*" -DestinationPath $zipPath

# Cleanup temp
Remove-Item -Recurse -Force $tempZipDir
Write-Host "Zip file created: $relativeFile"

# Copy zip to absolute path
if (Test-Path $relativeFile) {
    Copy-Item -Force $relativeFile -Destination $absolutePath
    Write-Host "File copied successfully to $absolutePath"
} else {
    Write-Host "Source file not found: $relativeFile"
    exit 1
}

# Run patching command
$ftlmanDir = "C:\Users\GunBuild-1\Documents\Workspace\ftlman-x86_64-pc-windows-gnu\ftlman"
Push-Location $ftlmanDir
.\ftlman.exe hyperspace-install latest
.\ftlman.exe patch `
    "Multiverse 5.5 - Assets (Patch above Data).zip" `
    "Multiverse 5.5 - Data.zip" `
    "Vertex-Util.ftl" `
	"Brightness Particles 1.4.1.zip" `
	"Lightweight Lua.zip" `
    "show_room_numbers.zip" `
    "Crew_Equipment_Library.zip" `
    $relativeFile
Pop-Location

# Launch FTL
Start-Process -FilePath "C:\Program Files (x86)\Steam\steamapps\common\FTL Faster Than Light\FTLGame.exe"