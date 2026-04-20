# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      class PestMapper
        def initialize(ctx)
          @ctx = ctx
        end

        def copy_pests_for_region(region)
          crop_mapper = CropMapper.new(@ctx)
          reference_crop_ids = crop_mapper.get_reference_crop_ids
          return [] if reference_crop_ids.empty?

          reference_scope = ::Pest.reference
          reference_scope = reference_scope.where(region: [ region, nil ]) if region.present?

          reference_scope = reference_scope.includes(
            :pest_temperature_profile,
            :pest_thermal_requirement,
            :pest_control_methods,
            crop_pests: :crop
          )

          user_pests = []

          @ctx.reference_pest_id_to_user_pest_id ||= {}

          reference_scope.find_each do |reference_pest|
            pest_crop_ids = reference_pest.crop_pests.pluck(:crop_id)
            next unless (pest_crop_ids & reference_crop_ids).any?

            existing_pest = @ctx.user.pests.reload.find_by(source_pest_id: reference_pest.id)

            if existing_pest
              copy_pest_crop_relationships(reference_pest, existing_pest, crop_mapper)
              @ctx.result.add_skip(:pests, existing_pest.id)
              user_pests << existing_pest
              @ctx.reference_pest_id_to_user_pest_id[reference_pest.id] = existing_pest.id
              next
            end

            new_pest = @ctx.user.pests.build(
              name: reference_pest.name,
              name_scientific: reference_pest.name_scientific,
              family: reference_pest.family,
              order: reference_pest.order,
              description: reference_pest.description,
              occurrence_season: reference_pest.occurrence_season,
              region: reference_pest.region || region,
              is_reference: false,
              source_pest_id: reference_pest.id
            )

            unless new_pest.save
              error_messages = new_pest.errors.full_messages
              error_keys = new_pest.errors.keys

              is_uniqueness_error = error_keys.include?(:source_pest_id) ||
                                    error_messages.any? { |msg| (msg.include?("Pest") || msg.include?("pest")) && (msg.include?("すでに存在") || msg.include?("already") || msg.include?("taken")) }

              if is_uniqueness_error
                existing_pest = @ctx.user.pests.reload.find_by(source_pest_id: reference_pest.id)
                if existing_pest
                  copy_pest_crop_relationships(reference_pest, existing_pest, crop_mapper)
                  @ctx.result.add_skip(:pests, existing_pest.id)
                  user_pests << existing_pest
                  @ctx.reference_pest_id_to_user_pest_id[reference_pest.id] = existing_pest.id
                  next
                else
                  error_message = "Pest uniqueness constraint violation but existing pest not found: source_pest_id=#{reference_pest.id}, user_id=#{@ctx.user.id}, error_messages=#{error_messages.join(', ')}"
                  Rails.logger.error "❌ [PlanSaveService] #{error_message}"
                  raise StandardError, error_message
                end
              end

              error_message = error_messages.join(", ")
              Rails.logger.error "❌ [PlanSaveService] Pest creation failed: #{error_message} (keys: #{error_keys.inspect})"
              raise StandardError, error_message
            end

            copy_pest_profiles(reference_pest, new_pest)
            copy_pest_control_methods(reference_pest, new_pest)
            copy_pest_crop_relationships(reference_pest, new_pest, crop_mapper)

            user_pests << new_pest
            @ctx.reference_pest_id_to_user_pest_id[reference_pest.id] = new_pest.id
            Rails.logger.info I18n.t("services.plan_save_service.messages.pest_created", pest_name: new_pest.name)
          end

          user_pests
        end

        def user_pest_id_for_reference_pest(reference_pest_id)
          @ctx.reference_pest_id_to_user_pest_id ||= {}
          return @ctx.reference_pest_id_to_user_pest_id[reference_pest_id] if @ctx.reference_pest_id_to_user_pest_id.key?(reference_pest_id)

          user_pest = @ctx.user.pests.find_by(source_pest_id: reference_pest_id)
          if user_pest
            @ctx.reference_pest_id_to_user_pest_id[reference_pest_id] = user_pest.id
            return user_pest.id
          end

          nil
        end

        private

        def copy_pest_profiles(reference_pest, new_pest)
          if (reference_profile = reference_pest.pest_temperature_profile)
            new_pest.create_pest_temperature_profile!(
              base_temperature: reference_profile.base_temperature,
              max_temperature: reference_profile.max_temperature
            )
          end

          if (reference_thermal = reference_pest.pest_thermal_requirement)
            new_pest.create_pest_thermal_requirement!(
              required_gdd: reference_thermal.required_gdd,
              first_generation_gdd: reference_thermal.first_generation_gdd
            )
          end
        end

        def copy_pest_control_methods(reference_pest, new_pest)
          reference_pest.pest_control_methods.order(:id).each do |method|
            new_pest.pest_control_methods.create!(
              method_type: method.method_type,
              method_name: method.method_name,
              description: method.description,
              timing_hint: method.timing_hint
            )
          end
        end

        def copy_pest_crop_relationships(reference_pest, new_pest, crop_mapper)
          reference_pest.crop_pests.each do |crop_pest|
            user_crop_id = crop_mapper.user_crop_id_for_reference_crop(crop_pest.crop_id)
            next unless user_crop_id

            ::CropPest.find_or_create_by!(crop_id: user_crop_id, pest: new_pest)
          end
        end
      end
    end
  end
end
