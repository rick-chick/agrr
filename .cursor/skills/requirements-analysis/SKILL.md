---
name: requirements-analysis
description: Performs project investigation, requirements understanding, and requirements refinement. Use when analyzing user requirements, clarifying new features, or when the user asks for 要件分析, 要求理解, 仕様作成, or when starting feature development.
disable-model-invocation: true
---

# 要件分析スキル

要件からプロジェクト調査、要求理解、要求ブラッシュアップまでを一貫して行うスキル。

## When to Use

- 新機能の実装依頼を受けたとき
- 要件が不明確で明確化が必要なとき
- プロジェクトの文脈を考慮した仕様作成が必要なとき
- Trigger: 要件分析, 要求理解, 仕様作成, 機能定義, 要求ブラッシュアップ

## Instructions

### ステップ1: プロジェクト調査

プロジェクトの構造と技術スタックを調査：
- プロジェクトのディレクトリ構造を確認
- 主要なコンポーネントと既存機能を把握
- 使用されている技術スタックを理解
- データベーススキーマやAPI構造を確認

### ステップ2: 要求理解

ユーザーの要求を詳細に分析：
- 要求の主要な目的を明確化
- 必要な機能要件をリストアップ
- 非機能要件（パフォーマンス、セキュリティなど）を特定
- 依存関係や制約条件を把握

### ステップ3: 要求ブラッシュアップ

プロジェクトの文脈に沿って要求を洗練：
- 既存機能との整合性を確認
- 技術的な実現可能性を評価
- 優先順位付けとスコープ定義
- 詳細な仕様の骨子を作成

各ステップ完了時にステータスを報告し、次のステップを案内する。

## References

- [references/CONTRACT_TEMPLATE.md](references/CONTRACT_TEMPLATE.md) - 仕様書作成のテンプレート
- [references/REQUIREMENTS_EXAMPLES.md](references/REQUIREMENTS_EXAMPLES.md) - 要件分析の事例