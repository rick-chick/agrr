# Clean Architecture — AGRR バックエンド（補足）

全体像とレイヤの説明は **[ARCHITECTURE.md](./ARCHITECTURE.md)** を正とする。本書は **-gateway / 表現層の境界** と **実装方針** に特化した規範である。

## Gateway は View（HTML/Partials/JSON の形）を知らない

- **禁止**: Gateway（`lib/adapters/**/gateways` および `Domain::*::Gateways` の実装）が、**特定テンプレート・Partial・`data-*`・ルートヘルパー前提の Hash 形** など **HTTP / UI 表現** に依存すること。
- **禁止の目安**: メソッド名や返却型が **`*_page`** / **`*_html`** のように **画面 ID そのもの** に寄りすぎ、かつ **JS が期待するキー名** を Gateway 内で組み立てている状態。
- **許容**: 認可・永続化・**ドメイン上意味のある読み取りスナップショット**（例: 圃場・栽培行の ID・日付・数値など）を **DTO / 値オブジェクト** として返すこと。
- **ページ用ペイロード**（ガント用 `Array<Hash>` など）は **Interactor 側の組み立て**、または **ドメイン内 Assembler / Mapper**（`lib/domain/**`、表現はまだ HTTP ではないが **読み取り結果 → ユースケースが約束する DTO** の変換）に置く。  
  既存の **Output Port が要求する `PrivatePlanShowPageDto` のような形** は、**Gateway の外** で組み立てる。

## 「とりあえず簡単」は却下

- **簡単に実装できるから** と理由を付けて **本来の層に置くべき処理を省略**し、後から **全面やり直し** が必要になるような変更は **採用しない**。
- 行う場合は、**同じ PR / 連続コミット** で負債を返済するか、**契約（`docs/contracts/`）とテスト** で「暫定」の寿命と置換条件を明記する。

詳細ルールは **`.cursor/rules/no-convenience-tech-debt.mdc`** も参照すること。
