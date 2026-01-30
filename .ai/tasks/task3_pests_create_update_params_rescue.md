---
id: 3
title: 'PestsController の create/update を pest_params と rescue で統一'
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

PestsController の create/update で DTO を raw params ではなく pest_params（strong params）から組み立て、失敗時に rescue StandardError で render :new / :edit と flash.now[:alert] を設定する。

## Details

- **create**: `Domain::Pest::Dtos::PestCreateInputDto.from_hash(params.to_unsafe_h.deep_symbolize_keys)` を、`from_hash({ pest: pest_params.to_h.symbolize_keys })` のように pest_params ベースに変更。DTO の from_hash が :pest キーを期待するか確認し、必要なら key を合わせる。
- **update**: 同様に `PestUpdateInputDto.from_hash({ pest: pest_params.to_h.symbolize_keys }, params[:id])` に変更。
- **rescue**: create/update の末尾に `rescue StandardError => e` を追加。create では `@pest = Pest.new(pest_params.to_h.symbolize_keys)` をセットし、update では `@pest.assign_attributes(pest_params.to_h.symbolize_keys)` をセット。いずれも `@pest.valid?`、`flash.now[:alert] = e.message`、`render :new` または `render :edit`、`status: :unprocessable_entity` を行う。
- 管理者専用項目（例: is_reference）がある場合は、farm と同様に pest_params 内で admin_user? のときだけ permit する。

## Test Strategy

- `bundle exec rails test test/controllers/pests_controller_test.rb` が通ること。
- バリデーションエラー時や Policy エラー時にフォームが再表示され、エラーメッセージが表示されること。

## Agent Notes

