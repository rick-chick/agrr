# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      # 公開プラン保存セッション用 Pesticide マッパー（AR を扱うため Adapter 層）。
      class PesticideMapper
        def initialize(ctx)
          @ctx = ctx
        end

        def copy_pesticides_for_region(region)
          pest_mapper = PestMapper.new(@ctx)

          reference_scope = ::Pesticide.reference.includes(
            :pesticide_usage_constraint,
            :pesticide_application_detail,
            :crop,
            :pest
          )
          reference_scope = reference_scope.where(region: [ region, nil ]) if region.present?

          user_pesticides = []

          reference_scope.find_each do |reference_pesticide|
            existing_pesticide = @ctx.user.pesticides.find_by(source_pesticide_id: reference_pesticide.id)

            if existing_pesticide
              @ctx.result.add_skip(:pesticides, existing_pesticide.id)
              user_pesticides << existing_pesticide
              next
            end

            user_crop_id = @ctx.user_crop_id_for_reference_crop(reference_pesticide.crop_id)
            user_pest_id = pest_mapper.user_pest_id_for_reference_pest(reference_pesticide.pest_id)

            unless user_crop_id && user_pest_id
              Rails.logger.warn "⚠️ [PlanSaveService] Skipping pesticide copy due to missing crop/pest mapping (pesticide_id=#{reference_pesticide.id})"
              next
            end

            new_pesticide = @ctx.user.pesticides.build(
              crop_id: user_crop_id,
              pest_id: user_pest_id,
              name: reference_pesticide.name,
              active_ingredient: reference_pesticide.active_ingredient,
              description: reference_pesticide.description,
              region: reference_pesticide.region || region,
              is_reference: false,
              source_pesticide_id: reference_pesticide.id
            )

            unless new_pesticide.save
              error_message = new_pesticide.errors.full_messages.join(", ")
              Rails.logger.error "❌ [PlanSaveService] Pesticide creation failed: #{error_message}"
              raise Domain::Shared::Exceptions::RecordInvalid, error_message
            end

            copy_pesticide_usage_constraint(reference_pesticide, new_pesticide)
            copy_pesticide_application_detail(reference_pesticide, new_pesticide)

            user_pesticides << new_pesticide
            Rails.logger.info I18n.t("services.plan_save_service.messages.pesticide_created", pesticide_name: new_pesticide.name)
          end

          user_pesticides
        end

        private

        def copy_pesticide_usage_constraint(reference_pesticide, new_pesticide)
          reference_constraint = reference_pesticide.pesticide_usage_constraint
          return unless reference_constraint

          new_pesticide.create_pesticide_usage_constraint!(
            min_temperature: reference_constraint.min_temperature,
            max_temperature: reference_constraint.max_temperature,
            max_wind_speed_m_s: reference_constraint.max_wind_speed_m_s,
            max_application_count: reference_constraint.max_application_count,
            harvest_interval_days: reference_constraint.harvest_interval_days,
            other_constraints: reference_constraint.other_constraints
          )
        end

        def copy_pesticide_application_detail(reference_pesticide, new_pesticide)
          reference_detail = reference_pesticide.pesticide_application_detail
          return unless reference_detail

          new_pesticide.create_pesticide_application_detail!(
            dilution_ratio: reference_detail.dilution_ratio,
            amount_per_m2: reference_detail.amount_per_m2,
            amount_unit: reference_detail.amount_unit,
            application_method: reference_detail.application_method
          )
        end
      end
    end
  end
end
