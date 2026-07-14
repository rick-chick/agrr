---
name: shared-screen-only-component
description: Extracts screen-only / event-only UI logic into shared components so it does not mix with interactor or API logic. Use when implementing UI that has both pure event handling (open/close, hover, timers) and use-case or Gateway calls, or when the user asks to separate screen-only behavior from feature logic.
disable-model-invocation: true
---

# 画面完結 UI の shared コンポーネント化

画面完結のUIロジックを再利用可能なsharedコンポーネントに分離するスキル。

## When to Use

- UI状態管理とAPI呼び出しが混在しているとき
- 再利用可能なUIコンポーネントを作成したいとき
- Trigger: 画面完結, sharedコンポーネント, UI分離

## Instructions

- 画面完結ロジックをsharedコンポーネントに抽出
- Input/Outputで親コンポーネントと連携
- Gateway/UseCaseを注入しない
- For patterns and examples, see [references/PATTERNS.md](references/PATTERNS.md)
- For usage examples, see [references/EXAMPLES.md](references/EXAMPLES.md)

## References

- [references/PATTERNS.md](references/PATTERNS.md) - Design patterns for shared components
- [references/EXAMPLES.md](references/EXAMPLES.md) - Implementation examples
