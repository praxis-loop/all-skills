# Agent Rules

## Repository Purpose

This repository is the source of truth for reusable AI agent skills. Skills are organized as:

```text
skills/<function>/<domain>/<skill-name>/SKILL.md
```

## Required Checks

After modifying any file under `skills/`, `docs/`, `templates/`, or `scripts/`, run:

```bash
git status --short
bash scripts/doctor.sh
```

Use the Git status to determine whether the local server has skill changes that still need to be synchronized to the remote repository.

## Sync Responsibility

When a skill is created, moved, deleted, or updated, the agent must explicitly tell the user whether the repository has:

- uncommitted working tree changes,
- local commits that have not been pushed,
- remote commits that should be pulled,
- or a clean synchronized state.

If the user asks to synchronize changes, commit the relevant files and push the current branch.

## Installation Safety

Do not overwrite a target CLI skill directory when the existing target is a real directory rather than a symlink or junction. Tell the user to back up or move the existing directory before installing the linked version.

## Skill Update Rules

- Keep `SKILL.md` concise and move long references to `references/`.
- Put deterministic helper logic in `scripts/`.
- Do not commit secrets, tokens, passwords, private keys, or machine-specific local config.
- Ask for confirmation before deleting data, publishing changes, sending messages, spending money, or changing production systems.

## Third-party Skill Supply Chain

- Keep the filesystem as the source of truth for approved runtime skills. Do not restore `registry.json`.
- Own skills directly under `skills/`; do not list them in `sources/skills.sources.yaml`.
- Manage third-party skills through `sources/skills.sources.yaml`, `.xan/skills.lock.json`, and `tools/skillctl`.
- Do not hand-edit third-party snapshot directories under `skills/`. Use `overlays/<skill-name>/overlay.yaml` for small local adaptations, or fork the upstream source for large changes.
- After changing sources, lockfiles, overlays, tooling, or third-party snapshots, run:

```bash
npm test
./skillctl check
bash scripts/doctor.sh
```

- Treat new `allowed-tools` permissions, helper scripts, network commands, package installs, destructive shell commands, and secret-path mentions as review-required changes.
