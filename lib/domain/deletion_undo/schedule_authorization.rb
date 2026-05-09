# frozen_string_literal: true

module Domain
  module DeletionUndo
    # アダプターに分散していた Undo スケジュール可否判定（マスタ Policy + 計画・圃場の例外）。
    module ScheduleAuthorization
      module_function

      def schedule_allowed?(user, record)
        case record.class.name
        when "Farm"
          Domain::Shared::Policies::FarmPolicy.edit_allowed?(user, is_reference: record.is_reference, user_id: record.user_id)
        when "Crop"
          Domain::Shared::Policies::CropPolicy.edit_allowed?(user, is_reference: record.is_reference, user_id: record.user_id)
        when "Pest"
          Domain::Shared::Policies::PestPolicy.edit_allowed?(user, is_reference: record.is_reference, user_id: record.user_id)
        when "Pesticide"
          Domain::Shared::Policies::PesticidePolicy.edit_allowed?(user, is_reference: record.is_reference, user_id: record.user_id)
        when "Fertilize"
          Domain::Shared::Policies::FertilizePolicy.edit_allowed?(user, is_reference: record.is_reference, user_id: record.user_id)
        when "AgriculturalTask"
          Domain::Shared::Policies::AgriculturalTaskPolicy.edit_allowed?(user, is_reference: record.is_reference, user_id: record.user_id)
        when "InteractionRule"
          Domain::Shared::Policies::InteractionRulePolicy.edit_allowed?(user, is_reference: record.is_reference, user_id: record.user_id)
        when "Field"
          user.admin? || record.farm.user_id == user.id
        when "TaskScheduleItem"
          plan = record.cultivation_plan
          user.admin? || (plan.plan_type_private? && plan.user_id == user.id)
        when "CultivationPlan"
          user.admin? || (record.plan_type_private? && record.user_id == user.id)
        else
          false
        end
      end
    end
  end
end
