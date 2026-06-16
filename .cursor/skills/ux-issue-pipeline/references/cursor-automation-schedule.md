# Cursor Automation スケジュール設定（AGRR）

Cloud Agent がリポジトリを clone してスキルに従う。**ローカル Docker / ng は使えない**点に注意。

## 一覧

| Automation | スキル | cron（5 フィールド） | TZ | PR |
|------------|--------|----------------------|-----|-----|
| **Issue Worker** | `github-issue-worker` | `0 9 * * 1-5` | Asia/Tokyo | ✅ 実装時 |
| **UX Issue Audit** | `ux-issue-pipeline` § Automation | `0 9 * * 1` | Asia/Tokyo | ❌（起票は条件付き） |

## 共通手順

1. [cursor.com/automations](https://cursor.com/automations) → **Create Automation**
2. **Repository**: `rick-chick/agrr`、branch **`master`**（空欄にしない）
3. **Trigger** → Schedule → Custom cron（**5 フィールドのみ**）
   - ❌ `0 0 9 * * 1-5`（6 フィールド）→ `Invalid trigger`
   - ✅ `0 9 * * 1-5`
4. **Timezone**: `Asia/Tokyo`
5. **Tools**: Issue Worker は **Pull request creation** を ON
6. **Memories**: ON 推奨（前回の対象 issue・スキップ理由を記録）
7. プロンプトは各スキルの「Automation」節をコピー
8. **Run test** で通ることを確認してから Save

### Prefill URL（フォーム事前入力）

UI で作る代わりに、次の URL を開いてから Trigger を確認・Save してもよい。

- **Issue Worker（平日 9:00）**: [prefill を開く](https://cursor.com/automations/new?prefill=eyJuYW1lIjoiQUdSUiBJc3N1ZSBXb3JrZXIgKOW5s-aXpSA5OjAwIEpTVCkiLCJkZXNjcmlwdGlvbiI6InJpY2stY2hpY2svYWdyciDjga7jgqrjg7zjg5fjg7MgaXNzdWUg44KSIDEg5Lu26YG444GzIFRERCDlrp_oo4Ug4oaSIFBSIiwid29ya2Zsb3ciOnsidHJpZ2dlcnMiOlt7ImNyb24iOnsiY3JvbiI6IjAgOSAqICogMS01IiwidGltZXpvbmUiOiJBc2lhL1Rva3lvIn19XSwicHJvbXB0cyI6W3sicHJvbXB0IjoiWW91IGFyZSB0aGUgQUdSUiBHaXRIdWIgSXNzdWUgV29ya2VyIGZvciByZXBvc2l0b3J5IHJpY2stY2hpY2svYWdyci5cblxuUmVhZCBhbmQgZm9sbG93IGAuY3Vyc29yL3NraWxscy9naXRodWItaXNzdWUtd29ya2VyL1NLSUxMLm1kYCBleGFjdGx5LlxuQWZ0ZXIgVEREIEdSRUVOLCBhbHdheXMgcnVuIGAuY3Vyc29yL3NraWxscy9zZXF1ZW50aWFsLWNsZWFudXAtcmV2aWV3LXdvcmtmbG93L1NLSUxMLm1kYCAowqc0KSBiZWZvcmUgb3BlbmluZyBhIFBSLlxuXG5Db25zdHJhaW50czpcbi0gT25lIGlzc3VlIHBlciBydW4gbWF4aW11bS5cbi0gVXNlIHRlc3QtY29tbW9uIG9ubHkgKG5ldmVyIG5wbSB0ZXN0IC8gcmFpbHMgdGVzdCBkaXJlY3RseSkuXG4tIERvIG5vdCBnaXQgY2hlY2tvdXQvc3dpdGNoL3Jlc2V0L3Jlc3RvcmUuXG4tIElmIG5vIGVsaWdpYmxlIGlzc3VlLCBleGl0IHdpdGhvdXQgUFIuIn1dLCJnaXRDb25maWciOnsicmVwbyI6Imh0dHBzOi8vZ2l0aHViLmNvbS9yaWNrLWNoaWNrL2FncnIiLCJyZXBvcyI6WyJodHRwczovL2dpdGh1Yi5jb20vcmljay1jaGljay9hZ3JyIl0sImJyYW5jaCI6Im1hc3RlciJ9LCJtZW1vcnlFbmFibGVkIjp0cnVlLCJhZ2VudE9wdGlvbnMiOnsib3BlblB1bGxSZXN0Ijp0cnVlfX19)
- **UX Issue Audit（月曜 9:00）**: [prefill を開く](https://cursor.com/automations/new?prefill=eyJuYW1lIjoiQUdSUiBVWCBJc3N1ZSBBdWRpdCAo5pyI5pucIDk6MDAgSlNUKSIsImRlc2NyaXB0aW9uIjoidmlzdWFsLXJldmlldyArIENTUyDnm6Pmn7sg4oaSIGNvbGxlY3Qg4oaSIOODieODqeOCpOODqeODs--8iOmHjeikh-aZguOBr-i1t-elqOOBl-OBquOBhO-8iSIsIndvcmtmbG93Ijp7InRyaWdnZXJzIjpbeyJjcm9uIjp7ImNyb24iOiIwIDkgKiAqIDEiLCJ0aW1lem9uZSI6IkFzaWEvVG9reW8ifX1dLCJwcm9tcHRzIjpbeyJwcm9tcHQiOiJZb3UgYXJlIHRoZSBBR1JSIFVYIElzc3VlIEF1ZGl0IGF1dG9tYXRpb24gZm9yIHJpY2stY2hpY2svYWdyci5cblxuUmVhZCBgLmN1cnNvci9za2lsbHMvdXgtaXNzdWUtcGlwZWxpbmUvU0tJTEwubWRgIHNlY3Rpb24gKipBdXRvbWF0aW9u77yI44K544Kx44K444Ol44O844Or77yJKiogYW5kIGZvbGxvdyBpdCBleGFjdGx5LlxuXG5TdW1tYXJ5OlxuLSBSdW4gcGhhc2VzIDMtNCBvbmx5IChOTyBlMmUgY2FwdHVyZTsgY2xvdWQgaGFzIG5vIGxvY2FsIFJhaWxzL25nKS5cbi0gUnVuIGNvbGxlY3QtdXgtZmluZGluZ3MubWpzIGFuZCB1eC1pc3N1ZS1jcmVhdG9yIGRyeS1ydW4uXG4tIERvIE5PVCBnaCBpc3N1ZSBjcmVhdGUgd2hlbiBleGlzdGluZ0lzc3VlQ2FuZGlkYXRlcyBoYXMgT1BFTiB3aXRoIHNjb3JlID49IDUuXG4tIFdyaXRlIHN1bW1hcnkgdG8gYXV0b21hdGlvbiBtZW1vcnk7IG9wZW4gUFIgb25seSBpZiB2aXN1YWwtcmV2aWV3LXJlc3VsdHMubWQgd2FzIGxlZ2l0aW1hdGVseSB1cGRhdGVkIGluLXJlcG8uXG4tIE5ldmVyIG9wZW4gUFIgZm9yIGltcGxlbWVudGF0aW9uICh0aGF0IGlzIGdpdGh1Yi1pc3N1ZS13b3JrZXIpLiJ9XSwiZ2l0Q29uZmlnIjp7InJlcG8iOiJodHRwczovL2dpdGh1Yi5jb20vcmljay1jaGljay9hZ3JyIiwicmVwb3MiOlsiaHR0cHM6Ly9naXRodWIuY29tL3JpY2stY2hpY2svYWdyciJdLCJicmFuY2giOiJtYXN0ZXIifSwibWVtb3J5RW5hYmxlZCI6dHJ1ZSwiYWdlbnRPcHRpb25zIjp7Im9wZW5QdWxsUmVxdWVzdCI6ZmFsc2V9fX0)

Prefill で **Trigger が Invalid** になる場合は、UI から手動で cron を入れ直す（[github-issue-worker SKILL](../github-issue-worker/SKILL.md) §セットアップと同じ）。

## Issue Worker（実装）

**目的**: オープン issue を 1 件選び TDD → PR。

**Webhook**（ラベル即時）: `.github/workflows/issue-worker-dispatch.yml`

| Secret | 内容 |
|--------|------|
| `CURSOR_ISSUE_WORKER_WEBHOOK_URL` | Automation の Webhook URL |
| `CURSOR_ISSUE_WORKER_WEBHOOK_KEY` | Webhook API key |

ラベル `agent-ready` / `agent-close` で起動。

## UX Issue Audit（監査・起票準備）

**目的**: リポジトリ上の `visual-review-results.md` を前提に、CSS 監査 + 草案生成 + ドライラン。**キャプチャはローカル手動**。

フルキャプチャ後に `visual-review-results.md` を commit してから週次 Audit が意味を持つ。

## GitHub CLI 認証（Cloud Agent）

Cloud Agent は **2 種類のトークン**を使い分ける。

| 用途 | トークン | 設定 |
|------|----------|------|
| `git clone` / `git push` / PR 作成 | Cursor GitHub App（`ghs_…`） | Dashboard → Integrations → GitHub |
| `gh issue list` / `gh issue create` / `gh pr comment` | **ユーザー PAT** | Dashboard → Cloud Agents → Secrets |

統合トークンだけでは `gh issue list` が失敗し、`collect-ux-findings.mjs` が `githubLookupStatus: failed` になる（起票禁止）。

### 手順

1. **GitHub App を接続**（未接続なら）
   - [cursor.com/dashboard](https://cursor.com/dashboard) → **Integrations** → **GitHub** → Connect
   - `rick-chick/agrr` に read/write（Issues, Pull requests, Contents）

2. **Fine-grained PAT を発行**（GitHub → Settings → Developer settings → Fine-grained tokens）
   - Repository: `rick-chick/agrr` のみ
   - Permissions: **Issues** Read and write、**Pull requests** Read and write、**Contents** Read（push は App が担当するが `gh auth setup-git` 用）
   - 有効期限は運用に合わせて設定

3. **Cursor Secrets に登録**
   - Dashboard → **Cloud Agents** → **Secrets**（User または Team scope）
   - 変数名: **`AGRR_GH_PAT`**（値に PAT を貼る）
   - ❌ `GITHUB_TOKEN` / `GH_TOKEN` は使わない（Cursor が `ghs_…` を上書き注入する場合がある）

4. **リポジトリ側の bootstrap**（`master` にマージ済みであること）
   - `.cursor/environment.json` の `install` が `.cursor/scripts/cloud-gh-auth.sh` を実行し、`AGRR_GH_PAT` で `gh auth login --with-token` する
   - Automation の **Repository** を `rick-chick/agrr` / branch `master` に設定

5. **確認** — Automation で **Run test** を実行し、ログで次を確認:
   - `gh auth status` に `rick-chick`（`gho_` / `github_pat_`）が表示される
   - `gh issue list --repo rick-chick/agrr --limit 1` が成功する

### Team Owned Automation の場合

Team scope の Secret に `AGRR_GH_PAT` を置く。Personal OAuth ではなく team service account 向けに PAT を発行するか、Team Visible / Private のまま作成者の user-scoped secret が注入されることを Run test で確認する。

## トラブルシュート

| 症状 | 対処 |
|------|------|
| Invalid trigger | cron を 5 フィールドに。TZ を Asia/Tokyo に |
| default branch エラー | `gitConfig.branch` を `master` に明示 |
| キャプチャ失敗 | Automation では phase 1 を実行しない（UX Audit） |
| 重複 issue 量産 | `existingIssueCandidates` score ≥ 5 で起票禁止を守る |
| `githubLookupStatus: failed` | 上記 **GitHub CLI 認証**を実施。`AGRR_GH_PAT` 未設定・`master` 未マージ・Webhook 経路で secret 未注入（既知バグ）を確認 |
| `gh auth status` が `ghs_…` のみ | `AGRR_GH_PAT` を Secrets に追加し Run test。`GITHUB_TOKEN` 名は使わない |
| Webhook 起動で secret が空 | 当面は Schedule / Run test / API 起動を使う（Cursor forum 既知バグ） |
| 課金が高い | Max Mode 固定。頻度を下げるか Team Owned の usage pool を確認 |

## 参照

- [Cursor Automations 公式](https://cursor.com/docs/cloud-agent/automations)
- `.cursor/skills/github-issue-worker/SKILL.md`
- `.cursor/skills/ux-issue-pipeline/SKILL.md`
