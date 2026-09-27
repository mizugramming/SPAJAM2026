# Open two independent participants without changing the normal browser profile.
# Run from Windows PowerShell: .\tool\open_presentation_windows.ps1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Run this script in Windows PowerShell on the recording PC.'
}

function Find-PresentationBrowser {
    param([Parameter(Mandatory = $true)][string]$LocalDataDirectory)

    $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $LocalDataDirectory)
    $browsers = @(
        @{ Name = 'Chrome'; RelativePath = 'Google\Chrome\Application\chrome.exe'; Command = 'chrome.exe' },
        @{ Name = 'Edge'; RelativePath = 'Microsoft\Edge\Application\msedge.exe'; Command = 'msedge.exe' }
    )
    foreach ($browser in $browsers) {
        foreach ($root in $roots) {
            if ([string]::IsNullOrWhiteSpace($root)) { continue }
            $candidate = Join-Path $root $browser.RelativePath
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return @{ Name = $browser.Name; Path = $candidate }
            }
        }
        $command = Get-Command $browser.Command -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($null -ne $command) {
            return @{ Name = $browser.Name; Path = $command.Source }
        }
    }
    throw 'Chrome or Microsoft Edge was not found. No browser was installed or changed.'
}

$localDataDirectory = [Environment]::GetFolderPath('LocalApplicationData')
if ([string]::IsNullOrWhiteSpace($localDataDirectory)) {
    throw 'The Windows LocalApplicationData directory is unavailable.'
}
$browser = Find-PresentationBrowser -LocalDataDirectory $localDataDirectory
$profileRoot = Join-Path (Join-Path $localDataDirectory 'TsunagunPresentation') $browser.Name
$presentationUrl = 'https://tsunagun.tsunagun-room-server.workers.dev'

Add-Type -AssemblyName System.Windows.Forms
$area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$margin = 8
$gap = 12
$availableWidth = $area.Width - (2 * $margin) - $gap
$leftWidth = [int][Math]::Floor($availableWidth / 2)
$rightWidth = $availableWidth - $leftWidth
$windowHeight = $area.Height - (2 * $margin)
if ($leftWidth -lt 360 -or $windowHeight -lt 480) {
    throw 'The primary screen working area is too small for two recording windows. Use a larger desktop area.'
}
$top = $area.Top + $margin
$windows = @(
    @{ Name = 'ParticipantA'; Left = $area.Left + $margin; Width = $leftWidth },
    @{ Name = 'ParticipantB'; Left = $area.Left + $margin + $leftWidth + $gap; Width = $rightWidth }
)

# Read only: never close an existing browser or alter its arguments/profile.
# Fail before launching if running processes cannot be checked safely.
$runningBrowsers = @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'chrome.exe' OR Name = 'msedge.exe'")
foreach ($window in $windows) {
    $profileDirectory = Join-Path $profileRoot $window.Name
    $profilePattern = '(?i)--user-data-dir(?:=|\s+)"?' +
        [Regex]::Escape($profileDirectory) + '(?:"|\s|$)'
    $alreadyRunning = @($runningBrowsers | Where-Object {
        $null -ne $_.CommandLine -and $_.CommandLine -match $profilePattern
    }).Count -gt 0
    if ($alreadyRunning) {
        Write-Host "$($window.Name): dedicated browser already running; reuse its window."
        Write-Host 'Close that dedicated browser yourself before rerunning if it needs to be reopened or repositioned.'
        continue
    }

    # Existing files and saved room membership are retained on every run.
    $null = New-Item -ItemType Directory -Path $profileDirectory -Force
    $arguments = @(
        "--user-data-dir=`"$profileDirectory`"",
        "--app=$presentationUrl",
        '--no-first-run',
        '--no-default-browser-check',
        "--window-position=$($window.Left),$top",
        "--window-size=$($window.Width),$windowHeight"
    )
    Start-Process -FilePath $browser.Path -ArgumentList $arguments
    Write-Host "$($window.Name): opened with $($browser.Name). Saved room membership is kept."
}

Write-Host 'Use Participant A to create a presentation room and Participant B to join with its room code.'
Write-Host 'Keep both windows visible; crop the recording instead of minimizing the other participant.'
Write-Host 'Window placement is requested from Windows/the browser; adjust it manually if display scaling changes it.'
