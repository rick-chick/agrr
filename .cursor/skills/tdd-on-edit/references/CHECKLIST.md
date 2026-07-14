# 改修 TDD — チェックリスト

## RED の前

- [ ] 触れる層と `ARCHITECTURE.md` の該当条項を確認した
- [ ] 期待する振る舞いを説明できる（根拠ゲート）
- [ ] [CODE_MODIFICATION_SKILLS.md](../../references/CODE_MODIFICATION_SKILLS.md) でテストスキルを選んだ

## RED

- [ ] テストを追加・更新した（対象層のテストスキルに従った）
- [ ] `test-common` で実行し、**意図どおり RED** であることを確認した

## GREEN

- [ ] 実装スキルに従い最小限の本実装を行った
- [ ] `test-common` で当該テストが **GREEN** であることを確認した

## 完了

- [ ] 個別 GREEN のあと、必要なら引数なし `test-common`（全体）
- [ ] `test-slow-detection` を実施した
- [ ] サブエージェント委譲時はプロンプトに RED→GREEN の順序を含めた

## 参照

- 本 SKILL: [../SKILL.md](../SKILL.md)
- ルール: [tdd-on-edit.mdc](../../../rules/tdd-on-edit.mdc)
- バグ: [error-investigation](../../error-investigation/SKILL.md) / [error-fix-red-green](../../error-fix-red-green/SKILL.md)
