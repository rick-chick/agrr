# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      class CultivationPlanGateway
        def find_existing(farm, user)
          raise NotImplementedError, "Subclasses must implement find_existing"
        end

        def private_owned_plan_display_name(user:, plan_id:)
          raise NotImplementedError, "Subclasses must implement private_owned_plan_display_name"
        end

        def delete(plan_id, user, toast_message:)
          raise NotImplementedError, "Subclasses must implement destroy"
        end

        # @return [Domain::CultivationPlan::Entities::CultivationPlanEntity]
        def find_by_id(plan_id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        # @return [Domain::CultivationPlan::Entities::CultivationPlanEntity]
        def update(plan_id, attrs)
          raise NotImplementedError, "Subclasses must implement update"
        end

        # @return [Array<Domain::CultivationPlan::Entities::FieldCultivationEntity>]
        def list_by_plan_id(plan_id)
          raise NotImplementedError, "Subclasses must implement list_by_plan_id"
        end

        # @return [Domain::CultivationPlan::Dtos::TaskScheduleGenerationContext]
        def find_with_field_cultivations_for_task_schedule(plan_id)
          raise NotImplementedError, "Subclasses must implement find_with_field_cultivations_for_task_schedule"
        end

        # @param attrs [Domain::CultivationPlan::Dtos::CultivationPlanCreateAttrs]
        # @return [Domain::CultivationPlan::Entities::CultivationPlanEntity]
        def create(attrs:)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def within_transaction(&block)
          raise NotImplementedError, "Subclasses must implement within_transaction"
        end

        def update_predicted_weather_data(cultivation_plan_id, payload)
          raise NotImplementedError, "Subclasses must implement update_predicted_weather_data"
        end

        # --- CultivationPlanOptimizeInteractor 用（永続化は Gateway 経由） ---

        # @return [Boolean]
        def field_cultivations_present?(plan_id)
          raise NotImplementedError, "Subclasses must implement field_cultivations_present?"
        end

        # @return [Array<Domain::CultivationPlan::Dtos::CultivationPlanCropWithAgrr>]
        def cultivation_plan_crops_with_crop(plan_id)
          raise NotImplementedError, "Subclasses must implement cultivation_plan_crops_with_crop"
        end

        def clear_field_cultivations(plan_id)
          raise NotImplementedError, "Subclasses must implement clear_field_cultivations"
        end

        # @param attrs [Hash] FieldCultivation#create! に渡す属性（シンボルキー可）
        # @return [Domain::CultivationPlan::Entities::FieldCultivationEntity]
        def create_field_cultivation(plan_id:, attrs:)
          raise NotImplementedError, "Subclasses must implement create_field_cultivation"
        end

        # find_or_create_by!(name:) 相当。圃場レコード id を返す
        def upsert_cultivation_plan_field(plan_id:, name:, area:, daily_fixed_cost:)
          raise NotImplementedError, "Subclasses must implement upsert_cultivation_plan_field"
        end

        # @raise [Domain::CultivationPlan::Errors::CultivationPlanCropMissingError] 紐付けが無い場合（データ不整合）
        def find_crop_id!(plan_id, crop_id)
          raise NotImplementedError, "Subclasses must implement find_crop_id!"
        end

        # @param attrs [Hash] CultivationPlan#update! に渡す属性
        def apply_optimization_result(plan_id:, attrs:)
          raise NotImplementedError, "Subclasses must implement apply_optimization_result"
        end

      end
    end
  end
end
