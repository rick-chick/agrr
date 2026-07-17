# GitHub Actions 制約（Automation 配線）

## GITHUB_TOKEN と workflow トリガー

`GITHUB_TOKEN`（`GH_TOKEN: ${{ github.token }}`）で行った操作が発火する後続 workflow は限られる。

| 操作（Actions 内） | `issues: labeled` 等の後続 workflow |
|--------------------|-------------------------------------|
| `GITHUB_TOKEN` でラベル付与 | **起動しない** |
| `postWebhook`（curl + secrets） | 起動する（意図した経路） |
| 人間 / PAT でラベル付与 | 起動する |

**結論**: Actions から Cloud Agent を起動するときは **webhook 直接送信**。「ラベルだけ変えて `issue-worker-dispatch.yml` に任せる」は **動かない**。

参照: [GitHub Docs — Triggering a workflow](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow)

### 二重 dispatch の見極め

| 経路 | 二重になるか |
|------|--------------|
| Actions: `postWebhook` + `GITHUB_TOKEN` で `agent-ready` 付与 | **ならない**（labeled workflow は起動しない） |
| 人間: UI で `agent-ready` 付与 | primary dispatch のみ |
| Actions: `postWebhook` 二回 | **なる**（同一 job 内の二重 curl を避ける） |

## 認証の二系統（Cloud Agent 内）

| 用途 | トークン | 設定 |
|------|----------|------|
| `git clone` / `git push` / PR 作成 | Cursor GitHub App | Dashboard → Integrations |
| `gh issue` / `gh pr comment` | `AGRR_GH_PAT` | Cloud Agents → Secrets |
| Actions 内 `gh` | `GITHUB_TOKEN` | workflow 自動 |

Cloud Agent 内の `gh` は `.cursor/scripts/cloud-gh-auth.sh` 経由。統合トークンだけでは `gh issue list` が失敗する。

詳細: [cursor-automation-schedule.md §GitHub CLI 認証](../../cloud-automation-audit/references/cursor-automation-schedule.md)

## secrets 未設定時

| workflow | 既定 |
|----------|------|
| Issue Worker dispatch | exit 0 でスキップ（ログに明記） |
| PR Merge Worker dispatch | exit 1（気づきやすく） |

新規 dispatch は **既存の同系 workflow に合わせる**。
