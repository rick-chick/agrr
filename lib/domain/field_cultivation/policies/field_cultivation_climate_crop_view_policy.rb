# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Policies
      # 気象 UC: 計画に紐づく作物の閲覧可否（I/O なし）。公開計画は参照作物のみ。
      module FieldCultivationClimateCropViewPolicy
        module_function

        def view_allowed?(user:, crop_entity:, plan_type_public:)
          if plan_type_public
            crop_entity.is_reference == true
          else
            Domain::Shared::Policies::CropPolicy.view_allowed?(
              user,
              is_reference: crop_entity.is_reference,
              user_id: crop_entity.user_id
            )
          end
        end
      end
    end
  end
end
