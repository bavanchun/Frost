# Frost Development Workflow

## 1. Purpose

This document defines the mandatory development workflow for Frost.

Frost is a personal macOS application forked from Ice. The project follows a lightweight trunk-based development model designed to keep the codebase stable, reviewable, releasable, and easy to synchronize with upstream.

All contributors and coding agents must follow this workflow unless an explicit exception is documented.

---

## 2. Branching Model

Frost does not use a permanent `dev` branch.

The repository uses the following flow:

```text
short-lived branch
        ↓
Pull Request
        ↓
main
        ↓
release tag
```

The `main` branch is the single integration branch and must always remain buildable and releasable.

### Why Frost does not use `dev`

A permanent `dev` branch would introduce:

* Additional merge operations.
* More opportunities for branch divergence.
* More conflicts during upstream synchronization.
* Delayed integration.
* Greater risk that `main` and `dev` behave differently.
* Additional process overhead without meaningful benefit for a small project.

A `dev` branch may only be introduced in the future if Frost has:

* Multiple active development teams.
* A dedicated QA environment.
* Long-running release stabilization cycles.
* Separate development, staging, and production deployments.
* A clear operational requirement for an integration branch.

Until then, all integration happens through Pull Requests into `main`.

---

## 3. Protected Main Branch

The `main` branch is protected.

The following actions are prohibited:

* Direct commits to `main`.
* Force pushes to `main`.
* Deleting `main`.
* Merging Pull Requests with failing CI.
* Merging incomplete or unrelated changes.
* Using `main` as a temporary development branch.

Every meaningful change must enter `main` through a Pull Request.

Recommended repository rules:

```text
Require a pull request before merging
Require status checks to pass
Require conversation resolution
Require linear history
Block force pushes
Block branch deletion
Automatically delete merged branches
```

For a solo-maintained repository, required approvals may remain at zero, but the Pull Request and CI requirements must still be enforced.

---

## 4. Branch Types

Every task must use a short-lived branch created from the latest `main`.

Supported branch prefixes:

```text
feat/
fix/
refactor/
perf/
test/
docs/
build/
ci/
chore/
release/
hotfix/
upstream/
```

### Branch naming format

```text
<type>/<short-kebab-case-description>
```

Examples:

```text
feat/menu-bar-profiles
fix/frost-bar-display-wake
refactor/settings-persistence
perf/menu-item-discovery
docs/release-process
ci/add-xcode-build-check
upstream/ice-v1.5.0
release/1.2.0
hotfix/updater-crash
```

Invalid names:

```text
update
working
new-feature
test
fix-bug
final
changes
van-branch
```

Branch names must describe the intended result, not the developer performing the work.

---

## 5. Task Lifecycle

Every task should follow this lifecycle:

```text
Issue or task definition
        ↓
Create branch from main
        ↓
Implement focused changes
        ↓
Run validation locally
        ↓
Commit atomic changes
        ↓
Push branch
        ↓
Open Draft Pull Request
        ↓
Complete implementation
        ↓
Self-review
        ↓
CI passes
        ↓
Mark Pull Request ready
        ↓
Squash merge into main
        ↓
Delete branch
```

---

## 6. Starting a Task

Before starting any work, synchronize the local repository.

```bash
git switch main
git pull --ff-only origin main
```

Create a task branch:

```bash
git switch -c feat/menu-bar-profiles
```

A branch must be created from the latest `main`.

Do not create a new branch from another feature branch unless the dependency is intentional and documented.

---

## 7. Issue and Task Requirements

A meaningful change should have an issue or clearly documented task.

The task must describe:

* The problem or requirement.
* The expected result.
* The scope.
* The out-of-scope items.
* The acceptance criteria.
* Relevant technical constraints.

Recommended issue format:

```markdown
## Context

Explain why this change is needed.

## Expected behavior

Describe the required final behavior.

## Scope

- Included item
- Included item

## Out of scope

- Excluded item
- Excluded item

## Acceptance criteria

- [ ] Requirement one
- [ ] Requirement two
- [ ] Tests added or updated
- [ ] Documentation updated where required

## Technical notes

Document relevant components, APIs, constraints, or upstream references.
```

