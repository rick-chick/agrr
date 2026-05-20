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

        # 害虫フォーム側モデル（is_reference? / user_id / region / persisted? / crop_ids を備える想定）。ActiveRecord 型に依存しない。
        def self.from_pest_form_handle(handle)
          persisted = handle.respond_to?(:persisted?) && handle.persisted?
          crop_ids =
            if persisted && handle.respond_to?(:crop_ids)
              Array(handle.crop_ids).map(&:to_i)
            else
              []
            end
          new(
            is_reference: handle.respond_to?(:is_reference?) && !!handle.is_reference?,
            pest_user_id: handle.respond_to?(:user_id) ? handle.user_id : nil,
            region: handle.respond_to?(:region) ? handle.region : nil,
            associated_crop_ids: crop_ids
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
