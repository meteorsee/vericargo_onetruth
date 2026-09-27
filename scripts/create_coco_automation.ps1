[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Connection,

    [string]$Schedule = 'daily at 9am',

    [string]$Timezone = 'Asia/Kuala_Lumpur'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$promptFile = Join-Path $projectRoot 'automations\daily_exception_digest.md'

$cortexCommand = Get-Command cortex -ErrorAction SilentlyContinue
$installedCortex = Join-Path $env:LOCALAPPDATA 'cortex\bin\cortex.cmd'
if ($cortexCommand) {
    $cortexExecutable = $cortexCommand.Source
}
elseif (Test-Path -LiteralPath $installedCortex) {
    $cortexExecutable = $installedCortex
}
else {
    throw 'Snowflake CoCo CLI (`cortex`) is required but was not found.'
}

& $cortexExecutable -c $Connection automation create `
    --name vericargo_daily_exception_digest `
    --prompt-file $promptFile `
    --schedule $Schedule `
    --timezone $Timezone `
    --no-workspace

if ($LASTEXITCODE -ne 0) {
    throw "CoCo automation creation failed with exit code $LASTEXITCODE."
}

Write-Host 'Run and inspect it before relying on the schedule:'
Write-Host "  cortex -c $Connection automation execute vericargo_daily_exception_digest --wait"
Write-Host "  cortex -c $Connection automation doctor vericargo_daily_exception_digest"