A coding agent must not infer a large feature from a vague issue without documenting its assumptions.

---

## 8. Scope Discipline

Each branch and Pull Request must have one primary objective.

Good scope:

```text
Add named menu bar layout profiles.
Fix Frost Bar visibility after display wake.
Extract settings persistence into a dedicated service.
```

Bad scope:

```text
Add profiles, redesign settings, update dependencies, fix updater, and rename files.
```

Unrelated changes must be placed in separate branches and Pull Requests.

Formatting-only changes must not be mixed with functional changes unless they are limited to files already being modified.

---

## 9. Commit Convention

Frost uses Conventional Commits.

Commit format:

```text
<type>(<scope>): <description>
```

Supported commit types:

| Type       | Purpose                                            |
| ---------- | -------------------------------------------------- |
| `feat`     | New user-facing functionality                      |
| `fix`      | Bug fix                                            |
| `refactor` | Structural change without intended behavior change |
| `perf`     | Performance improvement                            |
| `test`     | Test additions or corrections                      |
| `docs`     | Documentation changes                              |
| `style`    | Formatting without logic changes                   |
| `build`    | Build system, Xcode project, dependencies          |
| `ci`       | CI or GitHub Actions changes                       |
| `chore`    | Maintenance work                                   |
| `revert`   | Revert a previous change                           |

Examples:

```text
feat(profiles): add named menu bar layouts
fix(updater): suppress unavailable permission prompt
refactor(settings): isolate persistence from view state
perf(menu-bar): reduce repeated window enumeration
test(profiles): cover profile serialization
docs(release): document signing requirements
build(xcode): update deployment target
ci(actions): add macOS build validation
```

Invalid commit messages:

```text
update
fix bug
working
final version
changes
fix again
some improvements
```

---

## 10. Atomic Commits

Every commit must represent one coherent change.

A good commit should:

* Have one purpose.
* Be understandable independently.
* Avoid unrelated file modifications.
* Avoid mixing refactoring and feature work when possible.
* Avoid debug files, generated artifacts, secrets, or local configuration.
* Leave the project in a valid state whenever practical.

Example commit sequence:

```text
refactor(profiles): extract layout profile model
feat(profiles): persist named profiles
feat(profiles): add profile selection interface
test(profiles): cover profile persistence
docs(readme): document layout profiles
```

Avoid:

```text
feat: add profiles and refactor settings and fix updater
```

---

## 11. Staging Changes

Review changes before committing:

```bash
git status
git diff
```

Prefer interactive staging:

```bash
git add -p
```

Interactive staging helps prevent unrelated changes from entering the same commit.

Before committing, verify:

```bash
git diff --cached
```

---

## 12. Local Validation

Before pushing a branch, the coding agent must perform all relevant validation.

Minimum validation:

```text
Project builds successfully
Relevant tests pass
No unintended warnings are introduced
No secrets are included
No debug code remains
No unrelated files are modified
```

For UI changes:

```text
Manually verify the affected flow
Check layout in relevant states
Capture screenshots or recordings
Check light and dark appearance where applicable
```

For permission-sensitive changes:

```text
Verify Accessibility permission behavior
Verify Screen Recording permission behavior
Verify first-launch permission handling
Verify behavior after permission revocation
```

For settings changes:

```text
Verify existing settings still load
Verify default values
Verify migration behavior
Verify corrupted or missing values are handled safely
```

---

## 13. Pull Request Workflow

Push the branch:

```bash
git push -u origin feat/menu-bar-profiles
```

Open a Draft Pull Request as early as practical.

The Pull Request title must follow Conventional Commit format:

```text
feat(profiles): add named menu bar layouts
fix(frost-bar): restore visibility after display wake
```

Recommended Pull Request body:

