# Shared Skills Symlink Design

## Summary

This repository will become the single source of truth for skill content used by multiple coding agents. Each skill will live once in a neutral, agent-independent canonical directory. Agent-specific skill trees will remain in place only as symlink-based discovery entrypoints.

The immediate goal is to eliminate skill drift between Codex and Claude. A change to a skill's content should affect all supported agents without manual synchronization.

## Goals

- Make this repository the canonical source for all shared skill content.
- Store each skill only once.
- Keep agent-facing discovery paths stable through symlinks.
- Ensure changes to a skill affect all agents immediately.
- Add a verification path that catches broken links, missing files, and documentation drift.

## Non-Goals

- Introducing agent-specific forks of skill content.
- Changing the runtime behavior of existing skill scripts beyond path updates required by the migration.
- Building a generalized skill package manager.
- Broad cross-platform support for environments that cannot reliably preserve symlinks.

## Current State

The repository currently uses agent-specific skill trees:

- `.codex/skills/<skill-name>/`
- `.claude/skills/<skill-name>/`

At least one skill currently exists in both trees with duplicated `SKILL.md` content, while another exists only under `.codex/skills/`. This creates a maintenance risk:

- skill definitions can drift between agents
- new skills may be added to one tree but not the other
- documentation must describe multiple ownership paths for the same content

## Explicit Assumptions

- The repository's primary supported contributor environment preserves symlinks through normal Git workflows.
- Codex and Claude discovery mechanisms are expected to follow directory symlinks under their skill roots.
- Shared skills are intended to be visible to all supported agents unless a future design explicitly introduces per-agent visibility controls.
- Canonical paths are the required documentation standard after migration, not merely a preference.

## Proposed Architecture

### Canonical Layout

Each skill will move to a neutral canonical path:

```text
skills/<skill-name>/
  SKILL.md
  scripts/
  assets/        # optional, future
  references/    # optional, future
```

Agent-specific trees become symlink entrypoints:

```text
.codex/skills/<skill-name>   -> ../../skills/<skill-name>
.claude/skills/<skill-name>  -> ../../skills/<skill-name>
```

### Ownership Model

The entire skill directory is shared, not only `SKILL.md`. This includes:

- instruction content
- executable scripts
- future assets or references

This avoids partial duplication and ensures that a skill remains a coherent unit with one owner path.

### Compatibility Model

Agent-specific locations remain present in the repository for discovery compatibility, but they are no longer sources of truth. All internal skill content must be written to avoid dependence on a specific agent namespace.

The compatibility contract is:

- scripts and references must resolve correctly whether a skill is reached through `skills/<skill-name>` or an agent alias
- relative path logic must be based on the real skill directory, not on assumptions about the caller path
- migration work must audit existing scripts for path resolution patterns such as `dirname "$0"` and update them if the symlinked entrypoint would change behavior

Canonical documentation and examples must use canonical paths:

```bash
bash skills/<skill-name>/scripts/<script>.sh
```

Agent-specific paths may still be mentioned only as compatibility aliases where necessary.

### Agent Visibility Rule

The default rule for this migration is that every canonical skill is exposed to both `.codex/skills/` and `.claude/skills/`.

If a skill is found in only one agent tree during inventory, it must be classified before migration:

- `shared`: should be available to both agents after migration
- `agent-specific`: intentionally limited to one agent and therefore out of scope for this shared-symlink rollout

No skill may be exposed to an additional agent implicitly. Any one-sided skill requires an explicit classification decision during Phase 1.

### Visibility Manifest

The migration must create and maintain a durable manifest that records canonical skill visibility. For example:

```text
skills/manifest.json
```

At minimum, the manifest must record:

- canonical skill name
- visibility classification: `shared` or `agent-specific`
- for `agent-specific` skills, the allowed agent list

All verification and documentation checks must use this manifest as the source of truth for expected exposure under `.codex/skills/` and `.claude/skills/`.

### Naming Rule

