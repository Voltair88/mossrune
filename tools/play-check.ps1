# Slow checks, run at phase gates: plays the real game headless and compares
# timings with test/perf_baseline.json. Exit 1 on the first failure.
# Usage: pwsh -NoProfile -File tools/play-check.ps1 [-Captures] [-UpdateBaseline]
param([switch]$Captures, [switch]$UpdateBaseline)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType Directory -Force captures | Out-Null

$baselinePath = 'test/perf_baseline.json'
# Budgets from the Design page: 60 fps, and 2 ms of enemy logic with 300 enemies.
$frameBudgetMs = 16.6
$enemyBudgetMs = 2.0
$regression = 1.2
$timeoutMs = 180000

function Fail([string]$step, [string]$detail) {
    Write-Host "FAIL: $step" -ForegroundColor Red
    if ($detail) { Write-Host $detail }
    exit 1
}

# Runs Godot and returns its log. Kills the process tree if it hangs.
function Run-Godot([string]$name, [string[]]$godotArgs) {
    $log = "captures/$name.log"
    $p = Start-Process godot_console -ArgumentList $godotArgs -PassThru -NoNewWindow `
        -RedirectStandardOutput $log -RedirectStandardError "captures/$name.err"
    if (-not $p.WaitForExit($timeoutMs)) {
        & taskkill /T /F /PID $p.Id | Out-Null
        Fail $name "timed out after $($timeoutMs / 1000) s"
    }
    $text = (Get-Content $log, "captures/$name.err" -Raw -ErrorAction SilentlyContinue) -join "`n"
    $errors = $text -split "`n" | Where-Object { $_ -match 'SCRIPT ERROR|^ERROR' }
    if ($errors) { Fail $name ($errors -join "`n") }
    return $text
}

