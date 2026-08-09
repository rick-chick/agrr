# Agent commands

## Test commands

| Task | Command |
| ---- | ------- |
| R4 contracts | `scripts/run-rust-contract-tests.sh` |
| Domain tests | `.cursor/skills/test-common/scripts/run-test-rust-domain.sh` |
| Frontend tests | `.cursor/skills/test-common/scripts/run-test-frontend.sh` |
| API rebuild (after `crates/*`) | `.cursor/skills/dev-docker/scripts/rebuild-restart.sh` |

Run tests via [test-common](.cursor/skills/test-common/SKILL.md) only. Redirect full output to `./tmp/{UUID}.log`, then grep — do not pipe test runners through grep/tail in the same shell.

## Skills

| Task | Skill |
| ---- | ----- |
| Tests | [test-common](.cursor/skills/test-common/SKILL.md) |
| TDD | [tdd-on-edit](.cursor/skills/tdd-on-edit/SKILL.md) |
| Docker dev | [dev-docker](.cursor/skills/dev-docker/SKILL.md) |
| Bugs | [error-investigation](.cursor/skills/error-investigation/SKILL.md) |
