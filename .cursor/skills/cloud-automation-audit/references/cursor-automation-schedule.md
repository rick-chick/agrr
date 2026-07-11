# Cursor Automation スケジュール設定（AGRR）

Cloud Agent がリポジトリを clone してスキルに従う。**ローカル Docker / ng は使えない**点に注意。

**正本**: 一覧・prefill・GitHub CLI 手順は **本ファイルのみ**を更新する。他スキルはここへリンクする。

## 一覧

| Automation | スキル | cron（5 フィールド） | TZ | PR |
|------------|--------|----------------------|-----|-----|
| **Issue Worker** | `github-issue-worker` | `0 9 * * 1-5` | Asia/Tokyo | ✅ 実装時 |
| **PR Merge Worker** | `github-pr-merge-worker` | —（イベント駆動） | — | ❌（マージのみ） |
| **UX Campaign Loop** | `ux-campaign-loop` | —（PR マージ後 webhook） | — | ❌（残件起票のみ・完了時に自身を無効化） |
| **UX Issue Audit** | `ux-issue-pipeline` § Automation | `0 9 * * 1` | Asia/Tokyo | ❌（起票は条件付き） |
| **Frontend E2E capture** | GitHub Actions（非 Automation） | `0 15 * * 0`（月曜 0:00 JST） | UTC | ❌（PNG artifact のみ） |
| **Automation Audit** | `cloud-automation-audit` | `0 10 * * 5` | Asia/Tokyo | ✅ クリティカル修正時のみ |

**Automation Audit** は金曜 10:00 JST。平日 Issue Worker と月曜 UX Audit の**直近 1 週間**を監査する。

## 共通手順

