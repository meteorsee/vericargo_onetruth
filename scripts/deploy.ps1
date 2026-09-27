[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Connection,

    [switch]$RunAgentTests,

    [switch]$SkipStreamlit
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$generatedDir = Join-Path $projectRoot 'data\generated'
$documentsDir = Join-Path $generatedDir 'documents'
$sqlDir = Join-Path $projectRoot 'snowflake'
$appDir = Join-Path $projectRoot 'app'

function Assert-LastExitCode {
    param([string]$Operation)
    if ($LASTEXITCODE -ne 0) {
        throw "$Operation failed with exit code $LASTEXITCODE."
    }
}

function Invoke-SnowSqlFile {
    param([string]$Path)
    Write-Host "Running $(Split-Path -Leaf $Path)..."
    & $snowExecutable sql -c $Connection -f $Path
    Assert-LastExitCode "Snowflake SQL file $(Split-Path -Leaf $Path)"
}

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw 'Python is required but was not found on PATH.'
}
$snowCommand = Get-Command snow -ErrorAction SilentlyContinue
$localSnow = Join-Path $projectRoot '.venv\Scripts\snow.exe'
if ($snowCommand) {
    $snowExecutable = $snowCommand.Source
}
elseif (Test-Path -LiteralPath $localSnow) {
    $snowExecutable = $localSnow
}
else {
    throw 'Snowflake CLI (`snow`) is required but was not found on PATH or in .venv.'
}

Write-Host 'Generating deterministic fixture data...'
& python (Join-Path $projectRoot 'scripts\generate_data.py')
Assert-LastExitCode 'Synthetic data generation'

Write-Host 'Running local acceptance tests...'
$previousPythonPath = $env:PYTHONPATH
$env:PYTHONPATH = Join-Path $projectRoot 'src'
try {
    & python -m unittest discover -s (Join-Path $projectRoot 'tests') -v
    Assert-LastExitCode 'Local acceptance tests'
}
finally {
    $env:PYTHONPATH = $previousPythonPath
}

Invoke-SnowSqlFile (Join-Path $sqlDir '00_bootstrap.sql')
Invoke-SnowSqlFile (Join-Path $sqlDir '01_raw_tables.sql')

$csvPath = ($generatedDir -replace '\\', '/')
$documentPath = ($documentsDir -replace '\\', '/')

Write-Host 'Uploading CSV fixtures...'
& $snowExecutable sql -c $Connection -q "PUT file://$csvPath/*.csv @VERICARGO_ONETRUTH.RAW.CSV_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
Assert-LastExitCode 'CSV upload'

Write-Host 'Uploading synthetic SI and Draft BL documents...'
& $snowExecutable sql -c $Connection -q "PUT file://$documentPath/*.pdf @VERICARGO_ONETRUTH.RAW.DOCUMENT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
Assert-LastExitCode 'Document upload'

foreach ($fileName in @(
    '02_load.sql',
    '03_marts.sql',
    '04_documents.sql',
    '04b_snowpark_features.sql',
    '05_semantic.sql',
    '06_actions_and_agent.sql',
    '07_automation.sql',
    '08_validation.sql'
)) {
    Invoke-SnowSqlFile (Join-Path $sqlDir $fileName)
}

if ($RunAgentTests) {
    Invoke-SnowSqlFile (Join-Path $sqlDir '09_agent_smoke_tests.sql')
}

if (-not $SkipStreamlit) {
    Write-Host 'Deploying Streamlit in Snowflake...'
    Push-Location $appDir
    try {
        & $snowExecutable streamlit deploy -c $Connection --replace --prune
        Assert-LastExitCode 'Streamlit deployment'
    }
    finally {
        Pop-Location
    }
}

Write-Host 'Deployment finished. Save the emitted query IDs and screenshots in docs/coco-evidence.'