```markdown
## Summary

Explain what changed and why.

## Related issue

Closes #123

## Changes

- Added ...
- Updated ...
- Removed ...

## Verification

- [ ] App builds successfully
- [ ] Existing tests pass
- [ ] New tests were added where appropriate
- [ ] Manual testing completed
- [ ] Permission-sensitive behavior verified
- [ ] Settings compatibility verified
- [ ] No secrets or local files included

## Screenshots or recordings

Attach evidence for UI changes.

## Risks

Describe possible regressions and affected components.

## Upstream impact

- [ ] Frost-only change
- [ ] Derived from upstream Ice
- [ ] Candidate for upstream contribution
- [ ] May create future upstream conflicts
```

---

## 14. Pull Request Size

Pull Requests should remain small enough to review in one focused session.

Recommended target:

```text
One feature, fix, or refactor per Pull Request
Prefer fewer than approximately 400 changed logic lines
Exclude mechanical renames and generated files from this estimate
```

Large work should be divided into stages:

```text
Preparation refactor
Core implementation
UI integration
Tests
Documentation
```

Each stage must remain independently understandable.

---

## 15. Self-Review

Before marking a Pull Request ready, review the complete diff.

```bash
git fetch origin
git diff origin/main...HEAD
git log --oneline origin/main..HEAD
git diff --check
```

The coding agent must verify:

```text
The implementation matches the acceptance criteria
No unrelated changes are present
No temporary logging remains
No debug code remains
No hard-coded local paths exist
No credentials or secrets are included
No unnecessary dependency was added
No user-facing Ice branding was reintroduced
Frost identifiers remain correct
Tests cover important behavior
Documentation reflects user-visible behavior
```

Swift-specific review:

```text
Avoid unjustified force unwraps
Avoid silently swallowing meaningful errors
Use @MainActor for UI state when required
Ensure Tasks have clear ownership and cancellation
Avoid unnecessary work on the main thread
Check for retain cycles
Prefer value types where appropriate
Keep business logic outside SwiftUI views
```

---

## 16. Synchronizing Before Merge

Before final merge, update the branch with the latest `main`.

Preferred method:

```bash
git fetch origin
git rebase origin/main
```

Resolve conflicts carefully, then push:

```bash
git push --force-with-lease
```

Only use `--force-with-lease` on the task branch.

Never force push to `main`.

After rebasing, rerun all relevant validation.

---

## 17. Merge Strategy

Frost uses Squash and Merge for normal Pull Requests.

Recommended repository merge settings:

```text
Squash merging: enabled
Merge commits: disabled for normal feature work
Rebase merging: optional or disabled
Automatically delete head branches: enabled
```

The final squash commit must use the Pull Request title.

Example `main` history:

```text
feat(profiles): add named menu bar layouts (#42)
fix(updater): suppress unavailable permission prompt (#41)
refactor(settings): separate persistence layer (#40)
```

The resulting `main` history must remain concise and readable.

---

## 18. After Merge

After the Pull Request is merged:

```bash
git switch main
git pull --ff-only origin main
git branch -d feat/menu-bar-profiles
```

If the remote branch was not deleted automatically:

```bash
git push origin --delete feat/menu-bar-profiles
```

Do not reuse an old branch for unrelated work.

Create a new branch for every new task.

---

## 19. Definition of Done

A task is complete only when all applicable conditions are satisfied.

```text
[ ] Acceptance criteria are satisfied
[ ] Project builds successfully
[ ] Relevant tests pass
[ ] No unexplained warnings were introduced
[ ] Manual validation is complete
[ ] Permission behavior was tested where relevant
[ ] Existing settings remain compatible
[ ] UI evidence is attached where relevant
[ ] Documentation is updated
[ ] Changelog is updated for user-visible changes
[ ] Pull Request has been self-reviewed
[ ] CI passes
[ ] Pull Request is merged into main
[ ] Task branch is deleted
```

Code existing only on a feature branch is not considered complete.

---

## 20. Upstream Ice Workflow

Frost tracks Ice as an upstream project.

Configure remotes:

```bash
git remote add upstream https://github.com/jordanbaird/Ice.git
git fetch upstream
```

