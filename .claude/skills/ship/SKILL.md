---
name: ship
description: Commit the current work, open a GitHub PR, and merge it into main for Smoopee/MoverTester. Only run when the user types /ship.
disable-model-invocation: true
argument-hint: "[PR title or short description]"
---

# Ship: commit → PR → merge

Takes the current work all the way into `main` on GitHub (`Smoopee/MoverTester`). The user typing
`/ship` is the go-ahead to commit, push, open the PR and merge it. **Stop and report** instead of
working around anything below that fails. Never force-push, never use `--admin`, and never skip hooks.

Arguments (optional): `$ARGUMENTS` — used as the PR title / summary. Without it, write one from the diff.

## 1. Look at what's being shipped
- `git status --short`, `git diff HEAD --stat`, and `git log origin/main..HEAD --oneline`.
- If there are no uncommitted changes and no commits ahead of `origin/main`, say there's nothing to ship
  and stop.
- Skip anything that looks like it shouldn't be in git (secrets, `.env`, export builds, files under
  `.godot/`) and mention it. Do commit Godot's `*.gd.uid` files next to new scripts.

## 2. Check it works
Run these from the repo root. Any `SCRIPT ERROR` or non-zero exit stops the ship.
```bash
for f in $(git ls-files 'scripts/*.gd' 'tools/*.gd'; git ls-files --others --exclude-standard '*.gd'); do "/c/Program Files/Godot/godot.exe" --headless --path . --check-only --script "res://$f" || echo "FAILED: $f"; done
```
```bash
"/c/Program Files/Godot/godot.exe" --headless --path . --script res://tools/balance_sim.gd -- --rounds 50
```
The sim must finish with `unfinished 0`. Put its mean turns-to-cheese in the PR body.

## 3. Keep CLAUDE.md current
Read `CLAUDE.md` and check it against the diff being shipped. It needs an edit when the change:
- adds, renames or removes a file under `scripts/`, `tools/` or `scenes/`, or changes what one is for;
- adds or renames a `%Unique` node the code uses, or a method the Layout section names;
- adds, renames or removes a skill, agent or hook under `.claude/`;
- changes a command, the Godot path, or a convention (typing, drawing in code, `Board.animate`, ...).

Fix only the lines that are now wrong or missing, in the file's existing terse style. Don't list
individual effects or tuning values, and don't add a changelog. Ship the edit in the same commit. If
nothing needs changing, leave the file alone.

## 4. Branch and commit
- On `main`: create a branch named after the change (kebab-case, e.g. `add-teleport-effect`) with
  `git checkout -b <name>`. Otherwise stay on the current branch.
- Stage the specific files (not `git add -A`), then commit with a short imperative subject and a few
  bullet lines of detail if the change has several parts. End the message with:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- Commits already on the branch are shipped as they are; don't rewrite them.

## 5. Push and open the PR
```bash
git fetch origin && git merge-base --is-ancestor origin/main HEAD || git merge origin/main
```
If that merge conflicts, stop and show the conflicts. Then:
```bash
git push -u origin HEAD
```
Open the PR with `gh pr create --base main --title "<title>" --body-file <file>`, writing the body to a
file in the scratchpad. The body has:
- **Summary** — 2–4 bullets of what changed and why.
- **Checks** — parse check passed for N scripts; sim mean turns to cheese; CLAUDE.md updated (what
  changed) or already current.
- Last line: `🤖 Generated with [Claude Code](https://claude.com/claude-code)`

If a PR for this branch already exists (`gh pr view` succeeds), reuse it and update its body.

## 6. Merge
- `gh pr view --json mergeable,mergeStateStatus,statusCheckRollup`. The repo has no CI today, so an
  empty check list is fine. Stop if any check failed or is pending, or if `mergeable` is `CONFLICTING`.
- Merge with a merge commit (how the repo's PRs are merged) and delete the remote branch:
```bash
gh pr merge --merge --delete-branch
```

## 7. Sync and report
```bash
git checkout main && git pull --ff-only origin main
```
Delete the local branch with `git branch -d <name>` (not `-D`). Report the PR link, the merge commit
SHA, and the check results in a few lines.
