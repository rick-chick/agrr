---
id: 2
title: 'AgriculturalTasksController の index を ListInteractor に寄せるか検討・実装'
status: completed
priority: low
feature: Rails HTML Clean Architecture
dependencies: []
assigned_agent: null
created_at: "2026-01-30T11:29:20Z"
started_at: null
completed_at: "2026-01-30T11:35:00Z"
error_log: null
---

## Description

AgriculturalTasksController の index は現状 ActiveRecord と Policy の scope を直接使用している。現状のフィルタ・スコープ（admin 用フィルタ、検索、@reference_farms 等）を維持しつつ、AgriculturalTaskListInteractor + AgriculturalTaskListHtmlPresenter に寄せるか検討し、妥当であれば実装する。

## Details

- index では `@query`, `@selected_filter`, `agricultural_tasks_for_admin`, `apply_search`, `@agricultural_tasks`, `@reference_farms` 等の既存ロジックがある。
- ListInteractor の入力 DTO に filter/query を渡せるか、または index のみ従来どおり scope を組み立てて Presenter に渡す形にするか検討する。
- 契約 `docs/contracts/rails-html-clean-architecture-contract.md` および既存の AgriculturalTaskListInteractor / AgriculturalTaskListHtmlPresenter のインターフェースを確認してから方針を決める。

## Test Strategy

- `bundle exec rails test test/controllers/agricultural_tasks_controller_test.rb` で index 関連のテストが通ること。
- 一覧表示・フィルタ・検索の挙動が既存と変わらないこと。

## Agent Notes

