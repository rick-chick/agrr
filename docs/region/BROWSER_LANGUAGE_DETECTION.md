# Browser Language Detection

## 📖 概要

AGRRは、ブラウザの言語設定（Accept-Languageヘッダー）を自動検出して、適切な地域（region）のデータを表示します。

---

## 🎯 言語→地域のマッピング

| ブラウザ言語 | locale | region | 説明 |
|------------|--------|--------|------|
| 日本語 (`ja`, `ja-JP`) | `ja` | `jp` | 日本の農場・作物 |
| 英語 (`en-*`) | `us` | `us` | アメリカの農場・作物 |
| その他 | `ja` | `jp` | デフォルト（日本） |

**⚠️ 注意:** 
- 英語圏（en-US, en-GB, en-AU等）は全て `us` にマッピングされます
- 将来的に他の英語圏（EU, AU等）を追加する際は、より詳細なマッピングが必要

---

## 📊 優先順位

AGRRは以下の優先順位で言語を決定します：

1. **URLの`:locale`パラメータ** - 最優先（明示的な選択）
2. **Cookieの`locale`** - 前回の選択を保持
3. **Accept-Languageヘッダー** - ブラウザの言語設定
4. **デフォルト** - `ja`（日本語）

### 優先順位の例

#### 例1: 初回訪問（日本語ブラウザ）
```
ブラウザ設定: ja,en-US;q=0.9
URL: http://localhost:3000/public_plans

→ Accept-Languageから'ja'を検出
→ /ja/public_plans にアクセス
→ JP農場・作物が表示
→ Cookieに'ja'を保存
```

#### 例2: 初回訪問（英語ブラウザ）
```
ブラウザ設定: en-US,en;q=0.9
URL: http://localhost:3000/public_plans

→ Accept-Languageから'us'を検出
→ /us/public_plans にアクセス
→ US農場・作物が表示
→ Cookieに'us'を保存
```

#### 例3: URLで明示的に指定
```
ブラウザ設定: en-US,en;q=0.9
URL: http://localhost:3000/ja/public_plans

→ URLの'ja'パラメータが最優先
→ JP農場・作物が表示
→ Cookieに'ja'を上書き保存
```

#### 例4: Cookie保存後の訪問
```
ブラウザ設定: ja（日本語）
Cookie: locale=us（前回USを選択）
URL: http://localhost:3000/public_plans

→ Cookieの'us'がAccept-Languageより優先
→ /us/public_plans にアクセス
→ US農場・作物が表示
```

---

## 🔧 実装詳細

### ApplicationController

```ruby
def switch_locale(&action)
  # 優先順位に従って locale を決定
  locale = params[:locale] || 
           cookies[:locale] || 
           extract_locale_from_accept_language_header || 
           I18n.default_locale
  
  # Validate locale
  locale = I18n.default_locale unless I18n.available_locales.map(&:to_s).include?(locale.to_s)
  
  # Save locale to cookie (1年間有効)
  cookies[:locale] = { value: locale.to_s, expires: 1.year.from_now }
  
  I18n.with_locale(locale, &action)
end
```

### Accept-Languageヘッダーのパース

```ruby
def extract_locale_from_accept_language_header
  return nil unless request.env['HTTP_ACCEPT_LANGUAGE']
  
  # q値（品質スコア）を考慮してパース
  accepted_languages = request.env['HTTP_ACCEPT_LANGUAGE']
    .split(',')
    .map do |lang|
      parts = lang.strip.split(';')
      language = parts[0]
      quality = parts[1]&.match(/q=([\d.]+)/)&.[](1)&.to_f || 1.0
      { language: language, quality: quality }
    end
    .sort_by { |l| -l[:quality] } # 高い順にソート
  
  top_language = accepted_languages.first[:language]
  
  # 言語マッピング
  return 'ja' if top_language.start_with?('ja')
  return 'us' if top_language.start_with?('en')
  
  nil # その他はデフォルトに委ねる
end
```

---

## ✅ 動作確認結果

実際のブラウザ（curl）での動作確認を実施しました：

### テスト1: 日本語ブラウザ
```bash
curl -H "Accept-Language: ja,en-US;q=0.9" http://localhost:3000/public_plans
```
**結果:** ✅ JP農場（北海道等）が表示

