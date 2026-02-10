# Feature Contract: お問い合わせフォーム + メール転送機能 (contact-form)

**作成日**: 2026-02-10
**作成者**: akishige
**機能概要**: サイト訪問者がAngularフロントエンド上のフォームから問い合わせを送信できるようにし、Railsサーバー側で受信した内容を指定された管理用メールアドレスに転送する機能を追加する。バックエンドはメール送信処理（Mailer）を提供し、送信の成否にかかわらず必ずメッセージをDBに保存する。
**ステータス**: draft

## ビジネス要件
- サイト上に表示している静的なダミーメールアドレスを廃止し、実際に使える問い合わせフォームを提供する。
- フォーム送信後、指定された管理者メールアドレスへ問い合わせ内容を転送する（SMTP経由）。
- フォーム送信後は常にDBに保存し、管理者が後で確認できるようにする。メール転送は試行し、失敗した場合は再試行キューに入れる等の仕組みを提供する。
- スパム対策（レート制限、reCAPTCHA 等）を導入できること。

### 受け入れ条件
- フロントのフォームから送信すると201レスポンスが返り、DBにレコードが作成される。status が "sent" の場合は管理者にメールが届く（正常系）。
- 無効な入力では422が返る（バリデーション）。
- メール転送が失敗した場合でもAPIは201を返し、status が "failed" として保存され、再試行ジョブをスケジュールする。

## 技術要件
- フロントエンド: Angular コンポーネント + UseCase 層経由でAPI呼び出し。クライアント側バリデーション。
- バックエンド: Rails APIエンドポイント + Mailer。環境変数で転送先メールアドレスを管理する。
-- DB: 送信履歴を必ず保持する（migration を追加する）。
- セキュリティ: CSRF対策、レートリミット、CAPTCHA の取り込み余地を残す。
- ロギング/監視: 送信失敗やバウンスをログに残す。

## Use Case: SubmitInquiry

### 概要
訪問者が問い合わせフォームに必要事項を入力し送信する。サーバーは入力検証後、指定先メールアドレスに内容を転送し、送信の成否にかかわらずメッセージをDBに保存して送信結果を返す。

### アクター
- Primary Actor: サイト訪問者 (anonymous)
- Supporting Actors: Rails Mailer, 管理者（メール受信者）

### 事前条件
- フロントで基本的な入力チェックが通っている（必須項目が埋まっている等）。
- サーバーに転送先メールアドレス（ENV: CONTACT_DESTINATION_EMAIL）が設定されている。

### 基本フロー
1. ユーザはフォームに入力して送信ボタンを押す。
2. AngularがPOST /api/v1/contact_messages を呼び出す。
3. Railsはリクエストボディをバリデーションする（email形式、message必須等）。
4. バリデーション通過後、Mailerで指定アドレスへメール送信を試みる（非同期ジョブに切り替える設計を推奨）。
5. メール送信の成否にかかわらず、送信内容をDBに保存する（status: "sent" または "failed" を設定、送信成功時は sent_at を記録）。
6. API は保存処理完了後に 201 Created と保存されたレコードの id と status を返す（例: { id: 123, status: "sent" }）。メール送信に失敗した場合は再試行ジョブをスケジュールする。

### 代替フロー
- Alt-1: reCAPTCHA 検証が失敗した場合 -> 403 Forbidden を返す。
- Alt-2: 同一IP/同一メールアドレスから短時間に大量送信があった場合 -> 429 Too Many Requests を返す。

### 事後条件
- 管理者が指定アドレスでメールを受け取る、またはメッセージがDBに保存される。

## API Specification

### Endpoint: POST /api/v1/contact_messages

**説明**: フロントから問い合わせを送信するエンドポイント。受信したデータをメールで転送し、送信の成否にかかわらずDBに保存する。

#### Request

Headers:
```
Content-Type: application/json
```

Request Body (application/json):
```json
{
  "name": "string | null",
  "email": "string",            // 送信者メールアドレス（返信に使用）
  "subject": "string | null",
  "message": "string",          // 必須
  "source": "string | null"     // 任意: フォームの識別子やページURL等
}
```

バリデーション:
- email: 必須/任意はプロダクト判断（推奨: 必須かつフォーマット検証）
- message: 必須、maxLength 5000
- name, subject: maxLength 255

#### Responses

Success (201 Created):
```json
{
  "id": 123,
  "status": "sent|failed",
  "created_at": "2026-02-10T12:34:56Z",
  "sent_at": "2026-02-10T12:35:00Z|null"
}
```

Validation Error (422 Unprocessable Entity):
```json
{
  "error": "Validation failed",
  "field_errors": {
    "email": ["is invalid"],
    "message": ["can't be blank"]
  }
}
```

Rate Limit (429):
```json
{ "error": "Too many requests" }
```

