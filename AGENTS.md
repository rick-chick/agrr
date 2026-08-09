# Agent quick reference

Command table and skill index. Norms: `CLAUDE.md`, contracts, arch guard.

## Commands

| Task | Command |
| ---- | ------- |
| R4 contracts | `scripts/run-rust-contract-tests.sh` |
| Domain tests | `.cursor/skills/test-common/scripts/run-test-rust-domain.sh` |
| Frontend tests | `.cursor/skills/test-common/scripts/run-test-frontend.sh` |
| Docker rebuild (`crates/*`) | `.cursor/skills/dev-docker/scripts/rebuild-restart.sh` |

**Tests**: run once → log to `./tmp/{UUID}.log` → inspect with grep/tail/head. Do not pipe runner output to grep/tail.

**Read**: grep for line numbers, then read with offset/limit.

## Skills

| Task | Skill |
| ---- | ----- |
| Tests | [test-common](.cursor/skills/test-common/SKILL.md) |
| TDD | [tdd-on-edit](.cursor/skills/tdd-on-edit/SKILL.md) |
| Docker | [dev-docker](.cursor/skills/dev-docker/SKILL.md) |
| Bugs | [error-investigation](.cursor/skills/error-investigation/SKILL.md) |

## Git

Forbidden without user permission: checkout, switch, reset, restore, clean, force push. Allowed: status, diff, log, show, add, commit. See `.cursor/rules/git-operational-constraints.mdc`.

## Work

Split into ≤50k-context tasks with `tmp/` checklists. TDD + test-common. Test per task; full suite at end.