function Play([string]$name, [int]$frames, [string[]]$gameArgs) {
    $json = "captures/$name.json"
    Remove-Item $json -ErrorAction SilentlyContinue
    $all = @('--headless', '--path', '.', '--fixed-fps', '60', '--quit-after', "$frames", '--') + $gameArgs + "--perf-out=$json"
    Run-Godot $name $all | Out-Null
    if (-not (Test-Path $json)) { Fail $name "no report at $json" }
    $r = Get-Content $json -Raw | ConvertFrom-Json
    Write-Host ("   {0}: {1:N1} s played, {2} kills, hp {3}, max {4} enemies, step {5:N2} ms, enemies {6:N2} ms (max {7:N2})" -f `
        $name, $r.run_seconds, $r.kills, $r.player_hp, $r.enemies_max, $r.step_ms_mean, $r.enemy_ms_mean, $r.enemy_ms_max)
    return $r
}

Write-Host '-- import'
Run-Godot 'import' @('--headless', '--path', '.', '--import') | Out-Null

Write-Host '-- smoke: 60 s with the circle bot'
$smoke = Play 'smoke' 3660 @('--seed=1', '--bot=circle')
if ($smoke.run_seconds -lt 59) { Fail 'smoke' "the run stopped at $($smoke.run_seconds) s" }

Write-Host '-- onboarding: an idle player survives the first 20 s'
$idle = Play 'idle' 1260 @('--seed=1', '--bot=idle')
if ($idle.player_state -eq 'dead') { Fail 'onboarding' 'the idle player died in the first 20 s' }

Write-Host '-- stress: 300 slimes for 10 s, best of 3'
# Frame time swings up to 40% between identical runs on a desktop, so each
# timing is the best of three; the slower runs measure the machine, not the game.
$stressRuns = 1..3 | ForEach-Object { Play "stress_$_" 660 @('--seed=1', '--god', '--spawn=slime:300') }
$stress = $stressRuns[0]
foreach ($k in 'step_ms_mean', 'enemy_ms_mean', 'frame_ms_mean') {
    $stress.$k = ($stressRuns | ForEach-Object { $_.$k } | Measure-Object -Minimum).Minimum
}
if ($stress.enemies_mean -lt 290) { Fail 'stress' "only $($stress.enemies_mean) enemies on average" }
if ($stress.frame_ms_mean -gt $frameBudgetMs) { Fail 'stress' "frame $($stress.frame_ms_mean) ms > $frameBudgetMs" }
if ($stress.enemy_ms_mean -gt $enemyBudgetMs) { Fail 'stress' "enemy logic $($stress.enemy_ms_mean) ms > $enemyBudgetMs" }

if ($UpdateBaseline -or -not (Test-Path $baselinePath)) {
    $stress | Select-Object step_ms_mean, enemy_ms_mean, frame_ms_mean | ConvertTo-Json | Set-Content $baselinePath
    Write-Host "   baseline written to $baselinePath"
} else {
    $base = Get-Content $baselinePath -Raw | ConvertFrom-Json
    foreach ($k in 'step_ms_mean', 'enemy_ms_mean', 'frame_ms_mean') {
        if ($stress.$k -gt $base.$k * $regression) {
            Fail 'performance regression' ("{0}: {1:N3} ms, baseline {2:N3} ms (+20% allowed)" -f $k, $stress.$k, $base.$k)
        }
    }
}

Write-Host '-- bots: whole runs per policy, in parallel, then the balance summary'
$botSeeds = 12
Remove-Item captures/bots_*.jsonl -ErrorAction SilentlyContinue
$bots = foreach ($policy in 'kite/random', 'kite/first', 'circle/random', 'wall_hug/random', 'idle/random') {
    $n = $policy -replace '/', '_'
    Start-Process godot_console -PassThru -NoNewWindow `
        -ArgumentList @('--headless', '--path', '.', '-s', 'res://tools/sim/bots.gd', '--', "--seeds=$botSeeds", "--policy=$policy", "--out=captures/bots_$n.jsonl") `
        -RedirectStandardOutput "captures/bots_$n.log" -RedirectStandardError "captures/bots_$n.err"
}
$botTimeoutMs = 600000
foreach ($p in $bots) {
    if (-not $p.WaitForExit($botTimeoutMs)) {
        & taskkill /T /F /PID $p.Id | Out-Null
        Fail 'bots' "timed out after $($botTimeoutMs / 1000) s"
    }
}
$botErrors = Get-Content captures/bots_*.log, captures/bots_*.err -ErrorAction SilentlyContinue | Where-Object { $_ -match 'SCRIPT ERROR' }
if ($botErrors) { Fail 'bots' ($botErrors -join "`n") }
$files = (Get-ChildItem captures/bots_*.jsonl).FullName
$summary = & godot_console --headless --path . -s res://tools/sim/balance.gd -- @files 2>&1 |
    Where-Object { $_ -notmatch 'BUG: Unref|at: unref|^Godot Engine|^\s*$' }
$summary | ForEach-Object { Write-Host "   $_" }
if ($LASTEXITCODE -ne 0) { Fail 'balance' 'a broken line was crossed' }

if ($Captures) {
    Write-Host '-- captures (opens a window)'
    foreach ($c in @(
            @{ name = 'gym'; scene = 'res://game/world/gym.tscn'; args = @('--bot=circle', '--show-states') },
            @{ name = 'main'; scene = 'res://game/main.tscn'; args = @('--seed=1', '--bot=circle', '--wave=5', '--show-states') }
        )) {
        New-Item -ItemType Directory -Force "captures/$($c.name)" | Out-Null
        Remove-Item "captures/$($c.name)/*.png" -ErrorAction SilentlyContinue
        Run-Godot "capture_$($c.name)" (@('--path', '.', $c.scene, '--write-movie', "captures/$($c.name)/frame.png",
                '--fixed-fps', '30', '--quit-after', '150', '--') + $c.args) | Out-Null
        Write-Host "   captures/$($c.name)/"
    }
}

Write-Host 'play-check: all passed' -ForegroundColor Green