Server Error (500):
```json
{ "error": "Internal server error" }
```

### Endpoint: GET /api/v1/contact_messages (管理者向け, オプション)

**説明**: 送信履歴の一覧取得（管理者認証必須）。管理UIや将来の再送処理で使用。

Query Parameters:
| page | integer | false | 1 | ページ番号 |
| per_page | integer | false | 20 | 件数 |

Response (200):
```json
{
  "data": [
    {
      "id": 123,
      "name": "hoge",
      "email": "hoge@example.com",
      "subject": "件名",
      "message": "本文",
      "status": "sent|failed|queued",
      "created_at": "2026-02-10T12:34:56Z"
    }
  ],
  "meta": { "page": 1, "per_page": 20, "total": 1 }
}
```

## データモデル / Migration

### contact_messages テーブル（必須）

Columns:
- id: bigint PK
- name: string
- email: string
- subject: string
- message: text
- status: string (enum: sent, failed, queued) default: queued
- sent_at: datetime nullable
- created_at / updated_at

マイグレーション例（Rails）:
```ruby
create_table :contact_messages do |t|
  t.string :name
  t.string :email
  t.string :subject
  t.text :message, null: false
  t.string :status, null: false, default: "queued"
  t.datetime :sent_at
  t.timestamps
end
```

## 環境変数 / 設定
- CONTACT_DESTINATION_EMAIL (必須): 転送先メールアドレス
- SMTP_* (既存のSMTP設定を利用)
- CONTACT_RATE_LIMIT (例: 10/min)
- RECAPTCHA_SITE_KEY / SECRET_KEY (オプション)

## エラーハンドリング / 再試行
- メーラー送信失敗時は送信レコードを "failed" としてDBに保存し、ジョブキュー（ActiveJob/Sidekiq）で再試行する。再試行時は status を更新し、成功時は sent_at を設定する。
- 永続的に失敗する場合は管理者へアラートを投げる（メール/ログ収集）。

## フロントエンド要件（Angular）
- コンポーネント: `ContactFormComponent`
  - フィールド: name, email, subject, message, optional: source
  - バリデーション: required/format/maxLength
  - UI: 成功・エラーの通知（トースト等）、送信中のローディング表示
  - i18n: 日本語/英語対応文字列を準備
  - テスト: unit test（フォームバリデーション）とE2E（送信成功/失敗ケース）
- UseCase 層: `sendContactMessage` (HTTP gateway 経由で POST)
- Gateway: `contactGateway.postMessage(payload)` が contract に従う
- CSS/デザイン: `ContactFormComponent` は `.page-content-container` や `.form-card` 系のレイアウトクラスとグローバルデザイントークン（`--color-*`, `--space-*`, `--radius-*`, `--shadow-*`）を活用し、他画面と統一されたカード型フォーム・ボタン・余白を維持する。インラインスタイルは極力避け、`.form-card__field`, `.form-card__actions`, 共通ボタン `.btn`, `.btn-primary` など既存スタイルを再利用する。

## テスト要件
- Rails: request spec for POST /api/v1/contact_messages, mailer spec (正しく送信先にメールが作られること), job spec (再試行)。
- Angular: unit tests for form validation, integration/E2E test for successful送信とバリデーションエラー。
- 監査: 送信履歴がある場合は DB の read spec も追加。

## 実装タスク (Contract-First ワークフロー)

### Phase 1: 契約作成 (現在)
- [x] docs/contracts/contact-form-contract.md を作成（このファイル）

### Phase 2: UseCase 層（並列）
- [ ] usecase-server: Rails の UseCase 層（受信バリデーション、Mailer呼び出し、DB保存ロジック）を実装
- [ ] usecase-frontend: Angular の UseCase 層（sendContactMessage の実装）を実装

> 上記2つは並列で実行してください（subagents: usecase-server, usecase-frontend）。

### Phase 3: Adapter 層（並列）
- [ ] presenter-server / gateway-server / controller-server を実装（Rails Controller, Gateway, Presenter）
- [ ] presenter-frontend / gateway-frontend / controller-frontend を実装（Angular 側の Gateway, Presenter, Component）

### Phase 4: テスト・検証
- [ ] Rails / Angular の単体・統合テストを実装・実行
- [ ] スパム対策（reCAPTCHA, rate limiting）の有効化テスト
- [ ] 運用テスト（メール到達・失敗時アラート）

## レビューポイント
- API仕様（リクエスト/レスポンス/エラー）が明確か
- バリデーションとエラーハンドリングが十分か
- メール送信の再試行・失敗時の挙動が設計されているか
- セキュリティ（レートリミット、CAPTCHA）を考慮しているか

## 変更履歴
| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-02-10 | 0.1 | akishige | Initial draft contract for contact-form |

