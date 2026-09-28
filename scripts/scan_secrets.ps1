[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$scannerRelativePath = 'scripts/scan_secrets.ps1'
$textExtensions = @(
    '.cmd', '.csv', '.json', '.md', '.ps1', '.py', '.sql', '.toml', '.txt',
    '.yaml', '.yml'
)
$forbiddenPaths = @(
    '.env',
    '.snowflake/connections.toml',
    '.streamlit/secrets.toml'
)
$secretPatterns = [ordered]@{
    'private key material' = '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'
    'Google API key' = 'AIza[0-9A-Za-z_-]{35}'
    'AWS access key' = '(?:AKIA|ASIA)[0-9A-Z]{16}'
    'GitHub access token' = 'gh[pousr]_[0-9A-Za-z]{20,}'
    'Slack token' = 'xox[baprs]-[0-9A-Za-z-]{20,}'
    'Google service-account private key' = '"private_key"\s*:\s*"-----BEGIN'
    'assigned credential' = '(?i)(?:password|client_secret|access_token|refresh_token|api_key)\s*[:=]\s*["''](?!<|YOUR_|REPLACE_|PENDING)[^"'']{8,}["'']'
}

Push-Location $projectRoot
try {
    $files = @(& git ls-files --cached --others --exclude-standard)
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to enumerate repository files with git.'
    }

    $findings = [System.Collections.Generic.List[string]]::new()
    foreach ($forbiddenPath in $forbiddenPaths) {
        if ($files -contains $forbiddenPath) {
            $findings.Add("forbidden credential file: $forbiddenPath")
        }
    }

    foreach ($relativePath in $files) {
        $normalizedPath = $relativePath.Replace('\', '/')
        if ($normalizedPath -eq $scannerRelativePath) {
            continue
        }
        $extension = [System.IO.Path]::GetExtension($relativePath).ToLowerInvariant()
        if ($textExtensions -notcontains $extension) {
            continue
        }

        $lineNumber = 0
        foreach ($line in Get-Content -LiteralPath $relativePath -Encoding UTF8) {
            $lineNumber++
            foreach ($entry in $secretPatterns.GetEnumerator()) {
                if ($line -match $entry.Value) {
                    $findings.Add("$($entry.Key): ${normalizedPath}:${lineNumber}")
                }
            }
        }
    }

    if ($findings.Count -gt 0) {
        Write-Error ("Potential secrets found:`n - " + ($findings -join "`n - "))
        exit 1
    }

    Write-Host "Secret scan passed for $($files.Count) tracked and unignored files."
}
finally {
    Pop-Location
}
