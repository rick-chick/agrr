# Google AdSense セットアップガイド

## 実装状況

Google AdSenseの広告が以下の3つの画面に配置されています：

1. **最適化中の画面** (`app/views/public_plans/optimizing.html.erb`)
   - 作付け計画の最適化処理中に表示
   - 横長フォーマット推奨

2. **AI検索中の画面** (`app/views/crops/_form.html.erb`)
   - AI作物情報取得のポップアップ内に表示
   - レクタングルフォーマット推奨

3. **ガントチャート画面** (`app/views/public_plans/results/_gantt_chart.html.erb`)
   - 作付け計画の完成画面（ガントチャート下部）
   - 横長フォーマット推奨

## セキュリティ設定（完了済み）

Content Security Policy (CSP) の設定が完了しています：

- ✅ `pagead2.googlesyndication.com` を許可
- ✅ `adservice.google.com` を許可
- ✅ `googleads.g.doubleclick.net` を許可（iframe用）
- ✅ Nonce属性を使用してインラインスクリプトを許可

設定ファイル: `config/initializers/security.rb`

## AdSense 広告ユニット作成手順

### 1. AdSenseにログイン

https://www.google.com/adsense/ にアクセスして、パブリッシャーIDが `ca-pub-7498903562014256` のアカウントでログインします。

### 2. 広告ユニットを作成

各画面用に3つの広告ユニットを作成してください：

#### 広告ユニット1: 最適化中画面用
- 名前: `AGRR - 最適化中画面`
- 広告タイプ: **ディスプレイ広告**
- 形状: **横長バナー** (レスポンシブ推奨)
- 作成後に表示される **広告ユニットID** (`data-ad-slot` の値) をメモ

#### 広告ユニット2: AI検索中画面用
- 名前: `AGRR - AI検索中ポップアップ`
- 広告タイプ: **ディスプレイ広告**
- 形状: **レクタングル** (300x250 または レスポンシブ)
- 作成後に表示される **広告ユニットID** をメモ

#### 広告ユニット3: ガントチャート画面用
- 名前: `AGRR - ガントチャート結果`
- 広告タイプ: **ディスプレイ広告**
- 形状: **横長バナー** (レスポンシブ推奨)
- 作成後に表示される **広告ユニットID** をメモ

### 3. 広告ユニットIDを更新

作成した広告ユニットIDで、各ビューファイルの `ad_slot` パラメータを更新してください：

```ruby
# app/views/public_plans/optimizing.html.erb
<%= render 'shared/adsense_display_ad', ad_slot: 'ここに広告ユニットID', ad_format: 'horizontal' %>

# app/views/crops/_form.html.erb
<%= render 'shared/adsense_display_ad', ad_slot: 'ここに広告ユニットID', ad_format: 'rectangle' %>

# app/views/public_plans/results/_gantt_chart.html.erb
<%= render 'shared/adsense_display_ad', ad_slot: 'ここに広告ユニットID', ad_format: 'horizontal' %>
```

### 4. サイトをAdSenseに追加

1. AdSenseダッシュボード → **サイト** → **サイトを追加**
2. ドメイン `agrr.net` を入力
3. 確認コードを取得（既に`<head>`タグにAdSenseコードが含まれているため、自動的に検証されます）

### 5. ads.txt ファイルを配置

`public/ads.txt` ファイルを作成してください：

```
google.com, pub-7498903562014256, DIRECT, f08c47fec0942fa0
```

このファイルは既に配置されている可能性がありますが、念のため確認してください。

## テスト方法

### ローカル環境でのテスト

**注意**: 広告ブロッカーを無効にしてください！

1. ブラウザの拡張機能（AdBlock、uBlock Origin等）を無効化
2. ブラウザのトラッキング防止を無効化（特にEdge、Brave）
3. プライベート/シークレットモードで開く

### テスト画面URL

```bash
# 1. 最適化中画面
http://localhost:3000/public_plans/{plan_id}/optimizing

# 2. AI検索中画面（作物編集画面で「AIで作物情報を取得」ボタンをクリック）
http://localhost:3000/crops/new

# 3. ガントチャート画面
http://localhost:3000/public_plans/{plan_id}/results
```

### 本番環境での確認

- 広告が表示されるまで、サイト審査後 **数時間〜数日** かかる場合があります
- 最初はテスト広告が表示され、審査完了後に実際の広告が表示されます
- AdSenseダッシュボードで審査状況を確認できます

## トラブルシューティング

### 広告が表示されない場合

1. **ブラウザコンソールを確認**
   - CSPエラーが出ていないか
   - `ERR_BLOCKED_BY_CLIENT` → 広告ブロッカーを無効化

2. **AdSense審査状況を確認**
   - サイトが承認済みか
   - ads.txtが正しく配置されているか

3. **広告コードを確認**
   - `data-ad-client` が正しいか: `ca-pub-7498903562014256`
   - `data-ad-slot` が各広告ユニットIDに更新されているか

### CSPエラーが出る場合

`config/initializers/security.rb` で以下のドメインが許可されているか確認：

```ruby
policy.script_src  :self, "https://pagead2.googlesyndication.com", "https://adservice.google.com"
policy.frame_src   :self, "https://googleads.g.doubleclick.net", "https://tpc.googlesyndication.com"
```

## 収益化のヒント

- **動画広告の表示**: AdSenseの設定で動画広告を有効にすると、自動的に表示される可能性があります（単価が高め）
- **自動広告**: より多くの収益を得たい場合、AdSenseの「自動広告」機能も検討してください
- **パフォーマンス追跡**: AdSenseダッシュボードでCPM、CPC、収益を定期的に確認

## 参考情報

- [Google AdSense ヘルプ](https://support.google.com/adsense/)
- [広告ユニットの作成方法](https://support.google.com/adsense/answer/9274019)
- [ads.txt ガイド](https://support.google.com/adsense/answer/7532444)

