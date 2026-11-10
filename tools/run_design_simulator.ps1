param(
    [Parameter(Mandatory = $true)]
    [string] $DeveloperKey,
    [ValidateSet("NavyLight", "NavyDark", "Surf", "ZuluLight", "ZuluDark")]
    [string] $Variant = "NavyDark",
    [string] $DeviceId = "instinct3solar45mm"
)

$ErrorActionPreference = "Stop"
$sdkConfig = Join-Path $env:APPDATA "Garmin\ConnectIQ\current-sdk.cfg"
if (!(Test-Path $sdkConfig)) {
    throw "Connect IQ SDK not found: $sdkConfig"
}
if (!(Test-Path $DeveloperKey)) {
    throw "Developer key not found: $DeveloperKey"
}

$sdk = (Get-Content $sdkConfig -Raw).Trim()
$compiler = Join-Path $sdk "bin\monkeyc.bat"
$runner = Join-Path $sdk "bin\monkeydo.bat"
$project = Split-Path $PSScriptRoot -Parent
$jungle = @{
    NavyLight = "test-navy-light.jungle"
    NavyDark = "test-navy-dark.jungle"
    Surf = "test-surf.jungle"
    ZuluLight = "test-zulu-light.jungle"
    ZuluDark = "test-zulu-dark.jungle"
}[$Variant]
$output = Join-Path $project "bin\taticonavy-$($Variant.ToLowerInvariant()).prg"

Push-Location $project
try {
    & $compiler -f $jungle -d $DeviceId -y $DeveloperKey -w -o $output
    if ($LASTEXITCODE -ne 0) {
        throw "Connect IQ design build failed with exit code $LASTEXITCODE."
    }

    $arguments = "`"$runner`" `"$output`" $DeviceId"
    $process = Start-Process -FilePath $env:ComSpec -ArgumentList @("/d", "/c", $arguments) `
        -WorkingDirectory $project -PassThru
    Start-Sleep -Seconds 2
    if ($process.HasExited -and $process.ExitCode -ne 0) {
        throw "Could not launch the design build. Start the Connect IQ simulator and run this command again."
    }
    Write-Output "Launched $Variant design build (process $($process.Id))."
}
finally {
    Pop-Location
}
