param(
  [string]$CasesRoot = ".\PJ1-Posted-Test-Cases",
  [string]$ExeName   = "PJ1.exe"
)

# --- helpers ------------------------------------------------------------
function Normalize-Text([string]$path) {
  if (-not (Test-Path $path)) { return $null }
  return (Get-Content $path -Raw) -replace "`r`n","`n"
}

function Parse-Flag([string]$executionPath) {
  if (-not (Test-Path $executionPath)) { throw "Missing Execution file: $executionPath" }
  $raw = Get-Content $executionPath -Raw
  # Matches: ./PJ1 I-file O-file <flag>
  if ($raw -match "PJ1\s+\S+\s+\S+\s+(-?\d+)") {
    return [int]$matches[1]
  } else {
    throw "Cannot parse flag from: $executionPath (content: $raw)"
  }
}

function Resolve-File([string]$dir, [string[]]$candidates) {
  foreach ($c in $candidates) {
    $p = Join-Path $dir $c
    if (Test-Path $p) { return $p }
  }
  throw "Could not find any of: $($candidates -join ', ') in $dir"
}

# --- setup --------------------------------------------------------------
$exePath = Join-Path (Get-Location) $ExeName
if (-not (Test-Path $exePath)) { throw "Cannot find $exePath. Build first." }

$all = Get-ChildItem -Path $CasesRoot -Directory | Where-Object { $_.Name -match '^test\d{2}$' } | Sort-Object Name
if ($all.Count -eq 0) { throw "No testXX folders found under $CasesRoot" }

$passed = 0
$failed = 0
$results = @()

# --- run each test ------------------------------------------------------
foreach ($td in $all) {
  $name = $td.Name
  $dir  = $td.FullName

  try {
    $execPath = Resolve-File $dir @("Execution","execution")
    $flag     = Parse-Flag $execPath

    $iFile    = Resolve-File $dir @("I-File","I-file","I_file","Ifile")
    $instr    = Resolve-File $dir @("Instructions","instructions")
    $expOut   = Resolve-File $dir @("Output","output")
    $expOf    = Resolve-File $dir @("O-File","O-file","O_file","Ofile")

    # where we put OUR outputs (never overwrite the provided expected files)
    $myStdout = Join-Path $dir "student.Output"
    $myOf     = Join-Path $dir "student.O-File"

    # clean previous runs
    Remove-Item -Force -ErrorAction SilentlyContinue $myStdout, $myOf

    # run PJ1: feed instructions via pipeline, capture stdout, write ofile to our student.O-File
    Write-Host "[$name] Running... flag=$flag" -ForegroundColor Cyan
    Get-Content $instr | & $exePath $iFile $myOf $flag > $myStdout

    # compare (normalize line endings so CRLF vs LF doesn't cause spurious diffs)
    $gotStd = Normalize-Text $myStdout
    $expStd = Normalize-Text $expOut
    $gotOf  = Normalize-Text $myOf
    $expOfT = Normalize-Text $expOf

    $stdOK = ($gotStd -ceq $expStd)
    $ofOK  = ($gotOf  -ceq $expOfT)

    if ($stdOK -and $ofOK) {
      $passed += 1
      $results += "[PASS] $name"
      Write-Host "[$name] PASS" -ForegroundColor Green
    } else {
      $failed += 1
      $results += "[FAIL] $name (stdout: $($stdOK), ofile: $($ofOK))"
      Write-Host "[$name] FAIL  (stdout match: $stdOK, ofile match: $ofOK)" -ForegroundColor Red

      # print quick, first-diff hints
      if (-not $stdOK) {
        Write-Host "  stdout diff (yours vs expected):" -ForegroundColor Yellow
        Compare-Object ($gotStd -split "`n") ($expStd -split "`n") -SyncWindow 0 |
          Select-Object -First 6 | Format-Table -AutoSize | Out-String | Write-Host
      }
      if (-not $ofOK) {
        Write-Host "  ofile diff (yours vs expected):" -ForegroundColor Yellow
        Compare-Object ($gotOf -split "`n") ($expOfT -split "`n") -SyncWindow 0 |
          Select-Object -First 6 | Format-Table -AutoSize | Out-String | Write-Host
      }
    }
  }
  catch {
    $failed += 1
    $results += "[ERROR] $name -> $($_.Exception.Message)"
    Write-Host "[$name] ERROR: $($_.Exception.Message)" -ForegroundColor Red
  }
}

# --- summary ------------------------------------------------------------
Write-Host ""
Write-Host "Summary: $passed passed, $failed failed (of $($all.Count))" -ForegroundColor Magenta
$results | ForEach-Object { Write-Host $_ }
