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

        # If this repo is a git working copy and git is available, commit the change
        $gitDir = Join-Path $repoRoot '.git'
        $gitExe = (Get-Command git -ErrorAction SilentlyContinue).Path
    if ((Test-Path $gitDir) -and ($gitExe)) {
            try {
        Write-Log "gitDir: $gitDir"
        Write-Log "gitExe: $gitExe"
                Push-Location $repoRoot
        Write-Log "Running git add..."
                # Use Start-Process to avoid complex redirection parsing in PowerShell
                $tmpAddOut = [System.IO.Path]::GetTempFileName()
                $tmpAddErr = [System.IO.Path]::GetTempFileName()
                Start-Process -FilePath $gitExe -ArgumentList 'add','-f','--','password/ip.txt' -NoNewWindow -Wait -RedirectStandardOutput $tmpAddOut -RedirectStandardError $tmpAddErr
        Write-Log "Finished git add"
                $addOut = Get-Content $tmpAddOut -Raw -ErrorAction SilentlyContinue
                $addErr = Get-Content $tmpAddErr -Raw -ErrorAction SilentlyContinue
                if ($addOut) { Write-Log "git add: $addOut" }
                if ($addErr) { Write-Log "git add err: $addErr" }
                Remove-Item $tmpAddOut,$tmpAddErr -ErrorAction SilentlyContinue

                $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                $msg = "auto: update password/ip.txt - $timestamp"

                $tmpCommitOut = [System.IO.Path]::GetTempFileName()
                $tmpCommitErr = [System.IO.Path]::GetTempFileName()
                Write-Log "Running git commit..."
                Start-Process -FilePath $gitExe -ArgumentList 'commit','-m',$msg -NoNewWindow -Wait -RedirectStandardOutput $tmpCommitOut -RedirectStandardError $tmpCommitErr
                Write-Log "Finished git commit"
                $commitOut = Get-Content $tmpCommitOut -Raw -ErrorAction SilentlyContinue
                $commitErr = Get-Content $tmpCommitErr -Raw -ErrorAction SilentlyContinue
                if ($commitOut) { Write-Log "git commit: $commitOut" }
                if ($commitErr) { Write-Log "git commit err: $commitErr" }
                Remove-Item $tmpCommitOut,$tmpCommitErr -ErrorAction SilentlyContinue

                $tmpPushOut = [System.IO.Path]::GetTempFileName()
                $tmpPushErr = [System.IO.Path]::GetTempFileName()
                Write-Log "Running git push..."
                Start-Process -FilePath $gitExe -ArgumentList 'push' -NoNewWindow -Wait -RedirectStandardOutput $tmpPushOut -RedirectStandardError $tmpPushErr
                Write-Log "Finished git push"
                $pushOut = Get-Content $tmpPushOut -Raw -ErrorAction SilentlyContinue
                $pushErr = Get-Content $tmpPushErr -Raw -ErrorAction SilentlyContinue
                if ($pushOut) { Write-Log "git push: $pushOut" }
                if ($pushErr) { Write-Log "git push err: $pushErr" }
                Remove-Item $tmpPushOut,$tmpPushErr -ErrorAction SilentlyContinue
            } catch {
                Write-Log "Git commit/push failed: $($_.Exception.Message)"
            } finally {
                Pop-Location
            }
        } else {
            Write-Log "Git not available or not a repo; skipping commit"
        }
    } else {
        Write-Log "Content unchanged"
    }
} catch {
    # Print full exception details for debugging
    Write-Log "Error: $($_.Exception.Message)"
    Write-Host "EXCEPTION-DETAILS:" ; Write-Host $_.Exception.ToString()
    exit 1
}