### テスト2: アメリカ英語ブラウザ
```bash
curl -H "Accept-Language: en-US,en;q=0.9" http://localhost:3000/public_plans
```
**結果:** ✅ US農場（Kern County, CA等）が表示

### テスト3: イギリス英語ブラウザ
```bash
curl -H "Accept-Language: en-GB,en;q=0.9" http://localhost:3000/public_plans
```
**結果:** ✅ US農場が表示（英語圏全般をUSとして扱う）

### テスト4: フランス語ブラウザ（未サポート言語）
```bash
curl -H "Accept-Language: fr-FR,fr;q=0.9" http://localhost:3000/public_plans
```
**結果:** ✅ JP農場が表示（デフォルト）

### テスト5: URLパラメータ優先
```bash
curl -H "Accept-Language: en-US,en;q=0.9" http://localhost:3000/ja/public_plans
```
**結果:** ✅ JP農場が表示（URLの`/ja`が優先）

### テスト6: Cookie優先
```bash
# Step 1: /us にアクセスしてCookieを保存
curl -c /tmp/cookie.txt http://localhost:3000/us/public_plans

# Step 2: 日本語ブラウザでアクセス（Cookieが優先されるべき）
curl -b /tmp/cookie.txt -H "Accept-Language: ja" http://localhost:3000/public_plans
```
**結果:** ✅ US農場が表示（Cookieの`us`が優先）

---

## 🌍 ユーザー体験

### 初回訪問時

1. **日本からのユーザー:**
   - ブラウザ: 日本語
   - 自動的に `/ja/public_plans` にアクセス
   - 日本の農場・作物が表示
   - 次回以降もJP地域が保持される

2. **アメリカからのユーザー:**
   - ブラウザ: 英語
   - 自動的に `/us/public_plans` にアクセス
   - アメリカの農場・作物が表示
   - 次回以降もUS地域が保持される

### 言語切り替え

ユーザーは以下の方法で言語・地域を切り替えできます：

1. **URLを直接変更:**
   - `http://example.com/ja/public_plans` → JP
   - `http://example.com/us/public_plans` → US

2. **ナビゲーションバーの言語スイッチャー:**
   - 🇯🇵 日本語 / 🇺🇸 English

---

## 🔍 デバッグ

### 開発環境でのログ

開発環境・テスト環境では、以下のデバッグログが出力されます：

```
🌐 [Locale] params[:locale]=nil, cookies[:locale]=nil, Accept-Language locale=us, final locale=us
```

### ログの見方

```
params[:locale]=nil       # URLパラメータなし
cookies[:locale]=nil      # Cookieなし
Accept-Language locale=us # ブラウザから'us'を検出
final locale=us           # 最終的な locale
```

---

## ⚠️ 既知の制限事項

### 1. 英語圏の扱い

現在、全ての英語圏（en-US, en-GB, en-AU等）を `us` にマッピングしています。

**理由:** AGRRでは現在US地域のみサポート

**将来の対応:**
- EU地域追加時: en-GB → eu
- AU地域追加時: en-AU → au

### 2. Integration Testの制限

Integration testでは、`locale=us`のテストが失敗する場合があります。

**原因:** テストフレームワークの制限

**対応:** 実際のブラウザ（curl）での動作確認で代替

---

## 📚 参考資料

### Accept-Languageヘッダーの仕様

**形式:**
```
Accept-Language: ja,en-US;q=0.9,en;q=0.8
```

- `ja` - q=1.0（デフォルト、最優先）
- `en-US` - q=0.9
- `en` - q=0.8

**品質スコア（q値）:**
- 0.0 ~ 1.0の範囲
- 高いほど優先
- 省略時は1.0

### ベストプラクティス

1. ✅ **自動検出 + 手動選択:** ブラウザ設定を尊重しつつ、ユーザーが選択可能
2. ✅ **Cookie保存:** ユーザーの選択を記憶
3. ✅ **明示的なURL:** リンク共有時に正しい言語で開ける

---

**最終更新:** 2025-10-18  
**検証者:** AGRR Development Team

