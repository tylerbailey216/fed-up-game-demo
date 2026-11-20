param([switch]$Zen, [switch]$Outerbelt, [switch]$PresentationCheck)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $PSScriptRoot 'Godot_v4.5.1-stable_win64.exe'
$consoleEngine = Join-Path $PSScriptRoot 'Godot_v4.5.1-stable_win64_console.exe'
$importLog = Join-Path $PSScriptRoot 'startup-import.log'
$importErrors = Join-Path $PSScriptRoot 'startup-import-errors.log'
try {
    # Source mirrors intentionally exclude .godot. Prepare imports on this drive
    # before preloaded fonts, artwork and meshes are needed by the game script.
    $prepare = Start-Process -FilePath $consoleEngine -WorkingDirectory $projectRoot -WindowStyle Hidden -ArgumentList @('--headless', '--editor', '--path', ('"' + $projectRoot + '"'), '--import', '--quit') -RedirectStandardOutput $importLog -RedirectStandardError $importErrors -PassThru -Wait
    $diagnostics = (Get-Content -LiteralPath $importLog -Raw) + (Get-Content -LiteralPath $importErrors -Raw)
    if ($prepare.ExitCode -ne 0 -or $diagnostics -match 'SCRIPT ERROR:|Parse Error:|Failed loading resource:|Failed to import') {
        throw "Could not prepare game assets. See $importLog and $importErrors."
    }
    $gameArguments = @('--path', ('"' + $projectRoot + '"'))
    if ($Zen -or $Outerbelt -or $PresentationCheck) { $gameArguments += '--' }
    if ($Zen) { $gameArguments += '--zen' }
    if ($Outerbelt) { $gameArguments += '--outerbelt' }
    if ($PresentationCheck) { $gameArguments += '--presentation-check' }
    $game = Start-Process -FilePath $engine -WorkingDirectory $projectRoot -ArgumentList $gameArguments -PassThru
    if ($PresentationCheck) { $game.WaitForExit(); exit $game.ExitCode }
} catch {
    if ($PresentationCheck) { throw }
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'FedUp Driver could not start', 'OK', 'Error') | Out-Null
    exit 1
}
