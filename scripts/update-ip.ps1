param(
    [string]$SourceUrl = 'https://loca.lt/mytunnelpassword'
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..')).Path
$outFile = Join-Path $repoRoot 'password\ip.txt'

function Write-Log($msg){ Write-Host "[update-ip] $msg" }

try {
    Write-Log "Fetching $SourceUrl"
    $resp = Invoke-WebRequest -Uri $SourceUrl -UseBasicParsing -ErrorAction Stop
    $content = $resp.Content -as [string]
    if ($null -eq $content) { Write-Log "Empty response"; exit 1 }

    # Write the entire response content to the ip file (no scanning)
    $newContent = $content -replace '\r?\n$',''  # trim trailing newline

    $current = ''
    if (Test-Path $outFile) { $current = (Get-Content $outFile -Raw) }
    if ($current -ne $newContent) {
        # ensure directory exists
        $dir = Split-Path -Parent $outFile
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
        Set-Content -Path $outFile -Value $newContent -Encoding UTF8
        Write-Log "Updated $outFile"
    } else {
        Write-Log "Content unchanged"
    }
} catch {
    Write-Log "Error: $($_.Exception.Message)"
    exit 1
}
