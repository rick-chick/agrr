# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      # 既存 Pest を crop に紐付ける（永続化オーケストレーション）。認可は呼び出し側。
      class PestLinkToCropInteractor
        def initialize(pest_gateway:, crop_pest_gateway:, crop_gateway:)
          @pest_gateway = pest_gateway
          @crop_pest_gateway = crop_pest_gateway
          @crop_gateway = crop_gateway
        end

        # @return [Symbol] :linked, :already_linked, :missing_crop, :missing_pest
        def call(crop_id:, pest_id:)
          crop = @crop_gateway.find_by_id(crop_id)
          return :missing_crop unless crop

          pest_entity =
            begin
              @pest_gateway.find_by_id(pest_id)
            rescue Domain::Shared::Exceptions::RecordNotFound
              return :missing_pest
            end

          if @crop_pest_gateway.find_by_crop_id_and_pest_id(crop_id: crop_id, pest_id: pest_entity.id)
            return :already_linked
          end

          @crop_pest_gateway.create(crop_id: crop_id, pest_id: pest_entity.id)
          :linked
        end
      end
    end
  end
end