Expected remotes:

```text
origin    Frost repository
upstream  Ice repository
```

Upstream changes must never be merged directly into `main` without review.

Create a dedicated upstream branch:

```bash
git switch main
git pull --ff-only origin main
git fetch upstream
git switch -c upstream/ice-vX.Y.Z
```

Two integration strategies are supported.

### Full upstream synchronization

Use when integrating a complete upstream release:

```bash
git merge upstream/main
```

This preserves upstream ancestry and makes future synchronization easier.

### Selective integration

Use for isolated fixes or changes:

```bash
git cherry-pick <upstream-commit-sha>
```

Use selective integration only when commit dependencies are understood.

Recommended policy:

```text
Security fix              → prioritize immediately
Critical bug fix          → cherry-pick or merge
Small isolated fix        → cherry-pick
Major upstream release    → dedicated merge Pull Request
Unwanted upstream feature → do not integrate
```

---

## 21. Upstream Conflict Areas

The following areas are expected to conflict during upstream synchronization:

```text
Xcode project and scheme names
Bundle identifiers
App display names
Frost assets and icons
User-facing Frost strings
Sparkle update configuration
Release scripts
Documentation
Copyright and attribution
```

After every upstream merge, verify that Frost identity remains intact.

Do not combine a large upstream merge and unrelated Frost feature work in the same Pull Request.

Recommended upstream commit sequence:

```text
chore(upstream): merge Ice vX.Y.Z
fix(branding): restore Frost identifiers after upstream sync
fix(updater): retain Frost release feed configuration
docs(upstream): record synchronized Ice revision
```

---

## 22. Upstream Documentation

The repository should maintain:

```text
docs/UPSTREAM.md
```

Recommended content:

```markdown
# Upstream Relationship

Frost is derived from jordanbaird/Ice.

## Upstream

- Repository: https://github.com/jordanbaird/Ice
- Tracking branch: upstream/main
- Last synchronized revision: <commit SHA>
- Last synchronized release: <tag>

## Frost-specific changes

- Frost product identity and branding
- Frost bundle identifiers
- Frost release infrastructure
- Frost-specific features
- Frost update configuration

## Sync policy

Security and critical fixes are prioritized.
Features are evaluated individually.
All upstream integrations use dedicated branches and Pull Requests.

## Known conflict areas

- Xcode project
- Bundle identifiers
- Sparkle configuration
- App assets
- User-facing strings
- Release documentation
```

Update this file after every upstream synchronization.

---

## 23. Release Workflow

Releases must be created from `main`.

Normal release flow:

```text
main
  ↓
release preparation Pull Request
  ↓
version and changelog update
  ↓
merge into main
  ↓
create signed tag
  ↓
build and publish release
```

Create a release branch only when release preparation requires multiple coordinated changes:

```bash
git switch main
git pull --ff-only origin main
git switch -c release/1.2.0
```

A release branch is temporary. It must be deleted after the release Pull Request is merged.

Do not use a permanent `release` branch.

---

## 24. Semantic Versioning

Frost follows Semantic Versioning:

```text
MAJOR.MINOR.PATCH
```

Examples:

```text
1.0.0
1.1.0
1.1.1
2.0.0
```

Version rules:

```text
PATCH → backward-compatible bug fix
MINOR → backward-compatible feature
MAJOR → breaking behavior, migration, or compatibility change
```

Pre-release versions:

```text
1.2.0-alpha.1
1.2.0-beta.1
1.2.0-rc.1
```

Release tags:

```bash
git tag -s v1.2.0 -m "Frost 1.2.0"
git push origin v1.2.0
```

Tags must be created from commits already present on `main`.

---

## 25. Release Checklist

Before publishing a release:

```text
[ ] main is synchronized
[ ] CI passes
[ ] Marketing version is updated
[ ] Build number is updated
[ ] CHANGELOG is updated
[ ] Release build succeeds
[ ] Signing configuration is correct
[ ] Hardened Runtime is correct where applicable
[ ] Sparkle configuration is verified
[ ] Update from the previous version is tested
[ ] Fresh installation is tested
[ ] Accessibility permission is tested
[ ] Screen Recording permission is tested
[ ] Existing settings remain intact
[ ] Release archive is validated
[ ] Git tag is created
[ ] GitHub Release is published
[ ] Download links are verified
```

