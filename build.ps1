param(
    [string]$GameName = "mobize",
    [string]$LoveWinDir = "love-win",
    [string]$OutDir = "dist-windows",
    [string]$CertificateThumbprint = "",
    [string]$CertificatePath = "",
    [string]$CertificatePassword = "",
    [string]$TimestampServer = "http://timestamp.digicert.com",
    [string]$SignToolPath = ""
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$loveWinPath = Join-Path $projectRoot $LoveWinDir
$outPath = Join-Path $projectRoot $OutDir
$buildPath = Join-Path $projectRoot "build"
$loveFilePath = Join-Path $projectRoot "$GameName.love"
$exePath = Join-Path $outPath "$GameName.exe"
$loveExePath = Join-Path $loveWinPath "love.exe"

function Get-SignToolPath {
    if ($SignToolPath -and (Test-Path $SignToolPath)) {
        return $SignToolPath
    }

    $command = Get-Command signtool.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $windowsKits = "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
    if (Test-Path $windowsKits) {
        $candidate = Get-ChildItem -Path $windowsKits -Recurse -Filter signtool.exe -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match "\\x64\\signtool\.exe$" } |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($candidate) {
            return $candidate.FullName
        }
    }

    return $null
}

function Invoke-CodeSigning {
    param([string]$TargetPath)

    if (-not $CertificateThumbprint -and -not $CertificatePath) {
        Write-Host "Assinatura ignorada: informe -CertificateThumbprint ou -CertificatePath para assinar a build."
        return
    }

    $resolvedSignTool = Get-SignToolPath
    if (-not $resolvedSignTool) {
        throw "signtool.exe nao encontrado. Instale o Windows SDK ou informe -SignToolPath."
    }

    $arguments = @("sign", "/fd", "SHA256", "/tr", $TimestampServer, "/td", "SHA256")
    if ($CertificateThumbprint) {
        $arguments += @("/sha1", $CertificateThumbprint)
    }
    else {
        $arguments += @("/f", $CertificatePath)
        if ($CertificatePassword) {
            $arguments += @("/p", $CertificatePassword)
        }
    }
    $arguments += $TargetPath

    & $resolvedSignTool @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao assinar $TargetPath"
    }
}

function Update-GameVersion {
    $confPath = Join-Path $projectRoot "conf.lua"
    $content = Get-Content -LiteralPath $confPath -Raw
    $pattern = 'GAME_VERSION\s*=\s*"(\d+)\.(\d+)\.(\d+)([A-Za-z]*)"'
    $match = [regex]::Match($content, $pattern)

    if (-not $match.Success) {
        throw "GAME_VERSION nao encontrado em conf.lua"
    }

    $major = [int]$match.Groups[1].Value
    $minor = [int]$match.Groups[2].Value
    $patch = [int]$match.Groups[3].Value + 1
    $suffix = $match.Groups[4].Value
    $newVersion = "$major.$minor.$patch$suffix"
    $newEntry = "GAME_VERSION = `"$newVersion`""
    $newContent = $content.Remove($match.Index, $match.Length).Insert($match.Index, $newEntry)
    Set-Content -LiteralPath $confPath -Value $newContent -NoNewline
    Write-Host "Versao da build: $newVersion"
}

if (-not (Test-Path $loveWinPath)) {
    throw "Diretorio do LÖVE nao encontrado: $loveWinPath"
}

if (-not (Test-Path $loveExePath)) {
    throw "Arquivo nao encontrado: $loveExePath"
}

if (Test-Path $buildPath) {
    Remove-Item -LiteralPath $buildPath -Recurse -Force
}

Update-GameVersion

$includeRootFiles = @(
    'main.lua',
    'conf.lua'
)

$includeDirectories = @(
    'scripts/',
    'jumperj/',
    'assets/'
)

$allowedExtensionsByDirectory = @{
    'scripts/' = @('.lua', '.glsl')
    'jumperj/' = @('.lua')
    'assets/' = @('.png', '.mp3', '.ogg', '.wav', '.ttf', '.otf')
}

function Test-ShouldIncludeFile {
    param([string]$RelativePath)

    $normalized = $RelativePath -replace '\\', '/'
    $extension = [System.IO.Path]::GetExtension($normalized).ToLowerInvariant()

    if ($includeRootFiles -contains $normalized) {
        return $true
    }

    foreach ($directory in $includeDirectories) {
        if ($normalized.StartsWith($directory)) {
            $allowedExtensions = $allowedExtensionsByDirectory[$directory]
            return $allowedExtensions -contains $extension
        }
    }

    return $false
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

Invoke-CodeSigning -TargetPath $exePath

Get-ChildItem -Path $loveWinPath -File | Where-Object {
    $_.Extension -ieq ".dll" -or $_.Name -in @("license.txt", "LICENSE.txt", "changes.txt", "readme.txt")
} | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $outPath $_.Name) -Force
}

if (Test-Path $loveFilePath) {
    Remove-Item -LiteralPath $loveFilePath -Force
}

Write-Host "Build pronto em $outPath"
Write-Host "Executavel: $exePath"
