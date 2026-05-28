# frozen_string_literal: true

module Domain
  module Crop
    module Policies
      # AI 害虫の crop_name フォールバック: 参照作物を優先し、なければユーザーが edit 可能な自所有作物。
      module CropResolveByNamePolicy
        module_function

        # @param user [#id, #admin?]
        # @param candidates [Array] CropEntity 等（is_reference / user_id を持つ）
        # @return [Integer, nil]
        def select_id_for_pest_ai_name_fallback(user:, candidates:)
          return nil if candidates.blank?

          reference = candidates.find do |crop|
            Domain::Shared::ReferenceRecordAuthorization.referencable_is_reference(crop)
          end
          return reference.id if reference

          owned = candidates.find do |crop|
            Domain::Shared::Policies::CropPolicy.edit_allowed?(
              user,
              is_reference: Domain::Shared::ReferenceRecordAuthorization.referencable_is_reference(crop),
              user_id: crop.user_id
            )
          end
          owned&.id
        end
      end
    end
  end
end
