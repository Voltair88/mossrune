# Fast checks, run before every commit. Stops on the first failure, exit 1.
# Usage (from anywhere): pwsh -NoProfile -File tools/check.ps1
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

$dirs = @('game', 'test', 'tools', 'data') | Where-Object { Test-Path $_ }
$scripts = Get-ChildItem $dirs -Recurse -Filter *.gd -File

function Fail([string]$step, [string]$detail) {
    Write-Host "FAIL: $step" -ForegroundColor Red
    if ($detail) { Write-Host $detail }
    exit 1
}

function Step([string]$name) { Write-Host "-- $name" }

Step 'format'
$out = & gdscript-formatter --check @dirs 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { Fail 'format (run: gdscript-formatter game test tools data)' $out }

Step 'lint'
$out = & gdscript-formatter lint @dirs 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { Fail 'lint' $out }

Step 'import (refreshes the class_name cache)'
$out = & godot_console --headless --path . --import 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { Fail 'import' $out }

Step 'parse (warnings as errors)'
$out = & godot_console --headless --path . -s res://tools/check_scripts.gd 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { Fail 'parse' $out }

Step 'anti-patterns'
$banned = [ordered]@{
    'KinematicBody2D'                    = '\bKinematicBody2D\b'
    'TileMap (use TileMapLayer)'         = '\bTileMap\b'
    'Sprite/AnimatedSprite without 2D'   = '\b(Animated)?Sprite\b'
    'export var'                         = '^\s*export\s+var\b'
    'onready var'                        = '^\s*onready\s+var\b'
    'yield'                              = '\byield\s*\('
    'bare tool'                          = '^\s*tool\s*$'
    'setget'                             = '\bsetget\b'
    'string connect'                     = '\.connect\(\s*"[^"]*"\s*,'
    'Image.create( (use create_empty)'   = '\bImage\.create\('
}
$hits = foreach ($name in $banned.Keys) {
    $scripts | Select-String -Pattern $banned[$name] | ForEach-Object { "  ${name}: $($_.Path):$($_.LineNumber)" }
}
if ($hits) { Fail 'anti-patterns' ($hits -join "`n") }

Step 'magic numbers (game/)'
$allowed = @(0.0, 1.0, 2.0)
$hits = foreach ($file in ($scripts | Where-Object { $_.FullName -like '*\game\*' })) {
    $lines = Get-Content $file.FullName
    $isResource = [bool]($lines | Select-String -Pattern '^extends\s+Resource\b' -Quiet)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        # Drop strings first, so a '#' inside one doesn't cut the line, then comments.
        $code = $lines[$i] -replace '"(?:[^"\\]|\\.)*"|''(?:[^''\\]|\\.)*''', '""' -replace '#.*$', ''
        if ($code -match '^\s*(static\s+)?const\s') { continue }
        if ($isResource -and $code -match '^\s*@export') { continue }
        foreach ($m in [regex]::Matches($code, '(?<![\w.])(\d+(?:\.\d*)?|\.\d+)(?![\w.])')) {
            if ([double]$m.Value -notin $allowed) { "  $($file.FullName):$($i + 1): $($m.Value)" }
        }
    }
}
if ($hits) { Fail 'magic numbers: move these to a const or a Resource' ($hits -join "`n") }

Step 'tests (GUT)'
$out = & godot_console --headless -s addons/gut/gut_cmdln.gd --path . -gdir=res://test -ginclude_subdirs -gexit 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { Fail 'tests' $out }

Write-Host 'check: all passed' -ForegroundColor Green
