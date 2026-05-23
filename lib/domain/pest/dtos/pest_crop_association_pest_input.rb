# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      # 害虫マスタフォームの作物スコープ／正規化に必要な値のみ（ActiveRecord を渡さない）。
      class PestCropAssociationPestInput
        attr_reader :is_reference, :pest_user_id, :region, :associated_crop_ids

        def initialize(is_reference:, pest_user_id:, region:, associated_crop_ids:)
          @is_reference = is_reference
          @pest_user_id = pest_user_id
          @region = region
          @associated_crop_ids = associated_crop_ids
        end

        # @param payload [Domain::Pest::Dtos::PestMasterEditPayload]
        def self.from_master_edit_payload(payload)
          new(
            is_reference: payload.is_reference?,
            pest_user_id: payload.user_id,
            region: payload.region,
            associated_crop_ids: payload.associated_crop_ids
          )
        end

        # {PestCropAssociationAccess#filter_for_accessible_crops} が `user_id` / `is_reference?` を参照するための別名。
        def user_id
          pest_user_id
        end

        def is_reference?
          Domain::Shared::TypeConverters::BooleanConverter.cast(is_reference)
        end
      end
    end
  end
end
