# Skill Supply Chain V1/V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add controlled third-party skill sourcing, locking, update checks, and automated PR creation for this curated skill repository.

**Architecture:** Keep `skills/` as the approved runtime artifact tree. Add `sources/skills.sources.yaml` for external dependency intent, `.xan/skills.lock.json` for exact resolved provenance and content hashes, and `tools/skillctl` for local and CI operations.

**Tech Stack:** Node.js CommonJS CLI compatible with Node 12+, `js-yaml`, Git CLI, existing Bash maintenance scripts, GitHub Actions.

---

### Task 1: Core Library Tests

**Files:**
- Create: `test/skillctl-lib.test.js`
- Create: `tools/skillctl-lib.js`

- [x] Write tests for GitHub repository normalization, stable directory hashing, overlay replacement, and risk scanning.
- [x] Run `node test/skillctl-lib.test.js` and confirm it fails before implementation because `tools/skillctl-lib.js` is missing.
- [x] Implement the minimal library functions.
- [x] Run `npm test` and confirm all tests pass.

### Task 2: V1 CLI

**Files:**
- Create: `tools/skillctl`
- Create: `package.json`
- Create: `package-lock.json`
- Create: `sources/skills.sources.yaml`
- Create: `.xan/skills.lock.json`

- [x] Add `skillctl add github` to write external source declarations.
- [x] Add `skillctl update` and `skillctl sync` to clone GitHub sources, apply overlays, copy approved snapshots into `skills/`, and update lockfile metadata.
- [x] Add `skillctl check` and `skillctl doctor` to validate source schema, lockfile integrity, upstream availability, and security flags.
- [x] Validate against `kangarooking/cangjie-skill.git`.

### Task 3: V2 Automation

**Files:**
- Create: `.github/workflows/update-skills.yml`
- Create: `tools/render-update-summary`

- [x] Add a scheduled/manual workflow that runs `npm ci`, `skillctl update --all`, `skillctl check`, and opens a PR if files change.
- [x] Generate a PR body with changed external skills, provenance, content hashes, and security review flags.

### Task 4: Repository Docs and Doctor Integration

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `scripts/doctor.sh`

- [x] Document source/lock/snapshot workflow and the rule that third-party snapshots are not edited directly.
- [x] Call `./skillctl check` from `scripts/doctor.sh` when the Node tool exists.
- [x] Confirm `registry.json` is absent and not reintroduced.