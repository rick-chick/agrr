# 作物スケジュール（エントリ）— トラブルシュート調査メモ

**目的**: 症状ごとに **事実（観測できるもの）** と **仮説（まだ証明していないもの）** を混同しない。

---

## A. 事実として確認できること（再現手順つき）

### A.1 サーバーがその URL で応答するか

```bash
curl -sS -w "\nHTTP %{http_code}\n" \
  "http://127.0.0.1:3000/api/v1/public_plans/entry_schedule/farms?region=jp"
```

- ここで得られるのは **curl が受け取った HTTP ステータスとボディ**だけである。  
- **ブラウザの同一リクエスト**と完全に一致するかは、**別途 Network タブで確認するまで分からない**（ホスト・クエリ・Cookie・拡張機能が違う可能性がある）。

### A.2 Rails がリクエストを処理したか

Puma の標準出力または `log/development.log` に、少なくとも次が出るか:

- `Started GET "..."`  
- `Processing by Api::V1::PublicPlans::EntryScheduleController#farms`  
- `Completed ...`

ログに `Completed 200 OK` があっても、**ブラウザがそのレスポンス本文を受け取ったか**はログだけでは分からない（プロキシ・キャンセル・別タブなど）。

### A.3 ブラウザ側で「そのリクエスト」単体を見る

開発者ツール → **Network** で `entry_schedule/farms` を選び、次を記録する:

| 観測項目 | 分かること |
|----------|------------|
| Status / 終了 | 失敗・キャンセル・保留の別 |
| Response 本文 | 配列か・空か・HTML 混入か |
| Timing | 待ち続けているのが TCP か TLS か応答待ちか |

**「読み込み中のまま」**は、(1) リクエストが **pending のまま**、(2) **失敗したが UI がエラー表示に切り替わっていない**、(3) **成功したが別理由で描画が更新されない**、のいずれかであり、**Network と Console を見ないと区別できない**。

---

## B. 仮説（検証が必要。単独では原因と断定しない）

以下はよく挙がる候補だが、**症状と時刻・ログの対応付け**なしに「原因はこれ」と言えない。

| 仮説 | 検証のしかた |
|------|----------------|
| API ベース URL が意図と違う | `getApiBaseUrl()` の結果と、Network の Request URL を突き合わせる |
| CORS / 資格情報 | Network で該当リクエストが **failed** になっていないか、Console に CORS 文言がないか |
| `ng serve` のコンパイルエラー | 当該時刻のターミナルに **ERROR** がないか。あっても「そのエラーがその画面症状を直接生んだ」とは **自動的には言えない**（ビルドは成功していてもキャッシュや別タブで古いバンドルが残る可能性は別問題） |
| 空配列 `[]` | Response が `[]` なら **データ件数**の問題（UI は「0 件」表示の設計次第） |
| 例外で変更検知が止まる | Console に赤エラーがないか |

---

## C. 混同しやすい別事象

- **`GET /api/v1/auth/me` が 401**  
  `Api::V1::BaseController` 系の認証と別系統。**`EntryScheduleController` は `ApplicationController` 直継承で `authenticate_user!` を skip** している。  
  **地域一覧 API の成功・失敗の判定には使えない**。

---

## D. レスポンス形式（仕様上の注意）

`latitude` / `longitude` が JSON で **文字列**になることがある（DB の型に依存）。  
一覧が **名前だけ**なら表示に影響しないことが多いが、数値演算を足すなら型を明示的に扱う。

---

## E. 関連ドキュメント

- API 契約: [docs/contracts/entry-schedule-contract.md](../contracts/entry-schedule-contract.md)
- 気象初期化: [crop_schedule_entry_weather_initialization.md](./crop_schedule_entry_weather_initialization.md)

---

## F. リポジトリ上で実行した確認（記録用・再実行可）

**注意**: 以下は **そのときローカルで Rails が :3000、コードが当該コミット** のときの結果。環境が違えばやり直す。

| 手順 | コマンド / 操作 | 結果（事実のみ） |
|------|-------------------|------------------|
| GET 本体 | `curl` … `/api/v1/public_plans/entry_schedule/farms?region=jp` | **200**、本文先頭は `[{`（JSON 配列）。応答時間 **約 0.2s 未満** |
| CORS（GET） | 上記に `-H "Origin: http://localhost:4200"` | **200**、`access-control-allow-origin: http://localhost:4200`、`access-control-allow-credentials: true` |
| CORS（OPTIONS） | `OPTIONS` 同一パス、`Access-Control-Request-Method: GET` 等 | **200**、上記と整合する CORS ヘッダ |
| フロントビルド | `frontend` で `npx ng build --configuration=development` | **成功**（exit 0）、`entry-schedule-list-component` の lazy chunk が生成される |

**まだここでは言えないこと**: 上記は **curl / CLI** の結果である。**ブラウザで症状が出た瞬間**の Network の 1 行と突き合わせていない限り、「ブラウザでも同じ」とは断定しない。

