---
name: gitbutler-workflows
description: Work safely with this repository when it is managed by GitButler. Use when creating branches, assigning changes, committing, amending commits, pushing, or opening pull requests through GitButler virtual branches.
---

# GitButler Workflows

Use this skill when the repository is on `gitbutler/workspace` or when the user explicitly asks for GitButler-based branch and commit operations.

## Core Model

- Treat `gitbutler/workspace` as GitButler's integration branch, not a normal branch to commit on.
- Do not use plain `git commit` on `gitbutler/workspace`.
- Prefer GitButler CLI commands through `but` for branch creation, staging, commit creation, commit rewriting, pushing, and PR creation.
- Use plain `git` for read-only inspection when useful, but assume write operations on `HEAD`, branch refs, or the index can conflict with GitButler's model.

## Standard Flow

1. Run `but status -f` to inspect unassigned changes, staged changes, applied branches, and commit IDs.
2. If a suitable virtual branch already exists for the work, reuse it.
3. If not, create one with `but branch new <branch-name>`.
4. Move unassigned work onto the target branch with `but stage <file-or-hunk> <branch>`.
5. Create the commit with `but commit <branch> --only --message ...` when the branch already has the right staged changes.
6. Push with `but push <branch>`.
7. Open or update the review with `but pr new <branch>` when GitButler forge auth is configured.

## Branching Rules

- Prefer one virtual branch per user-visible task.
- If `but status` already shows a branch lane that matches the work, do not create a duplicate branch.
- Use `but branch new <branch-name> --anchor <branch-or-commit>` only when the user clearly wants stacked work.

## Commit Rewrites

- When the user wants additional work included in an existing commit, do not create a follow-up fixup commit by default.
- Use `but status -f` to get the file ID for the new change and the short commit ID for the target commit.
- Amend the change into the existing commit with `but amend <file-id> <commit-id>` or the equivalent `but rub <file-id> <commit-id>`.
- For commit-message-only rewrites, prefer `but reword <sha> -m "<message>"`.
- Use `but reword <sha>` without `-m` when you want to edit the message in an editor and let GitButler rebase dependent work automatically.
- If `but reword` fails because GitButler cannot open the workspace database or create temporary files, run `but setup` and retry once.
- If GitButler still cannot complete the rewrite, stop and surface the failure clearly instead of silently switching to plain Git history edits.
- After rewriting a pushed commit, push the branch again and expect a force update.

## PR Notes

- `but pr` requires GitButler forge authentication.
- If `but pr` fails because no authenticated forge user is configured, keep the GitButler branch and commit flow intact and use the available GitHub tooling only for the PR creation step.
- Reuse the commit message as the PR body when the user asks for a single source of truth.

## Safety Checks

- Before mutating anything, verify whether unassigned changes exist in `zz` and whether they belong to the requested branch.
- Avoid switching to normal git branches unless the user explicitly wants to leave GitButler mode.
- If you need to inspect branch state after a push or amend, rerun `but status -f`.
