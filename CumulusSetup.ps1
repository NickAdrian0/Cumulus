param(
    [string]$Mode = ""
)

$ErrorActionPreference = "Stop"

$Root = $PSScriptRoot
$ScriptPath = $MyInvocation.MyCommand.Path
$DataDir = Join-Path $Root "Data"
$GameSavesDir = Join-Path $DataDir "Game_Saves"
$PlayniteBackupDir = Join-Path $DataDir "Playnite_Backup"
$ToolsDir = Join-Path $Root "Tools"
$PlayniteDir = Join-Path $ToolsDir "Playnite"
$PlayniteExe = Join-Path $PlayniteDir "Playnite.DesktopApp.exe"
$PlayniteLibraryDir = Join-Path $PlayniteDir "library"
$LudusaviDir = Join-Path $ToolsDir "Ludusavi"
$LudusaviExe = Join-Path $LudusaviDir "ludusavi.exe"
$LudusaviConfig = Join-Path $LudusaviDir "config.yaml"
$RcloneDir = Join-Path $ToolsDir "rclone"
$RcloneExe = Join-Path $RcloneDir "rclone.exe"
$RcloneConfig = Join-Path $RcloneDir "rclone.conf"
$LudusaviPluginDir = Join-Path $PlayniteDir "ExtensionsData\72e2de43-d859-44d8-914e-4277741c8208"
$LudusaviPluginConfig = Join-Path $LudusaviPluginDir "config.json"
$ShortcutPath = Join-Path $Root "Playnite (Cumulus Config).lnk"

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Set-ObjectProperty {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Value
    )

    if ($Object.PSObject.Properties.Name -contains $Name) {
        $Object.$Name = $Value
    }
    else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Quote-Yaml {
    param([string]$Value)

    return "'" + ($Value -replace "'", "''") + "'"
}

function Set-LudusaviPortablePaths {
    if (-not (Test-Path -LiteralPath $LudusaviConfig)) {
        return
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    Get-Content -LiteralPath $LudusaviConfig | ForEach-Object { [void]$lines.Add($_) }

    $top = ""
    $inRclone = $false
    $backupFound = $false
    $restoreFound = $false
    $rclonePathFound = $false
    $rcloneArgsFound = $false

    $savePath = Quote-Yaml (($GameSavesDir -replace "\\", "/"))
    $rclonePath = Quote-Yaml (($RcloneExe -replace "\\", "/"))
    $rcloneConfigPath = ($RcloneConfig -replace "\\", "/")
    $rcloneArguments = Quote-Yaml ('--fast-list --ignore-checksum --config "' + $rcloneConfigPath + '"')

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        if ($line -match '^([A-Za-z0-9_]+):(?:\s.*)?$') {
            $top = $Matches[1]
            $inRclone = $false
        }

        if ($top -eq "backup" -and $line -match '^  path:\s*') {
            $lines[$i] = "  path: $savePath"
            $backupFound = $true
            continue
        }

        if ($top -eq "restore" -and $line -match '^  path:\s*') {
            $lines[$i] = "  path: $savePath"
            $restoreFound = $true
            continue
        }

        if ($top -eq "apps" -and $line -match '^  rclone:\s*$') {
            $inRclone = $true
            continue
        }

        if ($top -eq "apps" -and $inRclone -and $line -match '^    path:\s*') {
            $lines[$i] = "    path: $rclonePath"
            $rclonePathFound = $true
            continue
        }

        if ($top -eq "apps" -and $inRclone -and $line -match '^    arguments:\s*') {
            $lines[$i] = "    arguments: $rcloneArguments"
            $rcloneArgsFound = $true
            continue
        }

        if ($top -eq "apps" -and $inRclone -and $line -match '^  [A-Za-z0-9_]+:' -and $line -notmatch '^  rclone:') {
            $inRclone = $false
        }
    }

    if (-not $backupFound -or -not $restoreFound -or -not $rclonePathFound -or -not $rcloneArgsFound) {
        throw "config.yaml do Ludusavi nao possui a estrutura esperada."
    }

    [System.IO.File]::WriteAllLines($LudusaviConfig, $lines, [System.Text.UTF8Encoding]::new($false))
}

