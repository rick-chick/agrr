---
id: 1
title: 'FertilizesController の index/show を Interactor + HTML Presenter に移行'
status: completed
priority: medium
feature: Rails HTML Clean Architecture
dependencies: []
assigned_agent: null
created_at: "2026-01-30T11:29:20Z"
started_at: null
completed_at: "2026-01-30T11:35:00Z"
error_log: null
---

## Description

FertilizesController の index を FertilizeListInteractor + FertilizeListHtmlPresenter、show を FertilizeDetailInteractor + FertilizeDetailHtmlPresenter に寄せ、既存の Policy 直接呼び出しをやめる。

## Details

- **index**: `Domain::Shared::Policies::FertilizePolicy.visible_scope(current_user).recent` をやめ、`FertilizeListInteractor` + `FertilizeListHtmlPresenter` を使用する。DTO は is_admin を渡す形で既存の ListInteractor に合わせる。
- **show**: 現状は空の show で `@fertilize` は set_fertilize でセット済み。`FertilizeDetailInteractor` + `FertilizeDetailHtmlPresenter` を呼び、Presenter が @fertilize をセットする形にする。失敗時は redirect で既存と同等にする。
- 既存の FertilizeListHtmlPresenter / FertilizeDetailHtmlPresenter は `lib/presenters/html/fertilize/` に存在するため、コントローラ側の呼び出しを追加・変更するのみでよい。

## Test Strategy

- `bundle exec rails test test/controllers/fertilizes_controller_test.rb` で index/show 関連のテストが通ること。
- 既存の HTML Presenter テストが通ること。

## Agent Notes

