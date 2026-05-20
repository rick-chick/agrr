# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      # 害虫作成ユースケース: エッジで正規化済みの永続属性を Interactor に渡す。
      class PestCreateCommand
        attr_reader :persist_attrs, :crop_ids

        # @param persist_attrs [Domain::Pest::Dtos::PestPersistAttrs]
        # @param crop_ids [Array]
        def initialize(persist_attrs:, crop_ids: nil)
          @persist_attrs = persist_attrs
          @crop_ids = crop_ids || []
          freeze
        end
      end
    end
  end
end