---

## 26. Hotfix Workflow

A hotfix is used only for a critical production issue.

Create the hotfix branch directly from `main`:

```bash
git switch main
git pull --ff-only origin main
git switch -c hotfix/updater-crash
```

The hotfix must:

* Contain the smallest safe change.
* Include a regression test where practical.
* Avoid unrelated refactoring.
* Use a Pull Request.
* Pass CI.
* Increment the patch version if released.

Flow:

```text
main
  ↓
hotfix/*
  ↓
Pull Request
  ↓
main
  ↓
patch release
```

Do not bypass Pull Requests unless the repository is inaccessible or an exceptional emergency is documented.

---

## 27. Changelog Rules

Frost should maintain:

```text
CHANGELOG.md
```

Recommended structure:

```markdown
# Changelog

## [Unreleased]

### Added

### Changed

### Fixed

### Removed

## [1.2.0] - YYYY-MM-DD

### Added

- Added named menu bar layout profiles.

### Fixed

- Fixed Frost Bar visibility after display wake.
```

Only include changes relevant to users or maintainers.

Do not include routine implementation details such as:

```text
Renamed a local variable
Formatted files
Moved a private helper
Updated comments
```

---

## 28. Documentation Requirements

Update documentation when a change affects:

* User behavior.
* Installation.
* Permissions.
* Configuration.
* Architecture.
* Build process.
* Release process.
* Upstream synchronization.
* Contributor workflow.

Recommended documentation files:

```text
docs/
├── ARCHITECTURE.md
├── DEVELOPMENT.md
├── RELEASING.md
├── UPSTREAM.md
└── DECISIONS/
```

Important architectural decisions should be stored as Architecture Decision Records.

---

## 29. Architecture Decision Records

Use ADRs for decisions that are difficult to reverse or affect the long-term structure of Frost.

Example files:

```text
docs/DECISIONS/
├── 0001-use-trunk-based-development.md
├── 0002-track-ice-as-upstream.md
├── 0003-use-sparkle-for-updates.md
└── 0004-support-macos-14-and-later.md
```

ADR template:

```markdown
# ADR 0001: Decision title

## Status

Accepted

## Context

Describe the problem and constraints.

## Decision

Describe the selected approach.

## Consequences

### Positive

- Positive consequence

### Negative

- Negative consequence

## Alternatives considered

- Alternative one
- Alternative two
```

---

## 30. Dependency Policy

New dependencies must not be added casually.

Before adding a dependency, evaluate:

```text
Is the dependency necessary?
Can the standard library or existing code solve the problem?
Is the project actively maintained?
Is its license compatible with GPL-3.0?
Does it increase app size significantly?
Does it require new permissions?
Does it introduce privacy concerns?
Does it complicate upstream synchronization?
Does it support the minimum macOS version?
```

A dependency change must be documented in the Pull Request.

Lockfiles and resolved package files must be updated intentionally.

---

## 31. Security Rules

The following must never be committed:

```text
Private keys
Certificates
Notarization credentials
Apple account credentials
API tokens
GitHub tokens
Sparkle private signing keys
Environment files containing secrets
User-specific provisioning data
Local machine paths with sensitive information
```

Before committing:

```bash
git diff --cached
```

If a secret is committed, removing the file in a later commit is not sufficient. The secret must be revoked and repository history must be evaluated.

Security-related fixes should use private disclosure when appropriate.

---

## 32. Coding Agent Rules

A coding agent working on Frost must follow these rules:

