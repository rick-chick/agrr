# lib/domain → Rust 移行トラッキング

> **自動生成** — 手編集しない。更新: `./scripts/sync-lib-domain-rust-tracking.sh`
> program_version: 1 — 生成: 2026-05-28T23:15:50Z

## サマリー

| 指標 | 値 |
|------|----|
| lib/domain Ruby ファイル | 824 |
| test/domain ファイル | 234 |
| crates/agrr-domain Rust ファイル | 885 |

## コンテキスト別

| Context | Wave | Phase | Ruby files | domain tests | Rust module |
|---------|------|-------|------------|--------------|-------------|
| agricultural_task | wave-3-medium | test | 30 | 9 | crates/agrr-domain/src/agricultural_task |
| api_keys | wave-2-small | test | 4 | 0 | crates/agrr-domain/src/api_keys |
| auth | wave-2-small | test | 8 | 2 | crates/agrr-domain/src/auth |
| backdoor | wave-2-small | test | 5 | 1 | crates/agrr-domain/src/backdoor |
| contact_messages | wave-2-small | test | 7 | 2 | crates/agrr-domain/src/contact_messages |
| crop | wave-4-large | test | 140 | 36 | crates/agrr-domain/src/crop |
| cultivation_plan | wave-5-cultivation-plan | test | 234 | 65 | crates/agrr-domain/src/cultivation_plan |
| deletion_undo | wave-3-medium | test | 19 | 5 | crates/agrr-domain/src/deletion_undo |
| farm | wave-3-medium | test | 39 | 15 | crates/agrr-domain/src/farm |
| fertilize | wave-3-medium | test | 29 | 7 | crates/agrr-domain/src/fertilize |
| field | wave-3-medium | test | 26 | 6 | crates/agrr-domain/src/field |
| field_cultivation | wave-4-large | test | 51 | 16 | crates/agrr-domain/src/field_cultivation |
| file_blob | wave-2-small | test | 8 | 1 | crates/agrr-domain/src/file_blob |
| interaction_rule | wave-3-medium | test | 21 | 6 | crates/agrr-domain/src/interaction_rule |
| internal_jobs | wave-2-small | test | 4 | 1 | crates/agrr-domain/src/internal_jobs |
| pest | wave-3-medium | test | 48 | 17 | crates/agrr-domain/src/pest |
| pesticide | wave-3-medium | test | 24 | 7 | crates/agrr-domain/src/pesticide |
| public_plan | wave-3-medium | test | 24 | 3 | crates/agrr-domain/src/public_plan |
| shared | wave-1-shared | done | 52 | 20 | crates/agrr-domain/src/shared |
| weather_data | wave-4-large | test | 50 | 13 | crates/agrr-domain/src/weather_data |

## 進捗率（コンテキスト単位）

- done: **0/20** (0%)
- in_progress (design〜ffi_bridge): **20/20** (100%)
- not_started: **0/20**

## ウェーブ

- wave-0-foundation
- wave-1-shared
- wave-2-small
- wave-3-medium
- wave-4-large
- wave-5-cultivation-plan

詳細定義: [TRACKING.yaml](./TRACKING.yaml)、手順: [PROGRAM.md](./PROGRAM.md)
