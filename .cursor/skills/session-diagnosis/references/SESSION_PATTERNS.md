# Phase 2: セッション問題の診断パターン集

調査結果を以下のパターンに照合し、根本原因と修正方針を特定する。

---

## パターン A: session.id 依存 + 認可不要

**症状**: public エンドポイントで `session.id` を使っているが、認可には不要。

**診断条件**:
- コントローラが `skip_before_action :authenticate_user!` している
- `session.id` を `CultivationPlan.session_id` 等に保存している
- ActionCable Channel が `plan_type_public?` で認可バイパスしている
- PlanPolicy が `plan_type` のみチェックしている

**根本原因**: `session.id` が nil（非ログイン時にクッキーなし）で例外 or 空文字が保存される。

**修正方針**: `session.id` を `SecureRandom.hex(32)` に置換。セッション依存を排除。

```ruby
# Before
def ensure_session_id_for_public_plan
  return session.id.to_s if session.id.present?
  session[MARKER] = true  # フォールバック（不安定）
  session_id = session.id
  session.delete(MARKER)
  raise "Unable to initialize" if session_id.blank?
  session_id.to_s
end

# After
def ensure_session_id_for_public_plan
  return session.id.to_s if session.id.present?
  SecureRandom.hex(32)
end
```

---

## パターン B: SameSite=None + Secure=false（開発環境）

**症状**: 開発環境（HTTP）でクロスオリジンのクッキーが保存されない。

**診断条件**:
- `config/initializers/security.rb` で `same_site: :none, secure: Rails.env.production?`
- 開発環境は HTTP（非 HTTPS）で動作
- Chrome 80+ は `SameSite=None` に `Secure=true` を要求

**根本原因**: ブラウザが `SameSite=None; Secure=false` のクッキーを拒否する。

**修正方針**（選択肢）:
1. 開発環境を HTTPS にする
2. 開発環境のみ `same_site: :lax` にする
3. セッション依存を排除する（パターン A の修正と併用）

---

## パターン C: ActionCable 接続の session nil

**症状**: WebSocket 接続時に `request.session.id` が nil で、connection が失敗。

**診断条件**:
- `ApplicationCable::Connection#connect` で `request.session.id.to_s` を使用
- 非ログイン時にクッキーなし → `nil.to_s` → `""`
- Channel の認可が session_id マッチを要求

**根本原因**: ActionCable Connection が session nil を想定していない。

**修正方針**:
- `request.session&.id.to_s` で nil-safe にする
- public plan 用 Channel は `plan_type` で認可（session 不要）

---

## パターン D: 認証 API の副作用

**症状**: アプリ初期化時の `GET /api/v1/auth/me` が 401 を返し、セッション/クッキーに影響。

**診断条件**:
- `AuthService.loadCurrentUser()` が app 起動時に実行
- 非ログイン時は 401 → `catchError` で null 設定
- 401 レスポンスが Set-Cookie でセッションクッキーをクリアしていないか確認

**根本原因**: 通常は無害。401 がクッキーをクリアしていなければ問題なし。

**修正方針**: 401 レスポンスでクッキークリアしていないことを確認するだけ。修正不要の場合が多い。

---

## パターンの組み合わせ

実際の問題は複数パターンが組み合わさることが多い。典型的な組み合わせ:

| 組み合わせ | 優先修正 |
|-----------|---------|
| A + B | A を修正（session 依存排除）で B も解消 |
| A + C | A を修正 + C の防御的修正 |
| B のみ | 開発環境の cookie 設定を修正 |

→ 修正方針が決まったら [FIX_AND_VERIFY.md](FIX_AND_VERIFY.md) へ進む。
