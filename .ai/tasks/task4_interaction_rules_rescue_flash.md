---
id: 4
title: 'InteractionRulesController の create/update の rescue でエラーメッセージを表示'
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

InteractionRulesController の create/update で rescue StandardError 時に flash.now[:alert] = e.message を設定し、ユーザーにエラー内容が表示されるようにする。

## Details

- **create**: 既存の `rescue StandardError => e` ブロック内で、`render :new, status: :unprocessable_entity` の前に `flash.now[:alert] = e.message` を追加する。
- **update**: 既存の `rescue StandardError => e` ブロック内で、`render :edit, status: :unprocessable_entity` の前に `flash.now[:alert] = e.message` を追加する。
- 必要に応じて @interaction_rule に assign_attributes してバリデーションエラーを @interaction_rule.errors に反映させる（既存の @interaction_rule = InteractionRule.new(interaction_rule_params) は create で既にあり、rescue 時も同パラメータで再構築するとよい）。

## Test Strategy

- `bundle exec rails test test/controllers/interaction_rules_controller_test.rb` が通ること。
- 失敗時にフォーム再表示かつ flash にエラーメッセージが入ること。

## Agent Notes

