# Phase 3: 修正・検証手順

診断パターンに基づき修正を実施し、テストで検証する。

---

## Step 1: 修正対象の特定

SESSION_PATTERNS.md で特定したパターンに応じて修正対象ファイルを列挙する。

### パターン A（session.id 依存排除）の典型的修正対象

| 修正対象 | ファイル例 | 修正内容 |
|----------|-----------|---------|
| コントローラの session.id 取得メソッド | `app/controllers/api/v1/public_plans/wizard_controller.rb` | `session.id` → `SecureRandom.hex(32)` |
| ActionCable Connection | `app/channels/application_cable/connection.rb` | `request.session&.id.to_s` で nil-safe |
| コントローラテスト | `test/controllers/.../wizard_controller_test.rb` | `session.id` 一致アサーション → hex 形式チェックに変更 |

---

## Step 2: 修正の実施

修正対象に応じたスキルに従って修正する（[CODE_MODIFICATION_SKILLS.md](../../references/CODE_MODIFICATION_SKILLS.md) 参照）。

### session.id → SecureRandom.hex 置換の要点

1. **既存の session.id は活用**: `session.id.present?` なら既存値を使う（ログイン済みユーザーの互換性維持）
2. **フォールバックのみ変更**: session.id が nil の場合に `SecureRandom.hex(32)` を返す
3. **セッション書き込み不要**: マーカー書き込み・削除のコードは削除
4. **raise を削除**: nil 時のフォールバックが確実なので例外不要

### ActionCable Connection の防御的修正

```ruby
# Before
self.session_id = request.session.id.to_s

# After
self.session_id = request.session&.id.to_s
```

---

## Step 3: テストの更新

### session.id 一致テストの変更

```ruby
# Before: session.id と plan.session_id の一致を検証
assert_equal session.id.to_s, plan.session_id

# After: session_id が存在し hex 形式であることを検証
assert plan.session_id.present?, 'session_id should be written to the plan'
assert_match(/\A[0-9a-f]{16,}\z/, plan.session_id)
```

### ActionCable テスト

既存の ActionCable テストが public plan の認可を `plan_type_public?` でテストしていれば変更不要。session_id マッチのテストがある場合は、public plan では session_id 不問であることを反映する。

---

## Step 4: テスト実行

`test-common` スキルに従ってテストを実行する。

```bash
# 修正対象のテストファイルを個別実行
COVERAGE=false ./.cursor/skills/test-common/scripts/run-test-rails.sh \
  test/controllers/api/v1/public_plans/wizard_controller_test.rb \
  test/channels/optimization_channel_test.rb

# 個別テスト GREEN 後、全体テストも実行（リグレッション確認）
COVERAGE=false ./.cursor/skills/test-common/scripts/run-test-rails.sh
```

---

## Step 5: 完了確認チェックリスト

```
- [ ] session.id 依存箇所が SecureRandom.hex に置換されている
- [ ] ActionCable Connection が nil-safe になっている
- [ ] テストが session.id 一致ではなく hex 形式チェックになっている
- [ ] 個別テストが GREEN
- [ ] 全体テストが GREEN（リグレッションなし）
- [ ] 0.5 秒超のスローテストがないことを確認
```
