# Required CI contexts（pr-agent-prep / merge worker）

正本: `scripts/pr-agent-prep-lib.mjs`

## 無条件必須（`UNCONDITIONAL_REQUIRED_CI_CONTEXTS`）

| context | workflow |
|---------|----------|
| `rails-test` | Backend test |
| `frontend-test` | Frontend test |
| `lint / frontend-lint` | Lint |
| `lint / run-architecture-guard` | Lint (architecture guard) |

GitHub ruleset **master CI required** は上記のうち `lint / run-architecture-guard` を除く 3 件を硬いゲートとする（ruleset と pr-agent-prep の差分は意図的）。

## 条件付き必須（`CONDITIONAL_REQUIRED_CI_CONTEXTS`）

| context | workflow | 挙動 |
|---------|----------|------|
| `frontend-e2e-smoke` | Frontend E2E smoke | path filter で workflow が走った PR では **SUCCESS 必須**。check が無い PR（backend-only 等）はスキップ扱いで merge prep をブロックしない |

`areRequiredChecksGreen` / `areRequiredChecksComplete` は、条件付き context が `gh pr checks` に無いときは充足とみなす。表示されているのに fail / pending ならブロックする。

## ruleset との整合

- path-filter 付き workflow（`frontend-e2e-smoke.yml`）は ruleset 必須に**載せない**（未実行 PR が merge 不能になるため）
- Agent merge ゲート（`pr-agent-prep` / Delivery Agent merge 経路）は `REQUIRED_CI_CONTEXTS` で条件付きを評価する
- 契約テスト: `scripts/verify-ruleset-ci-lib.test.mjs`, `scripts/pr-agent-prep-lib.test.mjs`
