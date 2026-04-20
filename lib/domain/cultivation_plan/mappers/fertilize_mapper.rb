# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      class FertilizeMapper
        def initialize(ctx)
          @ctx = ctx
        end

        def copy_fertilizes_for_region(region)
          reference_scope = ::Fertilize.reference
          reference_scope = reference_scope.where(region: [ region, nil ]) if region.present?

          user_fertilizes = []

          reference_scope.find_each do |reference_fertilize|
            existing_fertilize = @ctx.user.fertilizes.find_by(source_fertilize_id: reference_fertilize.id)

            if existing_fertilize
              @ctx.result.add_skip(:fertilizes, existing_fertilize.id)
              user_fertilizes << existing_fertilize
              next
            end

            new_fertilize = @ctx.user.fertilizes.build(
              name: generate_unique_fertilize_name(reference_fertilize.name),
              n: reference_fertilize.n,
              p: reference_fertilize.p,
              k: reference_fertilize.k,
              description: reference_fertilize.description,
              package_size: reference_fertilize.package_size,
              region: reference_fertilize.region || region,
              is_reference: false,
              source_fertilize_id: reference_fertilize.id
            )

            unless new_fertilize.save
              error_message = new_fertilize.errors.full_messages.join(", ")
              Rails.logger.error "❌ [PlanSaveService] Fertilize creation failed: #{error_message}"
              raise StandardError, error_message
            end

            user_fertilizes << new_fertilize
            Rails.logger.info I18n.t("services.plan_save_service.messages.fertilize_created", fertilize_name: new_fertilize.name)
          end

          user_fertilizes
        end

        private

        def generate_unique_fertilize_name(base_name)
          candidate = "#{base_name} (コピー)"
          return candidate unless ::Fertilize.exists?(name: candidate)

          suffix = 2
          loop do
            candidate = "#{base_name} (コピー #{suffix})"
            break candidate unless ::Fertilize.exists?(name: candidate)
            suffix += 1
          end
        end
      end
    end
  end
end
