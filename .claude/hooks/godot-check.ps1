# PostToolUse hook: after Claude edits a .gd file, parse-check it with headless Godot.
# Exit 2 feeds the error back to Claude; anything else is silent.

$payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
$file = $payload.tool_input.file_path
if (-not $file -or -not $file.EndsWith('.gd')) { exit 0 }

$project = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { $payload.cwd }
$godot = if ($env:GODOT) { $env:GODOT } else { 'C:\Program Files\Godot\godot.exe' }
if (-not (Test-Path $godot)) { exit 0 }

$full = [IO.Path]::GetFullPath($file)
$root = [IO.Path]::GetFullPath($project).TrimEnd('\') + '\'
if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { exit 0 }
$resPath = 'res://' + $full.Substring($root.Length).Replace('\', '/')

# "$_" turns PowerShell's stderr ErrorRecords back into Godot's plain text.
$lines = & $godot --headless --path $project --check-only --script $resPath 2>&1 | ForEach-Object { "$_" }
if ($LASTEXITCODE -ne 0 -or ($lines -cmatch 'SCRIPT ERROR|Parse Error')) {
	[Console]::Error.WriteLine("Godot parse check failed for ${resPath}:")
	[Console]::Error.WriteLine(($lines | Where-Object { $_ -cmatch 'ERROR|^\s+at:' }) -join "`n")
	exit 2
}
exit 0
