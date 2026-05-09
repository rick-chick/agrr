# frozen_string_literal: true

module Domain
  module Shared
    # アダプターから Domain::Shared::Policies::* を直接参照しないための薄い委譲。
    # 判断の単一ソースは各 Policy クラスに残す。
    module ReferenceMasterAuthorization
      class << self
        def farm_view_allowed?(user, is_reference:, user_id:)
          Policies::FarmPolicy.view_allowed?(user, is_reference: is_reference, user_id: user_id)
        end

        def farm_edit_allowed?(user, is_reference:, user_id:)
          Policies::FarmPolicy.edit_allowed?(user, is_reference: is_reference, user_id: user_id)
        end

        def crop_view_allowed?(user, is_reference:, user_id:)
          Policies::CropPolicy.view_allowed?(user, is_reference: is_reference, user_id: user_id)
        end

        def crop_edit_allowed?(user, is_reference:, user_id:)
          Policies::CropPolicy.edit_allowed?(user, is_reference: is_reference, user_id: user_id)
        end

        def pest_view_allowed?(user, is_reference:, user_id:)
          Policies::PestPolicy.view_allowed?(user, is_reference: is_reference, user_id: user_id)
        end

        def pest_edit_allowed?(user, is_reference:, user_id:)
          Policies::PestPolicy.edit_allowed?(user, is_reference: is_reference, user_id: user_id)
        end

        def pesticide_view_allowed?(user, is_reference:, user_id:)
          Policies::PesticidePolicy.view_allowed?(user, is_reference: is_reference, user_id: user_id)
        end

        def pesticide_edit_allowed?(user, is_reference:, user_id:)
          Policies::PesticidePolicy.edit_allowed?(user, is_reference: is_reference, user_id: user_id)
        end

        def fertilize_view_allowed?(user, is_reference:, user_id:)
          Policies::FertilizePolicy.view_allowed?(user, is_reference: is_reference, user_id: user_id)
        end

        def fertilize_edit_allowed?(user, is_reference:, user_id:)
          Policies::FertilizePolicy.edit_allowed?(user, is_reference: is_reference, user_id: user_id)
        end

        def agricultural_task_view_allowed?(user, is_reference:, user_id:)
          Policies::AgriculturalTaskPolicy.view_allowed?(user, is_reference: is_reference, user_id: user_id)
        end

        def agricultural_task_edit_allowed?(user, is_reference:, user_id:)
          Policies::AgriculturalTaskPolicy.edit_allowed?(user, is_reference: is_reference, user_id: user_id)
        end

        def agricultural_task_masters_crop_task_template_associate_allowed?(user, is_reference:, user_id:)
          Policies::AgriculturalTaskPolicy.masters_crop_task_template_associate_allowed?(
            user,
            is_reference: is_reference,
            user_id: user_id
          )
        end

        def interaction_rule_view_allowed?(user, is_reference:, user_id:)
          Policies::InteractionRulePolicy.view_allowed?(user, is_reference: is_reference, user_id: user_id)
        end

        def interaction_rule_edit_allowed?(user, is_reference:, user_id:)
          Policies::InteractionRulePolicy.edit_allowed?(user, is_reference: is_reference, user_id: user_id)
        end
      end
    end
  end
end
