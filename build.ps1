param(
    [string]$GameName = "mobize",
    [string]$LoveWinDir = "love-win",
    [string]$OutDir = "dist-windows"
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$loveWinPath = Join-Path $projectRoot $LoveWinDir
$outPath = Join-Path $projectRoot $OutDir
$loveFilePath = Join-Path $projectRoot "$GameName.love"
$exePath = Join-Path $outPath "$GameName.exe"
$loveExePath = Join-Path $loveWinPath "love.exe"

if (-not (Test-Path $loveWinPath)) {
    throw "Diretorio do LÖVE nao encontrado: $loveWinPath"
}

if (-not (Test-Path $loveExePath)) {
    throw "Arquivo nao encontrado: $loveExePath"
}

$excludePatterns = @(
    '.git\',
    '.git/',
    'node_modules\',
    'node_modules/',
    '__pycache__\',
    '__pycache__/',
    'dist-windows\',
    'dist-windows/',
    'love-win\',
    'love-win/'
)

$excludeExtensions = @('.love', '.zip', '.aseprite', '.jpeg', '.jpg')

function Test-ShouldIncludeFile {
    param([string]$RelativePath)

    $normalized = $RelativePath -replace '\\', '/'

    foreach ($pattern in $excludePatterns) {
        $normalizedPattern = $pattern -replace '\\', '/'
        if ($normalized.StartsWith($normalizedPattern)) {
            return $false
        }
    }

    $extension = [System.IO.Path]::GetExtension($normalized)
    if ($excludeExtensions -contains $extension) {
        return $false
    }

    return $true
}

function Get-RelativePath {
    param(
        [string]$BasePath,
        [string]$TargetPath
    )

    $baseFullPath = [System.IO.Path]::GetFullPath($BasePath)
    if (-not $baseFullPath.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $baseFullPath += [System.IO.Path]::DirectorySeparatorChar
    }

    $targetFullPath = [System.IO.Path]::GetFullPath($TargetPath)

    $baseUri = New-Object System.Uri($baseFullPath)
    $targetUri = New-Object System.Uri($targetFullPath)

    $relativeUri = $baseUri.MakeRelativeUri($targetUri)
    return [System.Uri]::UnescapeDataString($relativeUri.ToString()) -replace '/', '\'
}

if (Test-Path $loveFilePath) {
    Remove-Item -LiteralPath $loveFilePath -Force
}

$files = Get-ChildItem -Path $projectRoot -Recurse -File | Where-Object {
    $relativePath = Get-RelativePath -BasePath $projectRoot -TargetPath $_.FullName
    Test-ShouldIncludeFile -RelativePath $relativePath
}

$zipArchive = [System.IO.Compression.ZipFile]::Open($loveFilePath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in $files) {
        $relativePath = Get-RelativePath -BasePath $projectRoot -TargetPath $file.FullName
        $entryName = $relativePath -replace '\\', '/'
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zipArchive,
            $file.FullName,
            $entryName,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
}
finally {
    $zipArchive.Dispose()
}

if (Test-Path $outPath) {
    Remove-Item -LiteralPath $outPath -Recurse -Force
}

New-Item -ItemType Directory -Path $outPath | Out-Null

$loveExeBytes = [System.IO.File]::ReadAllBytes($loveExePath)
$loveFileBytes = [System.IO.File]::ReadAllBytes($loveFilePath)
$mergedBytes = New-Object byte[] ($loveExeBytes.Length + $loveFileBytes.Length)
[System.Buffer]::BlockCopy($loveExeBytes, 0, $mergedBytes, 0, $loveExeBytes.Length)
[System.Buffer]::BlockCopy($loveFileBytes, 0, $mergedBytes, $loveExeBytes.Length, $loveFileBytes.Length)
[System.IO.File]::WriteAllBytes($exePath, $mergedBytes)

Get-ChildItem -Path $loveWinPath -File | Where-Object {
    $_.Extension -ieq ".dll" -or $_.Name -in @("license.txt", "LICENSE.txt", "changes.txt", "readme.txt")
} | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $outPath $_.Name) -Force
}

Write-Host "Build pronto em $outPath"
Write-Host "Arquivo .love: $loveFilePath"
Write-Host "Executavel: $exePath"