Canonical skill directory names must be lowercase kebab-case and unique under `skills/`.

Inventory must flag:

- case-only differences
- punctuation differences that would normalize to the same canonical name
- names that would be awkward or unsafe in symlinked paths

## Alternatives Considered

### 1. Canonical `skills/` directory with symlinked agent trees

This is the recommended design.

Benefits:

- one editable source per skill
- no cross-agent drift
- stable agent-facing entrypoints
- simple mental model for contributors

Trade-offs:

- requires agent tooling to follow symlinked directories
- documentation must be updated to explain canonical versus compatibility paths

### 2. Shared directory plus thin agent wrappers

Keep `.codex/skills/` and `.claude/skills/` as real directories containing wrapper files pointing into shared content.

Benefits:

- allows small agent-specific metadata differences
- reduces dependence on directory-level symlink support

Trade-offs:

- reintroduces duplication
- wrapper maintenance becomes ongoing overhead
- weakens the single-source-of-truth model

### 3. Keep `.codex/skills/` canonical and symlink other agents into it

Benefits:

- smallest migration from the current state

Trade-offs:

- keeps the repository organized around one agent namespace
- does not truly isolate skill content from agent-specific ownership
- scales poorly if more agents are added

## Migration Plan

### Phase 1: Inventory

- enumerate every skill in `.codex/skills/` and `.claude/skills/`
- identify duplicates, mismatches, and missing counterparts
- compare content where both agents already have a version of the same skill
- classify every discovered skill as `shared` or `agent-specific`
- flag any naming collisions or normalization conflicts before moving files

If duplicate skills differ between agent trees, migration must stop for that skill until a reconciliation decision is recorded. The spec does not assume `.codex` or `.claude` automatically wins.

### Phase 2: Establish Canonical Tree

- create `skills/`
- move each reconciled shared skill directory into `skills/`
- preserve file contents and executable bits
- validate the canonical copy before replacing any agent entrypoint

Conflict resolution rule:

- if duplicate copies are byte-identical, either may seed the canonical directory
- if duplicate copies differ, reconcile manually and record the resolved content in `skills/<skill-name>/`
- do not proceed to symlink replacement for a divergent skill until reconciliation is complete

### Phase 3: Replace Agent Trees with Symlinks

- replace `.codex/skills/<skill-name>` with symlinks to `../../skills/<skill-name>`
- replace `.claude/skills/<skill-name>` with symlinks to `../../skills/<skill-name>`
- keep parent directories `.codex/skills/` and `.claude/skills/` as discovery roots
- remove stale real directories or files left behind in agent trees for migrated shared skills

Replacement should be performed only after the canonical directory for that skill passes validation, to avoid a partially migrated state.

### Phase 4: Update Skill Content and Documentation

- rewrite hardcoded internal references from `.codex/skills/...` to `skills/...` where appropriate
- update repository docs to describe `skills/` as canonical
- clarify that agent trees are compatibility entrypoints only

### Phase 5: Verification

- confirm every directory in `skills/` contains `SKILL.md`
- confirm every migrated shared skill entry in `.codex/skills/` and `.claude/skills/` is a valid symlink
- confirm every migrated shared-skill symlink target resolves
- confirm there are no leftover real directories or stray files for migrated shared skills in agent trees
- confirm executable scripts retain expected mode bits
- run existing relevant tests or smoke checks
- validate that `SKILLS_GUIDE.md` reflects the canonical tree

### Phase 6: Rollback Safety

- keep migration steps small and reviewable at the per-skill level
- after each migrated skill, validate canonical content and both agent symlinks before continuing
- if validation fails, restore the affected agent entrypoints before migrating the next skill
- avoid batch replacement of all skills until the validation process is proven on a first migrated skill

## Verification Strategy

### Required Checks

