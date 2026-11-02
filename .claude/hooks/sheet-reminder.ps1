# PostToolUse hook: after Claude edits the game's tuning, remind it to update the "Mouse and Cheese"
# Google Sheet (see "Design sheet" in CLAUDE.md). Any edit to difficulty.gd or score.gd counts; in
# boss.gd, run.gd, main.gd and board.gd only an edit that touches a const line does.

$payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
$file = $payload.tool_input.file_path
if (-not $file) { exit 0 }
$name = [IO.Path]::GetFileName($file)

$always = @('difficulty.gd', 'score.gd')
$constsOnly = @('boss.gd', 'run.gd', 'main.gd', 'board.gd')
if ($name -notin $always -and $name -notin $constsOnly) { exit 0 }
if ($name -in $constsOnly) {
	$text = @($payload.tool_input.old_string, $payload.tool_input.new_string, $payload.tool_input.content) -join "`n"
	if ($text -notmatch '(?m)^\s*const\s') { exit 0 }
}

$note = "You changed game tuning in $name. Before finishing, update the Mouse and Cheese Google Sheet " +
	"to match (see 'Design sheet' in CLAUDE.md): the value on the Rules tab, and the Rounds tab's " +
	"formulas or notes if how the value is used changed."
@{ hookSpecificOutput = @{ hookEventName = 'PostToolUse'; additionalContext = $note } } | ConvertTo-Json -Compress
exit 0
