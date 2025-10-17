# Google Analytics 4 (GA4) セットアップガイド

## 📊 概要

AGRRでは、ユーザー行動を分析し、サービスを改善するためにGoogle Analytics 4を使用しています。

---

## 🚀 セットアップ手順

### 1. GA4プロパティを作成

1. [Google Analytics](https://analytics.google.com/) にアクセス
2. 「管理」→「プロパティを作成」
3. プロパティ名を入力（例: AGRR Production）
4. タイムゾーン: 日本
5. 通貨: 日本円
6. 「次へ」→ビジネスカテゴリを選択
7. 「作成」をクリック

### 2. 測定IDを取得

1. 「データストリーム」→「ウェブ」を選択
2. ウェブサイトのURL: `https://agrr-production-czyu2jck5q-an.a.run.app`
3. ストリーム名: AGRR Production
4. 「ストリームを作成」
5. **測定ID（G-XXXXXXXXXX）をコピー**

### 3. 測定IDを設定

`app/views/shared/_meta_tags.html.erb` の以下の2箇所を更新：

```erb
<!-- 変更前 -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-XXXXXXXXXX', {
    'anonymize_ip': true,
    'cookie_flags': 'SameSite=None;Secure'
  });
</script>

<!-- 変更後（G-XXXXXXXXXXを実際の測定IDに） -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-YOUR-ACTUAL-ID"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-YOUR-ACTUAL-ID', {
    'anonymize_ip': true,
    'cookie_flags': 'SameSite=None;Secure'
  });
</script>
```

`app/javascript/analytics.js` の以下の箇所も更新：

```javascript
// 変更前
export function trackPageView(pagePath) {
  if (isGA4Available()) {
    gtag('config', 'G-XXXXXXXXXX', {
      page_path: pagePath
    });
  }
}

// 変更後
export function trackPageView(pagePath) {
  if (isGA4Available()) {
    gtag('config', 'G-YOUR-ACTUAL-ID', {
      page_path: pagePath
    });
  }
}
```

### 4. デプロイ

```bash
source .env.gcp
./scripts/gcp-deploy.sh deploy
```

### 5. 動作確認

1. 本番環境にアクセス
2. ブラウザの開発者ツールで以下を確認：
   ```javascript
   // コンソールに入力
   typeof gtag
   // "function" が返ればOK
   ```
3. GA4ダッシュボードの「リアルタイム」でイベントを確認

---

## 📈 トラッキング可能なイベント

### 自動トラッキング
- ページビュー
- スクロール
- クリック（外部リンク）
- ファイルダウンロード

### カスタムイベント

#### 作付け計画関連
- `plan_creation_start` - 作付け計画作成開始
- `farm_size_select` - 農場サイズ選択
- `crop_select` - 作物選択
- `optimization_start` - 最適化開始
- `plan_completed` - 計画完成

#### ガントチャート関連
- `gantt_crop_click` - ガントチャート作物クリック

#### データ表示関連
- `climate_data_view` - 気候データ表示

#### AI機能関連
- `ai_crop_info` - AI作物情報取得

#### エラー関連
- `error` - エラー発生

---

## 🔧 カスタムイベントの追加方法

### JavaScriptから送信

```javascript
import { trackEvent } from './analytics.js';

// シンプルな例
trackEvent('button_click', {
  event_category: 'ui',
  button_name: 'submit'
});

// 詳細な例
trackEvent('custom_action', {
  event_category: 'custom',
  event_label: 'test',
  value: 123,
  custom_param: 'custom_value'
});
```

### 新しいイベントを追加

`app/javascript/analytics.js` に関数を追加：

```javascript
export function trackYourCustomEvent(param1, param2) {
  trackEvent('your_event_name', {
    event_category: 'your_category',
    param1: param1,
    param2: param2
  });
}
```

---

## 📊 レポートの見方

### リアルタイムレポート
- GA4ダッシュボード → 「リアルタイム」
- 現在のユーザー数、ページビュー、イベントを確認

### イベントレポート
- GA4ダッシュボード → 「レポート」→「エンゲージメント」→「イベント」
- 各イベントの発生回数、ユーザー数を確認

### カスタムレポート
1. 「探索」→「空白」
2. ディメンション・指標を追加
3. 独自の分析レポートを作成

---

## 🔒 プライバシー対応

### IP匿名化
```javascript
gtag('config', 'G-YOUR-ID', {
  'anonymize_ip': true  // 有効
});
```

### Cookie設定
```javascript
gtag('config', 'G-YOUR-ID', {
  'cookie_flags': 'SameSite=None;Secure'
});
```

### プライバシーポリシー
`app/views/pages/privacy.html.erb` に記載済み：
- Google Analyticsの使用について
- データ収集の目的
- オプトアウト方法

---

## 🐛 トラブルシューティング

### イベントが送信されない

```javascript
// コンソールで確認
console.log('GA4 available:', typeof gtag === 'function');

// イベント送信テスト
gtag('event', 'test_event', { test: 'value' });
```

### CSPエラーが出る

`config/initializers/security.rb` を確認：
```ruby
policy.script_src :self, "https://www.googletagmanager.com", "https://www.google-analytics.com"
policy.connect_src :self, "https://www.google-analytics.com", "https://analytics.google.com"
```

### 開発環境で動作しない

**仕様です。** GA4は本番環境（`Rails.env.production?`）でのみ有効化されています。

---

## 📚 参考リンク

- [Google Analytics 4 公式ドキュメント](https://support.google.com/analytics/answer/9304153)
- [GA4 イベント測定](https://developers.google.com/analytics/devguides/collection/ga4/events)
- [プライバシーとデータ保護](https://support.google.com/analytics/topic/2919631)

---

**最終更新**: 2025-10-17