- filesystem inspection of canonical skill directories
- filesystem inspection of symlink entrypoints
- resolution check for each symlink target
- validation that script references in `SKILL.md` files point to canonical locations or explicitly supported aliases
- validation that no migrated shared skill remains as a real directory in an agent tree
- validation that executable scripts remain executable after migration
- agent-level smoke checks for discovery and load behavior

### Recommended Automation

Add a repository verification script that checks:

- canonical skill directories exist under `skills/`
- each skill has `SKILL.md`
- each migrated shared skill has a symlink entry under `.codex/skills/` and `.claude/skills/`
- each migrated shared-skill symlink target exists
- no migrated shared skill exists as a real directory or plain file under agent trees
- script files under `skills/*/scripts/` retain executable bits where expected
- `SKILLS_GUIDE.md` has a one-to-one entry for each canonical shared skill
- `SKILLS_GUIDE.md` references the correct canonical path and canonical usage command for each shared skill

This can later be wired into CI if the repository adopts automated checks.

### Required Smoke Checks

At minimum, migration validation must include:

- enumerate the canonical `shared` skill set from the visibility manifest
- confirm that shared skill set is discoverable through `.codex/skills/`
- confirm that shared skill set is discoverable through `.claude/skills/`
- open at least one migrated skill through each agent alias and confirm `SKILL.md` and script paths resolve correctly
- exclude explicitly classified `agent-specific` skills from shared-symlink verification checks

## Documentation Changes

The following files should be updated during implementation:

- `README.md`
- `SKILLS_GUIDE.md`
- `CLAUDE.md`
- `AGENTS.md` if contributor instructions need clarification

Documentation should state:

- `skills/` is the canonical location
- `.codex/skills/` and `.claude/skills/` are symlinked compatibility entrypoints
- contributors must edit canonical skill directories, not agent-specific aliases
- shared skills are exposed to both supported agents by default

## Risks and Mitigations

### Risk: Agent tooling does not follow symlinked skill directories

Mitigation:

- test discovery behavior for Codex and Claude after migration
- if discovery fails for an agent, stop the rollout and decide on a repo-wide fallback before further migration
- do not mix wrapper-based and symlink-based exposure patterns across shared skills unless a separate design explicitly allows it

Fallback decision rule:

- the fallback applies at the agent integration layer, not ad hoc per individual skill
- `skills/` remains canonical in either case

### Risk: Existing skill documents or scripts reference `.codex/skills/...`

Mitigation:

- audit all `SKILL.md` files and scripts during migration
- rewrite references to canonical paths where possible

### Risk: Contributors edit agent-specific aliases instead of canonical directories

Mitigation:

- make the aliases symlinks, not copies
- document the ownership model clearly in `README.md` and `SKILLS_GUIDE.md`

### Risk: Documentation drifts from actual skill inventory

Mitigation:

- add a verification script that checks guide coverage against `skills/`

### Risk: Symlink preservation fails in unsupported environments

Mitigation:

- document supported workflows clearly
- treat non-preserving archive/export flows as unsupported for direct contribution unless an alternate packaging path is later designed

### Risk: Partial migration leaves mixed real directories and symlinks

Mitigation:

- migrate one skill at a time
- validate immediately after each skill
- restore the previous state for that skill before continuing if validation fails

## Testing Considerations

This repository has minimal automation today, so implementation should include lightweight filesystem-level checks rather than complex test infrastructure.

Where skill-specific tests already exist, they should continue to run unchanged or be updated to canonical paths if they currently assume `.codex/skills/`.

Executable script checks should be part of migration verification, not left implicit.

## Implementation Boundaries

This design covers repository structure, ownership model, migration sequencing, and verification expectations.

It does not prescribe:

- a specific CI provider
- agent runtime internals beyond the path contract
- support for non-symlink platforms beyond current repository needs

## Recommendation

Adopt a canonical `skills/` directory and convert `.codex/skills/` and `.claude/skills/` into symlink-based discovery layers.

This gives the repository a clean ownership model, removes cross-agent drift, and keeps the migration small enough to implement safely with straightforward filesystem verification.
