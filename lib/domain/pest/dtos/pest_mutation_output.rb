# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      # 作物ネスト経路の害虫作成・更新・検索の結果（ゲートウェイ戻り）。
      # Interactor は `status` / `pest_entity` / `unassociated_pest_entities` のみ解釈する。
      # `crop_nest_snapshot` は作物ネスト UI 向けの読み取りスナップショット（Presenter のみ参照）。
      class PestMutationOutput
        attr_reader :status, :pest_entity, :unassociated_pest_entities, :crop_nest_snapshot

        # @param status [Symbol] :created / :updated / :invalid / :found / :not_found / :crop_missing / :pest_missing
        # @param pest_entity [Domain::Pest::Entities::PestEntity, nil]
        # @param unassociated_pest_entities [Array<Domain::Pest::Entities::PestEntity>]
        # @param crop_nest_snapshot [Domain::Pest::Dtos::PestCropNestSnapshot, nil] Presenter のみ参照
        def initialize(status:, pest_entity: nil, unassociated_pest_entities: nil, crop_nest_snapshot: nil)
          @status = status
          @pest_entity = pest_entity
          @unassociated_pest_entities = (unassociated_pest_entities || []).freeze
          @crop_nest_snapshot = crop_nest_snapshot
          freeze
        end
      end
    end
  end
end
