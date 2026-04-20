# run_benchmark_suite.ps1
#
# Automated benchmark: runs batches of agents, waits for each batch
# to finish, records the slowest runtime, then moves on to the next.
#
# Usage:
#   .\run_benchmark_suite.ps1 <Executable> [Start] [End]
#
#   <Executable>  Name of the MODFLOW binary (with or without .exe).
#                 Looked up in the parent directory (Win/) first,
#                 then anywhere on PATH.
#   [Start]       First batch to run (default: 1)
#   [End]         Last batch to run  (default: 16)
#
# Examples:
#   .\run_benchmark_suite.ps1 USGs_1.exe             # all batches
#   .\run_benchmark_suite.ps1 USGs_1.exe 5           # batch 5 only
#   .\run_benchmark_suite.ps1 USGs_1.exe 10 16       # batches 10-16
#
# Results are saved to {ComputerName}_{Executable}_{datetime}_benchmark_results.csv
# in this directory.
#
# Requirements: Python 3 on PATH (for retrieve_runtimes.py).
# To allow execution: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Executable,

    [Parameter(Position=1)]
    [int]$Start = 1,

    [Parameter(Position=2)]
    [int]$End = 16
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Configuration ──────────────────────────────────────────────────
$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$ParentDir    = Split-Path -Parent $ScriptDir
$ComputerName = $env:COMPUTERNAME
$Timestamp    = Get-Date -Format "yyyy-MM-dd_HHmmss"
$ResultsCsv   = Join-Path $ScriptDir "${ComputerName}_${Executable}_${Timestamp}_benchmark_results.csv"
$Python       = if (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" } else { "python" }
$RetrieveScript = Join-Path $ScriptDir "retrieve_runtimes.py"

# ── Locate executable ──────────────────────────────────────────────
$ExePath = $null
$Candidate = Join-Path $ParentDir $Executable
if (Test-Path $Candidate) {
    $ExePath = $Candidate
} else {
    $Found = Get-Command $Executable -ErrorAction SilentlyContinue
    if ($Found) {
        $ExePath = $Found.Source
    }
}

if (-not $ExePath) {
    Write-Host ""
    Write-Host "Cannot find '$Executable'." -ForegroundColor Red
    Write-Host "  Place the binary in: $ParentDir"
    Write-Host "  or ensure it is on your PATH."
    Write-Host ""
    Write-Host "Available binaries in ${ParentDir}:"
    Get-ChildItem $ParentDir -File | Where-Object { $_.Name -ne "scripts" } | ForEach-Object { Write-Host "  $($_.Name)" }
    exit 1
}

# ── Detect OS and executable architecture ─────────────────────────
$OsName    = "Windows"
$OsVersion = (Get-CimInstance Win32_OperatingSystem).Version
$ExeArch   = try {
    $bytes = [System.IO.File]::ReadAllBytes($ExePath)
    # PE machine field at offset 0x3C (pointer to PE header) + 4
    $peOffset = [System.BitConverter]::ToInt32($bytes, 0x3C)
    $machine  = [System.BitConverter]::ToUInt16($bytes, $peOffset + 4)
    switch ($machine) {
        0x8664 { "x86-64" }
        0xAA64 { "arm64"  }
        0x014C { "x86"    }
        default { "unknown (0x{0:X4})" -f $machine }
    }
} catch { "unknown" }

# ── Helper: clean MODFLOW outputs for agents a1..aN ───────────────
function Clear-Outputs([int]$N) {
    for ($i = 1; $i -le $N; $i++) {
        $outDir = Join-Path $ScriptDir "a$i\output"
        "biscayne.list","biscayne.cbc","biscayne.hds" | ForEach-Object {
            $f = Join-Path $outDir $_
            if (Test-Path $f) { Remove-Item $f -Force }
        }
    }
}

# ── Helper: run N agents in parallel and wait ─────────────────────
function Start-Batch([int]$N) {
    $jobs = @()
    for ($i = 1; $i -le $N; $i++) {
        $agentDir = Join-Path $ScriptDir "a$i"
        $job = Start-Process `
            -FilePath    $ExePath `
            -ArgumentList "biscayne.nam" `
            -WorkingDirectory $agentDir `
            -WindowStyle Hidden `
            -PassThru
        $jobs += $job
    }
    $jobs | Wait-Process
}

# ── Main ──────────────────────────────────────────────────────────

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  MODFLOW-USG Benchmark Suite"
Write-Host "  Executable : $Executable ($ExeArch)"
Write-Host "  Batches    : $Start to $End"
Write-Host "  OS         : $OsName $OsVersion"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Write CSV header
"num_agents,slowest_runtime_minutes,slowest_agent,datetime,executable,os,arch" | Out-File -FilePath $ResultsCsv -Encoding utf8
Write-Host "  Results file: $ResultsCsv"
Write-Host ""

for ($n = $Start; $n -le $End; $n++) {
    Write-Host "------------------------------------------"
    Write-Host "  Batch $n/$End : Running $n agent(s)..."
    Write-Host "------------------------------------------"

    Clear-Outputs $n

    $t0 = Get-Date
    Start-Batch $n
    $wallSec = [int](New-TimeSpan -Start $t0 -End (Get-Date)).TotalSeconds
    $wallMin = [math]::Round($wallSec / 60.0, 2)

    # Parse runtimes
    $output = & $Python $RetrieveScript --agents $n 2>&1
    $slowestLine = $output | Where-Object { $_ -match "^Slowest run:" } | Select-Object -First 1

    if ($slowestLine) {
        $slowestRuntime = if ($slowestLine -match "Slowest run: ([0-9.]+) minutes") { $Matches[1] } else { "N/A" }
        $slowestAgent   = if ($slowestLine -match "\(agent ([^)]+)\)")              { $Matches[1] } else { "N/A" }
    } else {
        $slowestRuntime = "N/A"
        $slowestAgent   = "N/A"
    }

    Write-Host "  -> Wall time: $wallMin min | Slowest: $slowestRuntime min ($slowestAgent)"
    Write-Host ""

    $runDatetime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$n,$slowestRuntime,$slowestAgent,$runDatetime,$Executable,$OsName $OsVersion,$ExeArch" |
        Out-File -FilePath $ResultsCsv -Append -Encoding utf8
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Benchmark Complete!"
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Results saved to: $ResultsCsv"
Write-Host ""

# Print summary table
$header = "{0,-8}  {1,-22}  {2,-8}  {3,-20}  {4,-18}  {5,-16}  {6,-10}" -f "Agents","Slowest Runtime (min)","Agent","Date/Time","Executable","OS","Arch"
$divider = "{0,-8}  {1,-22}  {2,-8}  {3,-20}  {4,-18}  {5,-16}  {6,-10}" -f "------","---------------------","-----","---------","----------","--","----"
Write-Host $header
Write-Host $divider
Import-Csv $ResultsCsv | ForEach-Object {
    "{0,-8}  {1,-22}  {2,-8}  {3,-20}  {4,-18}  {5,-16}  {6,-10}" -f `
        $_.num_agents, $_.slowest_runtime_minutes, $_.slowest_agent,
        $_.datetime, $_.executable, $_.os, $_.arch
} | Write-Host