1. [cursor.com/automations](https://cursor.com/automations) → **Create Automation**
2. **Repository**: `rick-chick/agrr`、branch **`master`**（空欄にしない）
3. **Trigger** → Schedule → Custom cron（**5 フィールドのみ**）
   - ❌ `0 0 9 * * 1-5`（6 フィールド）→ `Invalid trigger`
   - ✅ `0 9 * * 1-5`
4. **Timezone**: `Asia/Tokyo`
5. **Tools**:
   - Issue Worker / Automation Audit → **Pull request creation** ON
   - UX Issue Audit → OFF
6. **Memories**: ON 推奨（スキップ理由・失敗記録・監査レポート）
7. プロンプトは各スキルの「Automation」節をコピー
8. **Run test** で通ることを確認してから Save

### Prefill URL（フォーム事前入力）

Prefill で **Trigger が Invalid** になる場合は UI から手動で cron を入れ直す。

- **Issue Worker（平日 9:00）**: [prefill を開く](https://cursor.com/automations/new?prefill=eyJuYW1lIjoiQUdSUiBJc3N1ZSBXb3JrZXIgKOW5s-aXpSA5OjAwIEpTVCkiLCJkZXNjcmlwdGlvbiI6InJpY2stY2hpY2svYWdyciDjga7jgqrjg7zjg5fjg7MgaXNzdWUg44KSIDEg5Lu26YG444GzIFRERCDlrp_oo4Ug4oaSIFBSIiwid29ya2Zsb3ciOnsidHJpZ2dlcnMiOlt7ImNyb24iOnsiY3JvbiI6IjAgOSAqICogMS01IiwidGltZXpvbmUiOiJBc2lhL1Rva3lvIn19XSwicHJvbXB0cyI6W3sicHJvbXB0IjoiWW91IGFyZSB0aGUgQUdSUiBHaXRIdWIgSXNzdWUgV29ya2VyIGZvciByZXBvc2l0b3J5IHJpY2stY2hpY2svYWdyci5cblxuUmVhZCBhbmQgZm9sbG93IGAuY3Vyc29yL3NraWxscy9naXRodWItaXNzdWUtd29ya2VyL1NLSUxMLm1kYCBleGFjdGx5LlxuQWZ0ZXIgVEREIEdSRUVOLCBhbHdheXMgcnVuIGAuY3Vyc29yL3NraWxscy9zZXF1ZW50aWFsLWNsZWFudXAtcmV2aWV3LXdvcmtmbG93L1NLSUxMLm1kYCAowqc0KSBiZWZvcmUgb3BlbmluZyBhIFBSLlxuXG5Db25zdHJhaW50czpcbi0gT25lIGlzc3VlIHBlciBydW4gbWF4aW11bS5cbi0gVXNlIHRlc3QtY29tbW9uIG9ubHkgKG5ldmVyIG5wbSB0ZXN0IC8gcmFpbHMgdGVzdCBkaXJlY3RseSkuXG4tIERvIG5vdCBnaXQgY2hlY2tvdXQvc3dpdGNoL3Jlc2V0L3Jlc3RvcmUuXG4tIElmIG5vIGVsaWdpYmxlIGlzc3VlLCBleGl0IHdpdGhvdXQgUFIuIn1dLCJnaXRDb25maWciOnsicmVwbyI6Imh0dHBzOi8vZ2l0aHViLmNvbS9yaWNrLWNoaWNrL2FncnIiLCJyZXBvcyI6WyJodHRwczovL2dpdGh1Yi5jb20vcmljay1jaGljay9hZ3JyIl0sImJyYW5jaCI6Im1hc3RlciJ9LCJtZW1vcnlFbmFibGVkIjp0cnVlLCJhZ2VudE9wdGlvbnMiOnsib3BlblB1bGxSZXN0Ijp0cnVlfX19)
- **UX Issue Audit（月曜 9:00）**: [prefill を開く](https://cursor.com/automations/new?prefill=eyJuYW1lIjoiQUdSUiBVWCBJc3N1ZSBBdWRpdCAo5pyI5pucIDk6MDAgSlNUKSIsImRlc2NyaXB0aW9uIjoidmlzdWFsLXJldmlldyArIENTUyDnm6Pmn7sg4oaSIGNvbGxlY3Qg4oaSIOODieODqeOCpOODqeODs--8iOmHjeikh-aZguOBr-i1t-elqOOBl-OBquOBhO-8iSIsIndvcmtmbG93Ijp7InRyaWdnZXJzIjpbeyJjcm9uIjp7ImNyb24iOiIwIDkgKiAqIDEiLCJ0aW1lem9uZSI6IkFzaWEvVG9reW8ifX1dLCJwcm9tcHRzIjpbeyJwcm9tcHQiOiJZb3UgYXJlIHRoZSBBR1JSIFVYIElzc3VlIEF1ZGl0IGF1dG9tYXRpb24gZm9yIHJpY2stY2hpY2svYWdyci5cblxuUmVhZCBgLmN1cnNvci9za2lsbHMvdXgtaXNzdWUtcGlwZWxpbmUvU0tJTEwubWRgIHNlY3Rpb24gKipBdXRvbWF0aW9u77yI44K544Kx44K444Ol44O844Or77yJKiogYW5kIGZvbGxvdyBpdCBleGFjdGx5LlxuXG5TdW1tYXJ5OlxuLSBSdW4gcGhhc2VzIDMtNCBvbmx5IChOTyBlMmUgY2FwdHVyZTsgY2xvdWQgaGFzIG5vIGxvY2FsIFJhaWxzL25nKS5cbi0gUnVuIGNvbGxlY3QtdXgtZmluZGluZ3MubWpzIGFuZCB1eC1pc3N1ZS1jcmVhdG9yIGRyeS1ydW4uXG4tIERvIE5PVCBnaCBpc3N1ZSBjcmVhdGUgd2hlbiBleGlzdGluZ0lzc3VlQ2FuZGlkYXRlcyBoYXMgT1BFTiB3aXRoIHNjb3JlID49IDUuXG4tIFdyaXRlIHN1bW1hcnkgdG8gYXV0b21hdGlvbiBtZW1vcnk7IG9wZW4gUFIgb25seSBpZiB2aXN1YWwtcmV2aWV3LXJlc3VsdHMubWQgd2FzIGxlZ2l0aW1hdGVseSB1cGRhdGVkIGluLXJlcG8uXG4tIE5ldmVyIG9wZW4gUFIgZm9yIGltcGxlbWVudGF0aW9uICh0aGF0IGlzIGdpdGh1Yi1pc3N1ZS13b3JrZXIpLiJ9XSwiZ2l0Q29uZmlnIjp7InJlcG8iOiJodHRwczovL2dpdGh1Yi5jb20vcmljay1jaGljay9hZ3JyIiwicmVwb3MiOlsiaHR0cHM6Ly9naXRodWIuY29tL3JpY2stY2hpY2svYWdyciJdLCJicmFuY2giOiJtYXN0ZXIifSwibWVtb3J5RW5hYmxlZCI6dHJ1ZSwiYWdlbnRPcHRpb25zIjp7Im9wZW5QdWxsUmVxdWVzdCI6ZmFsc2V9fX0)
- **Automation Audit（金曜 10:00）**: [prefill を開く](https://cursor.com/automations/new?prefill=eyJuYW1lIjoiQUdSUiBBdXRvbWF0aW9uIEF1ZGl0ICjph5Hmm5wgMTA6MDAgSlNUKSIsImRlc2NyaXB0aW9uIjoiSXNzdWUgV29ya2VyIC8gVVggQXVkaXQg44Gu5a6f6KGM57WQ5p6c55uj5p-744CC44Kv44Oq44OG44Kj44Kr44Or44GqIHJlcG8g5LiN5YW35ZCI44Gu44G_IFBSIiwid29ya2Zsb3ciOnsidHJpZ2dlcnMiOlt7ImNyb24iOnsiY3JvbiI6IjAgMTAgKiAqIDUiLCJ0aW1lem9uZSI6IkFzaWEvVG9reW8ifX1dLCJwcm9tcHRzIjpbeyJwcm9tcHQiOiJZb3UgYXJlIHRoZSBBR1JSIENsb3VkIEF1dG9tYXRpb24gQXVkaXQgZm9yIHJlcG9zaXRvcnkgcmljay1jaGljay9hZ3JyLlxuXG5SZWFkIGFuZCBmb2xsb3cgYC5jdXJzb3Ivc2tpbGxzL2Nsb3VkLWF1dG9tYXRpb24tYXVkaXQvU0tJTEwubWRgIGV4YWN0bHkuXG5cbkF1ZGl0IHRoZSBsYXN0IDcgZGF5cyBvZiBJc3N1ZSBXb3JrZXIgYW5kIFVYIElzc3VlIEF1ZGl0IHJ1bnMuIEZpeCBPTkxZIGNyaXRpY2FsIGJyZWFrYWdlcyBpbiB0aGUgcmVwb3NpdG9yeSAoYnJva2VuIHNraWxsIHBhdGhzLCBib290c3RyYXAvYXV0aCBzY3JpcHRzLCBmYWlsaW5nIGF1dG9tYXRpb24gc2NyaXB0cywgYnJva2VuIGlzc3VlLXdvcmtlci1kaXNwYXRjaCB3b3JrZmxvdykuIERvIE5PVCBtYWtlIHByb2FjdGl2ZSBpbXByb3ZlbWVudHMsIHByb21wdCB0d2Vha3MsIG9yIHNjaGVkdWxlIGNoYW5nZXMuXG5cbk9wZW4gYSBQUiBvbmx5IHdoZW4gYSBjcml0aWNhbCByZXBvLXNpZGUgZml4IGlzIHJlcXVpcmVkLiBJZiBhbGwgYXV0b21hdGlvbnMgYXJlIGhlYWx0aHkgb3IgaXNzdWVzIGFyZSBEYXNoYm9hcmQtb25seSwgd3JpdGUgdGhlIGF1ZGl0IHJlcG9ydCB0byBhdXRvbWF0aW9uIG1lbW9yeSBhbmQgZXhpdCB3aXRob3V0IGEgUFIuIn1dLCJnaXRDb25maWciOnsicmVwbyI6Imh0dHBzOi8vZ2l0aHViLmNvbS9yaWNrLWNoaWNrL2FncnIiLCJyZXBvcyI6WyJodHRwczovL2dpdGh1Yi5jb20vcmljay1jaGljay9hZ3JyIl0sImJyYW5jaCI6Im1hc3RlciJ9LCJtZW1vcnlFbmFibGVkIjp0cnVlLCJhZ2VudE9wdGlvbnMiOnsib3BlblB1bGxSZXF1ZXN0Ijp0cnVlfX19)
- **PR Merge Worker（PR / CI）**: [prefill を開く](https://cursor.com/automations/new?prefill=eyJuYW1lIjoiQUdSUiBQUiBNZXJnZSBXb3JrZXIiLCJkZXNjcmlwdGlvbiI6InJpY2stY2hpY2svYWdyciDjga7lr77osaEgUFIg44KSIENJIOmAmumBjuW-jOOBq-ODrOODk-ODpeODvOODu-S_ruato-OBl-OBpiBzcXVhc2gg44Oe44O844K4Iiwid29ya2Zsb3ciOnsidHJpZ2dlcnMiOlt7ImdpdCI6eyJldmVudCI6ImNpQ29tcGxldGVkIiwicmVwb3MiOlsiaHR0cHM6Ly9naXRodWIuY29tL3JpY2stY2hpY2svYWdyciJdfX0seyJnaXQiOnsiZXZlbnQiOiJwdWxsUmVxdWVzdE9wZW5lZCIsInJlcG9zIjpbImh0dHBzOi8vZ2l0aHViLmNvbS9yaWNrLWNoaWNrL2FncnIiXX19XSwicHJvbXB0cyI6W3sicHJvbXB0IjoiWW91IGFyZSB0aGUgQUdSUiBHaXRIdWIgUFIgTWVyZ2UgV29ya2VyIGZvciByZXBvc2l0b3J5IHJpY2stY2hpY2svYWdyci5cblxuUmVhZCBhbmQgZm9sbG93IGAuY3Vyc29yL3NraWxscy9naXRodWItcHItbWVyZ2Utd29ya2VyL1NLSUxMLm1kYCBleGFjdGx5LlxuXG5PbmUgUFIgcGVyIHJ1bi4gTmV2ZXIgbWVyZ2UgYmVmb3JlIHJlcXVpcmVkIENJIGNoZWNrcyBwYXNzLiBGb3IgYnVnZml4ZXMsIHZlcmlmeSB0ZXN0IGNvdmVyYWdlIGFuZCBydW4gaW1wYWN0IGFuYWx5c2lzIGJlZm9yZSBtZXJnaW5nLiJ9XSwiZ2l0Q29uZ2ZpZyI6eyJyZXBvIjoiaHR0cHM6Ly9naXRodWIuY29tL3JpY2stY2hpY2svYWdyciIsInJlcG9zIjpbImh0dHBzOi8vZ2l0aHViLmNvbS9yaWNrLWNoaWNrL2FncnIiXSwiYnJhbmNoIjoibWFzdGVyIn0sIm1lbW9yeUVuYWJsZWQiOnRydWUsImFnZW50T3B0aW9ucyI6eyJvcGVuUHVsbFJlcXVlc3QiOmZhbHNlfX19)

## Issue Worker（実装）

**目的**: オープン issue を 1 件選び TDD → PR。

詳細: [github-issue-worker/SKILL.md](../../github-issue-worker/SKILL.md) §セットアップ

**Webhook**（ラベル即時）: `.github/workflows/issue-worker-dispatch.yml`

| Secret | 内容 |
|--------|------|
| `CURSOR_ISSUE_WORKER_WEBHOOK_URL` | Automation の Webhook URL |
| `CURSOR_ISSUE_WORKER_WEBHOOK_KEY` | Webhook API key |

ラベル `agent-ready` / `agent-close` で起動。

## PR Merge Worker（マージ）

**目的**: オプトイン対象 PR を CI 通過後にレビューし、問題なければ squash マージ。軽微な不備は同一ブランチで修正。

詳細: [github-pr-merge-worker/SKILL.md](../../github-pr-merge-worker/SKILL.md)

**Trigger（Cursor UI）**

1. **CI completed** — `rick-chick/agrr`（**推奨・主トリガー**）
2. **Webhook** — `.github/workflows/pr-merge-worker-dispatch.yml`（**Backend test 完了時** — ruleset 3 context すべて SUCCESS 後に dispatch + PR `opened` / `agent-merge` ラベル / **`master` push 後のコンフリクト** / PR `synchronize` で `mergeable: CONFLICTING`）
3. **Pull request opened** — 任意（workflow の `agent-merge-in-progress` / §0 で重複抑止）

**硬いゲート**: ruleset **master CI required** — `rails-test`, `frontend-test`, `lint / frontend-lint`

| Secret | 内容 |
|--------|------|
| `CURSOR_PR_MERGE_WEBHOOK_URL` | Automation の Webhook URL |
| `CURSOR_PR_MERGE_WEBHOOK_KEY` | Webhook API key |

**GitHub repo secrets（必須・初回のみ）**

1. [PR Merge Worker Automation](https://cursor.com/automations/dd9379bd-28c3-4e4b-8143-b5decc0ecd7e) → **Webhook** トリガーから URL と API key をコピー
2. リポジトリ secrets に登録:

```bash
gh secret set CURSOR_PR_MERGE_WEBHOOK_URL --repo rick-chick/agrr
gh secret set CURSOR_PR_MERGE_WEBHOOK_KEY --repo rick-chick/agrr
```

未設定のまま eligible PR が dispatch されると `PR Merge Worker Dispatch` workflow が **exit 1**（Actions 失敗で気づく）。

**対象 PR（いずれか）**: ラベル `agent-merge` / head `issue/<number>-*` / 本文 `Merge-Strategy: agent`

**Tools**: Comment on pull request（Approvals ON）、Pull request creation OFF、Memories ON

### Automation 用プロンプト（コピペ）

```
You are the AGRR GitHub PR Merge Worker for repository rick-chick/agrr.

Read and follow `.cursor/skills/github-pr-merge-worker/SKILL.md` exactly.

One PR per run. Never merge before required CI checks pass. For bugfixes, verify test coverage and run impact analysis before merging.
```

Issue Worker が開いた PR には `agent-merge` ラベルが付く（[github-issue-worker/SKILL.md](../../github-issue-worker/SKILL.md) §6）。

## UX Campaign Loop（マージ後・残件起票）

**目的**: UX キャンペーン（戻るボタン廃止・パンくず統一など）を **マージ後も完了するまで回す**。1 issue→PR では終わらない場合、マージ後に機械スキャンし、残件を issue 化。全体完了時は **本 Automation を無効化**。

詳細: [ux-campaign-loop/SKILL.md](../../ux-campaign-loop/SKILL.md)

**Trigger**: Webhook のみ（`.github/workflows/ux-campaign-review-dispatch.yml` が **PR merged** 後に dispatch）

| Secret | 内容 |
|--------|------|
| `CURSOR_UX_CAMPAIGN_REVIEW_WEBHOOK_URL` | Automation Webhook URL |
| `CURSOR_UX_CAMPAIGN_REVIEW_WEBHOOK_KEY` | Webhook API key |

**対象 PR**: リンク issue に `ux-campaign:breadcrumb` ラベル、または PR/issue 本文にキャンペーン記述

**Tools**: Pull request creation **OFF**（`gh issue create` で起票）、Memories ON

**Prefill**: [UX Campaign Loop（breadcrumb）](https://cursor.com/automations/new?prefill=eyJuYW1lIjoiQUdSUiBVWCBDYW1wYWlnbiBMb29wIChicmVhZGNydW1iKSIsImRlc2NyaXB0aW9uIjoiUFLjg57jg7zjgrjlvozjgavmiLvjgovjg5zjgr_jg7Pmrovku7bjgpLjgrnjgq3jg6Pjg7PjgILmnKrlrozkuobjgarjgolpc3N1Zei1t-elqOOAgeWujOS6huOBquOCiUF1dG9tYXRpb27nhKHlirnljJYiLCJ3b3JrZmxvdyI6eyJ0cmlnZ2VycyI6W3sid2ViaG9vayI6e319XSwicHJvbXB0cyI6W3sicHJvbXB0IjoiWW91IGFyZSB0aGUgQUdSUiBVWCBDYW1wYWlnbiBMb29wIChwb3N0LW1lcmdlIHJldmlld2VyKSBmb3Igcmljay1jaGljay9hZ3JyLlxuXG5SZWFkIGFuZCBmb2xsb3cgYC5jdXJzb3Ivc2tpbGxzL3V4LWNhbXBhaWduLWxvb3AvU0tJTEwubWRgIGV4YWN0bHkuXG5cbldlYmhvb2sgcGF5bG9hZDogcHJfbnVtYmVyLCBwcl90aXRsZSwgcHJfdXJsLCBtZXJnZWQsIGhlYWRfcmVmLCBjYW1wYWlnbl9pZCwgbGlua2VkX2lzc3VlX251bWJlcnMuXG5cblN0ZXBzOlxuMS4gUnVuIGBub2RlIC5jdXJzb3Ivc2tpbGxzL3V4LWNhbXBhaWduLWxvb3Avc2NyaXB0cy9zY2FuLWJyZWFkY3J1bWItY2FtcGFpZ24ubWpzYFxuMi4gUmVhZCBgZnJvbnRlbmQvZTJlL2FnZW50LXJldmlldy9icmVhZGNydW1iLWNhbXBhaWduLXNjYW4uanNvbmBcbjMuIElmIGNhbXBhaWduQ29tcGxldGUgPT09IHRydWU6IHJlY29yZCB0byBtZW1vcnksIGNsb3NlIHRyYWNraW5nIGlzc3VlIGlmIGFueSwgc2V0IFRISVMgYXV0b21hdGlvbiBlbmFibGVkOiBmYWxzZSwgZXhpdC5cbjQuIElmIGZhbHNlOiBkZWR1cGUgd2l0aCBnaCBpc3N1ZSBsaXN0LCBjcmVhdGUgdXAgdG8gMyBuZXcgaXNzdWVzIHdpdGggbGFiZWxzIHV4LWNhbXBhaWduOmJyZWFkY3J1bWIgYW5kIGFnZW50LXJlYWR5LiBOZXZlciBvcGVuIGltcGxlbWVudGF0aW9uIFBScy5cblxuQ29uc3RyYWludHM6XG4tIE9uZSBjYW1wYWlnbiByZXZpZXcgcGVyIHJ1bi5cbi0gRG8gbm90IGdpdCBjaGVja291dC9zd2l0Y2gvcmVzZXQvcmVzdG9yZS5cbi0gRG8gbm90IGRpc2FibGUgYXV0b21hdGlvbiB1bmxlc3MgY2FtcGFpZ25Db21wbGV0ZSBpcyB0cnVlLiJ9XSwiZ2l0Q29uZmlnIjp7InJlcG8iOiJodHRwczovL2dpdGh1Yi5jb20vcmljay1jaGljay9hZ3JyIiwicmVwb3MiOlsiaHR0cHM6Ly9naXRodWIuY29tL3JpY2stY2hpY2svYWdyciJdLCJicmFuY2giOiJtYXN0ZXIifSwibWVtb3J5RW5hYmxlZCI6dHJ1ZSwiYWdlbnRPcHRpb25zIjp7Im9wZW5QdWxsUmVxdWVzdCI6ZmFsc2V9fX0)

**作成済み Automation**: [e3536984-7b74-11f1-ba66-0e7d0216e441](https://cursor.com/automations/e3536984-7b74-11f1-ba66-0e7d0216e441) — Webhook URL/key は UI の Webhook トリガーから secrets へ登録

ループ: issue（`ux-campaign:breadcrumb`）→ Issue Worker → PR → PR Merge Worker → **本 Automation** → 残件 issue（`agent-ready`）→ … → scan 完了 → Automation 無効化

## UX Issue Audit（監査・起票準備）

**目的**: リポジトリ上の `visual-review-results.md` を前提に、CSS 監査 + 草案 + 条件付き起票。**キャプチャはローカル手動**。

詳細: [ux-issue-pipeline/SKILL.md](../../ux-issue-pipeline/SKILL.md) § Automation

フルキャプチャ後に `visual-review-results.md` を commit してから週次 Audit が意味を持つ。

## Automation Audit（実行結果監査）

**目的**: 上記 Automation の実行結果と依存物を監査。**クリティカルな不具合のみ** repo 修正 PR。

**PR を開く条件**: P0/P1 の repo 側根因のみ（[SKILL.md](../SKILL.md) §3）。それ以外は Memory レポートのみ。

### Automation 用プロンプト（コピペ）

```
You are the AGRR Cloud Automation Audit for repository rick-chick/agrr.

Read and follow `.cursor/skills/cloud-automation-audit/SKILL.md` exactly.

Audit the last 7 days of Issue Worker and UX Issue Audit runs using GitHub side effects and repository smoke tests (you cannot read other automations' run logs or memories). Fix ONLY critical breakages in the repository. Do NOT make proactive improvements.

Open a PR only when a critical repo-side fix is required. Otherwise write the audit report to automation memory and exit without a PR.
```

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
   - Permissions: **Issues** Read and write、**Pull requests** Read and write、**Contents** Read
   - 有効期限は運用に合わせて設定

3. **Cursor Secrets に登録**
   - Dashboard → **Cloud Agents** → **Secrets**（User または Team scope）
   - 変数名: **`AGRR_GH_PAT`**
   - ❌ `GITHUB_TOKEN` / `GH_TOKEN` は使わない

4. **リポジトリ側の bootstrap**（`master` にマージ済みであること）
   - `.cursor/environment.json` → `.cursor/scripts/cloud-gh-auth.sh`
   - Automation の **Repository** を `rick-chick/agrr` / branch `master` に設定

5. **確認** — Automation で **Run test**:
   - `gh auth status` に `gho_` / `github_pat_` が表示される
   - `gh issue list --repo rick-chick/agrr --limit 1` が成功する
   - PR Merge Worker 用: テスト PR で `gh pr checks` が ruleset 3 context を表示し、PAT に merge 権限があること（`gh pr merge --help` が通ること。dry-run は gh 未対応のため権限は Dashboard の Fine-grained PAT 設定で確認）

### Team Owned Automation の場合

Team scope の Secret に `AGRR_GH_PAT` を置く。Run test で注入を確認する。

## トラブルシュート

| 症状 | 対処 |
|------|------|
| Invalid trigger | cron を 5 フィールドに。TZ を Asia/Tokyo に |
| default branch エラー | `gitConfig.branch` を `master` に明示 |
| キャプチャ失敗 | Automation では phase 1 を実行しない（UX Audit）。PNG は **CI artifact**（`frontend-e2e-capture.yml`）またはローカル `run-e2e-capture-ci.sh` |
| 重複 issue 量産 | `existingIssueCandidates` score ≥ 5 で起票禁止を守る |
| `githubLookupStatus: failed` | **GitHub CLI 認証**を実施。1 週は Memory 記録、**2 週連続**で P1 エスカレーション |
| `gh auth status` が `ghs_…` のみ | `AGRR_GH_PAT` を Secrets に追加 |
| Webhook secret 空 | Schedule / Run test を使用（既知バグ） |
| 監査で毎週 PR が開く | [SKILL.md](../SKILL.md) の P0/P1 定義を確認 |
| PR Merge が ruleset 無しでマージ | ruleset **master CI required** を確認 |
| `PR Merge Worker Dispatch` が secret 未設定で fail | 上記 **GitHub repo secrets** を設定 |
| Merge Worker が起動しない（Draft） | Issue Worker §6 の `gh pr ready` を確認 |
| 課金が高い | Max Mode 固定。頻度を下げるか Team Owned の usage pool を確認 |

## 参照

- [Cursor Automations 公式](https://cursor.com/docs/cloud-agent/automations)
- `.cursor/skills/github-pr-merge-worker/SKILL.md`
- `.cursor/skills/cloud-automation-audit/SKILL.md`
- `.cursor/skills/github-issue-worker/SKILL.md`
- `.cursor/skills/ux-issue-pipeline/SKILL.md`