function Set-LudusaviPluginConfig {
    if (-not (Test-Path -LiteralPath $PlayniteDir)) {
        return
    }

    Ensure-Directory $LudusaviPluginDir

    if (Test-Path -LiteralPath $LudusaviPluginConfig) {
        try {
            $settings = Get-Content -LiteralPath $LudusaviPluginConfig -Raw | ConvertFrom-Json
        }
        catch {
            $settings = [pscustomobject]@{}
        }
    }
    else {
        $settings = [pscustomobject]@{}
    }

    Set-ObjectProperty $settings "ExecutablePath" $LudusaviExe
    Set-ObjectProperty $settings "OverrideBackupPath" $true
    Set-ObjectProperty $settings "BackupPath" $GameSavesDir
    Set-ObjectProperty $settings "DoRestoreOnGameStarting" $true
    Set-ObjectProperty $settings "DoBackupOnGameStopped" $true
    Set-ObjectProperty $settings "AskBackupOnGameStopped" $false
    Set-ObjectProperty $settings "OnlyBackupOnGameStoppedIfPc" $true
    Set-ObjectProperty $settings "RetryUnrecognizedGameWithNormalization" $true

    $json = $settings | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($LudusaviPluginConfig, $json, [System.Text.UTF8Encoding]::new($false))
}

