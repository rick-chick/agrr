# Phase 1: 調査手順（セッション問題の原因特定）

## 概要

「ログイン時は動くが非ログイン時に失敗する」場合、session/cookie の差分が原因。以下の手順で絞り込む。

---

## Step 1: 失敗フローの特定

対象機能の **API リクエスト順序** を整理する。

```
例: 農場選択 → サイズ選択 → 作物選択 → 計画作成 → 完了遷移
     GET farms   GET sizes   GET crops   POST plans   WebSocket+GET data
```

- どのステップまで成功し、どこから失敗するかを特定
- フロントエンドのコンポーネント → UseCase → Gateway → API endpoint の呼び出し順を追う

### 確認ポイント

| 確認項目 | 確認方法 |
|----------|----------|
| API エンドポイントの認証スキップ | コントローラの `skip_before_action :authenticate_user!` |
| CSRF スキップ | `skip_before_action :verify_authenticity_token` |
| フロント `withCredentials: true` | ApiClientService の HTTP 設定 |
| ActionCable の認可ロジック | Channel の `authorized?` メソッド |

---

## Step 2: session.id 依存箇所の洗い出し

プロジェクト内で `session.id` を使っている箇所を検索する。

```
検索対象:
  - session.id（Rails コントローラ）
  - request.session.id（ActionCable Connection）
  - session[...] = ...（セッション書き込み）
```

各箇所で **非ログイン時に session.id が nil になるか** を判定:

| 状態 | session.id の挙動 |
|------|-------------------|
| `_agrr_session` クッキーあり | 既存のセッション ID を返す |
| `_agrr_session` クッキーなし | nil → フォールバック次第 |

---

## Step 3: ログイン時 vs 非ログイン時の差分表

以下の表を埋めて差分を可視化する。

| 観点 | ログイン時 | 非ログイン時 |
|------|-----------|-------------|
| `cookies[:session_id]`（アプリ認証） | あり（OAuth で設定） | なし |
| `_agrr_session`（Rails セッション） | あり（OAuth フロー中に確立） | なし（ブラウザが拒否する可能性） |
| `session.id` の値 | 有効な SessionId | nil（クッキーなし時） |
| `current_user` | 実ユーザー | anonymous_user |
| ActionCable `connection.session_id` | セッション ID 文字列 | `""` (nil.to_s) |

**ポイント**: `_agrr_session` クッキーが OAuth フロー中にファーストパーティ Cookie として確立されるため、ログイン済みユーザーだけ session.id が有効になる。

---

## Step 3 の結果 → Phase 2 へ

差分表から「session.id が nil になることで何が壊れるか」を特定したら、[SESSION_PATTERNS.md](SESSION_PATTERNS.md) で既知パターンに照合する。