1. Read the issue, relevant documentation, and nearby implementation before editing.
2. Confirm the current branch before making changes.
3. Never work directly on `main`.
4. Keep changes limited to the requested scope.
5. Preserve existing architecture unless the task requires architectural change.
6. Preserve Frost branding and identifiers.
7. Preserve GPL attribution and upstream credit.
8. Avoid unnecessary dependencies.
9. Avoid broad formatting changes.
10. Add or update tests for changed behavior.
11. Run relevant build and test commands.
12. Review the complete diff before committing.
13. Use Conventional Commits.
14. Create or update documentation for user-visible or architectural changes.
15. Clearly report validation performed.
16. Clearly report validation that could not be performed.
17. Never claim a test passed unless it was actually executed successfully.
18. Never silently ignore compiler warnings, failing tests, or unresolved conflicts.
19. Do not merge a Pull Request unless all required checks pass.
20. Do not create release tags from unmerged branches.

---

## 33. Coding Agent Execution Template

For every task, the agent should follow this sequence.

### Step 1: Inspect

```text
Read the task
Inspect relevant files
Inspect existing tests
Inspect architecture documentation
Identify upstream-sensitive areas
```

### Step 2: Plan

```text
Summarize intended changes
Identify affected files
Identify risks
Identify required tests
Identify documentation changes
```

### Step 3: Branch

```bash
git switch main
git pull --ff-only origin main
git switch -c <type>/<description>
```

### Step 4: Implement

```text
Make the smallest correct change
Follow existing style
Avoid unrelated refactoring
Add tests
Update documentation
```

### Step 5: Validate

```text
Run formatter
Run linter
Build the application
Run relevant tests
Perform manual checks where required
Review git diff
```

### Step 6: Commit

```bash
git add -p
git diff --cached
git commit -m "<type>(<scope>): <description>"
```

### Step 7: Synchronize

```bash
git fetch origin
git rebase origin/main
```

### Step 8: Push

```bash
git push -u origin <branch>
```

### Step 9: Pull Request

```text
Open a Draft Pull Request
Complete the Pull Request template
Attach screenshots where applicable
Wait for CI
Resolve all failures
Mark ready for review
```

### Step 10: Merge

```text
Use Squash and Merge
Use the Pull Request title as the squash commit
Delete the task branch
Synchronize local main
```

---

## 34. Standard Command Flow

```bash
# Synchronize main
git switch main
git pull --ff-only origin main

# Create task branch
git switch -c feat/example-feature

# Inspect work
git status
git diff

# Stage intentionally
git add -p

# Review staged changes
git diff --cached

# Commit
git commit -m "feat(example): add example feature"

# Update with latest main
git fetch origin
git rebase origin/main

# Push branch
git push -u origin feat/example-feature

# After Pull Request merge
git switch main
git pull --ff-only origin main
git branch -d feat/example-feature
```

---

## 35. Core Project Principles

All Frost development must follow these principles:

1. `main` is always releasable.
2. No direct development occurs on `main`.
3. Frost does not use a permanent `dev` branch.
4. Every meaningful change uses a short-lived branch.
5. Every meaningful change enters through a Pull Request.
6. Each branch and Pull Request has one primary objective.
7. Commits follow Conventional Commits.
8. Commits are atomic and reviewable.
9. CI must pass before merge.
10. User-visible changes require documentation or changelog updates.
11. Upstream Ice changes use dedicated branches and Pull Requests.
12. Frost-specific changes must remain distinguishable from upstream.
13. Security-sensitive data must never enter Git.
14. Release tags are created only from `main`.
15. Maintainability takes priority over short-term implementation speed.

---

## 36. Canonical Frost Workflow

The official Frost development workflow is:

```text
Create or select issue
        ↓
Update local main
        ↓
Create short-lived branch
        ↓
Implement one focused change
        ↓
Add or update tests
        ↓
Run local validation
        ↓
Create atomic Conventional Commits
        ↓
Rebase onto latest main
        ↓
Push branch
        ↓
Open Draft Pull Request
        ↓
Self-review complete diff
        ↓
CI passes
        ↓
Mark Pull Request ready
        ↓
Squash merge into main
        ↓
Delete branch
        ↓
Release from main when appropriate
```

This workflow is mandatory for all normal Frost development.
