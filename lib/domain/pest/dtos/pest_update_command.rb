# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      # 害虫更新ユースケース: エッジで正規化済みの永続属性を Interactor に渡す。
      class PestUpdateCommand
        attr_reader :pest_id, :persist_attrs, :crop_ids

        # @param pest_id [Integer]
        # @param persist_attrs [Domain::Pest::Dtos::PestPersistAttrs]
        # @param crop_ids [Array, nil] nil のとき作物関連付けは変更しない
        def initialize(pest_id:, persist_attrs:, crop_ids: nil)
          @pest_id = pest_id
          @persist_attrs = persist_attrs
          @crop_ids = crop_ids
          freeze
        end
      end
    end
  end
end
