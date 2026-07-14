---
name: test-slow-detection
description: テスト完了後に必ず実施する処理。
disable-model-invocation: false
---

# Test Slow Detection

## When to Use

- テスト実行後、またはテスト結果の確認を求められたとき

## Instructions

- プロジェクトの標準テストスクリプトで全体テストを実行する
- 出力がGREENか、"=== Slow tests detected (threshold: 0.5s) ===" 未検出を確認する
- slow検出時は詳細参照ファイルを参照し対応する

## References

- [references/DETAILS.md](references/DETAILS.md) - 遅いテスト検出時の詳細手順