function Get-LudusaviCloudRemote {
    if (-not (Test-Path -LiteralPath $LudusaviConfig)) {
        return $null
    }

    $inCloud = $false
    $inRemote = $false

    foreach ($line in Get-Content -LiteralPath $LudusaviConfig) {
        if ($line -match '^([A-Za-z0-9_]+):(?:\s.*)?$') {
            $inCloud = $Matches[1] -eq "cloud"
            $inRemote = $false
            continue
        }

        if (-not $inCloud) {
            continue
        }

        if ($line -match '^  remote:\s*(.*)$') {
            $value = $Matches[1].Trim()

            if ($value -eq "" ) {
                $inRemote = $true
                continue
            }

            if ($value -eq "~" -or $value -eq "null") {
                return $null
            }

            return ($value.Trim("'`""))
        }

        if ($inRemote -and $line -match '^      id:\s*(.+)$') {
            return ($Matches[1].Trim().Trim("'`""))
        }

        if ($inRemote -and $line -match '^  [A-Za-z0-9_]+:' -and $line -notmatch '^  remote:') {
            $inRemote = $false
        }
    }

    return $null
}

function Invoke-RcloneCopy {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $RcloneExe) -or -not (Test-Path -LiteralPath $RcloneConfig)) {
        return $false
    }

    $arguments = @(
        "--config", $RcloneConfig,
        "copy", $Source, $Destination,
        "--retries", "1",
        "--low-level-retries", "1",
        "--contimeout", "5s",
        "--timeout", "30s"
    )

    & $RcloneExe @arguments *> $null
    return $LASTEXITCODE -eq 0
}

function Pull-PlayniteBackups {
    $remote = Get-LudusaviCloudRemote

    if ([string]::IsNullOrWhiteSpace($remote)) {
        return
    }

    Ensure-Directory $PlayniteBackupDir
    [void](Invoke-RcloneCopy "${remote}:Playnite/Backups" $PlayniteBackupDir)
}

function Push-PlayniteBackups {
    $remote = Get-LudusaviCloudRemote

    if ([string]::IsNullOrWhiteSpace($remote)) {
        return
    }

    if (-not (Test-Path -LiteralPath $PlayniteBackupDir)) {
        return
    }

    [void](Invoke-RcloneCopy $PlayniteBackupDir "${remote}:Playnite/Backups")
}

function Invoke-PlayniteBackup {
    if (-not (Test-Path -LiteralPath $PlayniteExe)) {
        throw "Playnite.DesktopApp.exe nao encontrado."
    }

    Ensure-Directory $PlayniteBackupDir
    Ensure-Directory $PlayniteLibraryDir

    Wait-ForPlayniteExit

    $configPath = Join-Path $env:TEMP ("Cumulus-Playnite-Backup-" + $PID + ".json")
    $before = @(Get-ChildItem -LiteralPath $PlayniteBackupDir -Filter "PlayniteBackup-*.zip" -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)

    $config = [ordered]@{
        DataDir = $PlayniteDir
        LibraryDir = $PlayniteLibraryDir
        OutputDir = $PlayniteBackupDir
        BackupItems = @(2, 3, 4, 5)
        ClosedWhenDone = $true
        CancelIfGameRunning = $true
        RotatingBackups = 5
    }

    try {
        $json = $config | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($configPath, $json, [System.Text.UTF8Encoding]::new($false))
        & $PlayniteExe --backup $configPath
        Wait-ForPlayniteExit
    }
    finally {
        Remove-Item -LiteralPath $configPath -Force -ErrorAction SilentlyContinue
    }

    $after = @(Get-ChildItem -LiteralPath $PlayniteBackupDir -Filter "PlayniteBackup-*.zip" -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $created = @($after | Where-Object { $_ -notin $before })

    if ($created.Count -eq 0) {
        throw "O Playnite encerrou sem criar um novo backup."
    }
}

function Restore-PlayniteIfNeeded {
    $gamesDb = Join-Path $PlayniteLibraryDir "games.db"

    if (Test-Path -LiteralPath $gamesDb) {
        return
    }

    if (-not (Test-Path -LiteralPath $PlayniteBackupDir)) {
        return
    }

    $backup = Get-ChildItem -LiteralPath $PlayniteBackupDir -Filter "PlayniteBackup-*.zip" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($null -eq $backup) {
        return
    }

    $configPath = Join-Path $env:TEMP ("Cumulus-Playnite-Restore-" + $PID + ".json")

    $config = [ordered]@{
        BackupFile = $backup.FullName
        DataDir = $PlayniteDir
        LibraryDir = $PlayniteLibraryDir
        RestoreItems = @(0, 1, 2, 3, 4, 5)
        ClosedWhenDone = $true
        CancelIfGameRunning = $true
        RestoreLibrarySettingsPath = $PlayniteLibraryDir
    }

    try {
        $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configPath -Encoding UTF8
        $process = Start-Process -FilePath $PlayniteExe -ArgumentList @("--restorebackup", "`"$configPath`"") -PassThru
        $process.WaitForExit()
    }
    finally {
        Remove-Item -LiteralPath $configPath -Force -ErrorAction SilentlyContinue
    }

    Set-LudusaviPluginConfig
}

function New-CumulusShortcut {
    if (-not (Test-Path -LiteralPath $PlayniteExe)) {
        throw "Playnite.DesktopApp.exe nao encontrado."
    }

    $powerShellExe = Join-Path $PSHOME "powershell.exe"

    if (-not (Test-Path -LiteralPath $powerShellExe)) {
        $powerShellExe = (Get-Command "powershell.exe" -ErrorAction Stop).Source
    }

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = $powerShellExe
    $shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $ScriptPath + '" -Mode Launch'
    $shortcut.WorkingDirectory = $Root
    $shortcut.IconLocation = $PlayniteExe + ",0"
    $shortcut.WindowStyle = 7
    $shortcut.Save()
}

function Initialize-Cumulus {
    Ensure-Directory $DataDir
    Ensure-Directory $GameSavesDir
    Ensure-Directory $PlayniteBackupDir

    if (-not (Test-Path -LiteralPath $PlayniteExe)) {
        throw "Playnite nao encontrado em Tools\Playnite."
    }

    if (-not (Test-Path -LiteralPath $LudusaviExe)) {
        throw "Ludusavi nao encontrado em Tools\Ludusavi."
    }

    Set-LudusaviPortablePaths
    Set-LudusaviPluginConfig
}

function Wait-ForPlayniteExit {
    do {
        Start-Sleep -Milliseconds 750
        $running = @(
            Get-Process -Name "Playnite.DesktopApp" -ErrorAction SilentlyContinue
            Get-Process -Name "Playnite.FullscreenApp" -ErrorAction SilentlyContinue
        ) | Where-Object { $null -ne $_ }
    } while ($running.Count -gt 0)
}

function Start-Cumulus {
    Initialize-Cumulus

    $alreadyRunning = Get-Process -Name "Playnite.DesktopApp" -ErrorAction SilentlyContinue

    if ($alreadyRunning) {
        return
    }

    if (-not (Test-Path -LiteralPath (Join-Path $PlayniteLibraryDir "games.db"))) {
        Pull-PlayniteBackups
        Restore-PlayniteIfNeeded
    }

    Set-LudusaviPortablePaths
    Set-LudusaviPluginConfig

    Start-Process -FilePath $PlayniteExe -WorkingDirectory $PlayniteDir | Out-Null

    $startTimeout = [System.Diagnostics.Stopwatch]::StartNew()

    do {
        Start-Sleep -Milliseconds 500

        $started = @(
            Get-Process -Name "Playnite.DesktopApp" -ErrorAction SilentlyContinue
            Get-Process -Name "Playnite.FullscreenApp" -ErrorAction SilentlyContinue
        ) | Where-Object { $null -ne $_ }

        if ($startTimeout.Elapsed.TotalSeconds -ge 30 -and $started.Count -eq 0) {
            throw "O Playnite nao iniciou dentro de 30 segundos."
        }
    } while ($started.Count -eq 0)

    $startTimeout.Stop()

    Wait-ForPlayniteExit
    Invoke-PlayniteBackup
    Push-PlayniteBackups
}

function Clear-LudusaviPersonalInfo {
    $lines = @(
        "backup:",
        "  path: ''",
        "restore:",
        "  path: ''",
        "cloud:",
        "  path: Saves",
        "  remote: ~",
        "  synchronize: true",
        "apps:",
        "  rclone:",
        "    path: ''",
        "    arguments: ''",
        "roots: []",
        "redirects: []",
        "customGames: []"
    )

    [System.IO.File]::WriteAllLines(
        $LudusaviConfig,
        $lines,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Clear-DirectoryContents {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Ensure-Directory $Path
        return
    }

    Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

function Clear-CumulusInfo {
    $running = @(
        Get-Process -Name "Playnite.DesktopApp" -ErrorAction SilentlyContinue
        Get-Process -Name "Playnite.FullscreenApp" -ErrorAction SilentlyContinue
    ) | Where-Object { $null -ne $_ }

    if ($running.Count -gt 0) {
        Write-Host ""
        Write-Host "Feche o Playnite antes de continuar."
        Read-Host "Enter"
        return
    }

    Write-Host ""
    $confirmation = Read-Host "Digite CLEAR para continuar"

    if ($confirmation -cne "CLEAR") {
        return
    }

    Clear-DirectoryContents $GameSavesDir
    Clear-DirectoryContents $PlayniteBackupDir

    Ensure-Directory $RcloneDir
    [System.IO.File]::WriteAllText($RcloneConfig, "", [System.Text.UTF8Encoding]::new($false))

    Clear-LudusaviPersonalInfo

    $playniteDirectories = @(
        "library",
        "browsercache",
        "cache",
        "User Data",
        "ExtraMetadata",
        "Backup",
        "ExtensionsData"
    )

    foreach ($name in $playniteDirectories) {
        $path = Join-Path $PlayniteDir $name
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $playniteFiles = @(
        "config.json",
        "fullscreenConfig.json",
        "windowPositions.json",
        "backup.json",
        "cef.log",
        "debug.log",
        "extensions.log",
        "playnite.log"
    )

    foreach ($name in $playniteFiles) {
        $path = Join-Path $PlayniteDir $name
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
    }

    Get-ChildItem -LiteralPath $LudusaviDir -Filter "ludusavi*.log" -File -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue

    $playniteExtensionsDir = Join-Path $PlayniteDir "Extensions"

    if (Test-Path -LiteralPath $playniteExtensionsDir) {
        Get-ChildItem `
            -LiteralPath $playniteExtensionsDir `
            -Filter "*.log" `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }


    Ensure-Directory $PlayniteLibraryDir

    Write-Host ""
    Write-Host "Clear Info concluido."
    Read-Host "Enter"
}

function Show-DebugMenu {
    while ($true) {
        Clear-Host
        Write-Host "Debug"
        Write-Host ""
        Write-Host "1. Clear Info"
        Write-Host "2. Back"
        Write-Host ""
        $choice = Read-Host ">"

        switch ($choice) {
            "1" {
                Clear-CumulusInfo
            }
            "2" {
                return
            }
        }
    }
}

function Show-MainMenu {
    while ($true) {
        Clear-Host
        Write-Host "Cumulus - By N1ckPA."
        Write-Host ""
        Write-Host "1. Setup Cumulus Launcher"
        Write-Host "2. Exit"
        Write-Host ""
        $choice = Read-Host ">"

        switch ($choice) {
            "1" {
                try {
                    Initialize-Cumulus
                    New-CumulusShortcut
                    Write-Host ""
                    Write-Host "Cumulus Launcher configurado."
                }
                catch {
                    Write-Host ""
                    Write-Host $_.Exception.Message
                }

                Read-Host "Enter"
            }
            "2" {
                return
            }
            "1233212007" {
                Show-DebugMenu
            }
        }
    }
}

function Show-LaunchError {
    param([string]$Message)

    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show($Message, "Cumulus") | Out-Null
    }
    catch {
    }
}

if ($Mode -eq "Launch") {
    try {
        Start-Cumulus
    }
    catch {
        Show-LaunchError $_.Exception.Message
        exit 1
    }

    exit 0
}

Show-MainMenu
