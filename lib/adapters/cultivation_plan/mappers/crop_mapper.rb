# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      # 公開プラン保存セッション用 Crop マッパー（AR を扱うため Adapter 層）。
      # Domain::Crop::Gateways::CropStageCopyGateway は依存できる（gateway interface）。
      class CropMapper
        def initialize(ctx, stage_copy_gateway: nil)
          @ctx = ctx
          @stage_copy_gateway = stage_copy_gateway || Domain::Crop::Gateways::CropStageCopyGateway.default
        end

        def create_user_crops_from_plan
          plan_id = @ctx.session_data[:plan_id] || @ctx.session_data["plan_id"]
          raise StandardError, "plan_id is required to derive crops" unless plan_id

          reference_plan = ::CultivationPlan.includes(cultivation_plan_crops: [ crop: { crop_stages: [ :temperature_requirement, :sunshine_requirement, :thermal_requirement ] } ]).find(plan_id)

          user_crops = []
          @ctx.reference_crop_id_to_user_crop_id ||= {}

          reference_cultivation_plan_crops = reference_plan.cultivation_plan_crops.order(:id).to_a
          @ctx.ref_cpc_id_to_user_crop_id = {}

          reference_cultivation_plan_crops.each do |reference_cpc|
            reference_crop = reference_cpc.crop
            user_crop = @ctx.user.crops.find_by(source_crop_id: reference_crop.id)

            if user_crop
              @ctx.result.add_skip(:crops, user_crop.id)
              user_crops << user_crop
            else
              user_crop = @ctx.user.crops.create!(
                name: reference_crop.name,
                variety: reference_crop.variety,
                area_per_unit: reference_crop.area_per_unit,
                revenue_per_area: reference_crop.revenue_per_area,
                groups: reference_crop.groups,
                is_reference: false,
                region: reference_crop.region,
                source_crop_id: reference_crop.id
              )
              copy_crop_stages(reference_crop, user_crop)
              user_crops << user_crop
            end

            @ctx.reference_crop_id_to_user_crop_id[reference_crop.id] = user_crop.id
            @ctx.ref_cpc_id_to_user_crop_id[reference_cpc.id] = user_crop.id
          end

          Rails.logger.info I18n.t("services.plan_save_service.debug.user_crops_created", count: user_crops.count)
          user_crops
        end

        def user_crop_id_for_reference_crop(reference_crop_id)
          @ctx.reference_crop_id_to_user_crop_id ||= {}
          return @ctx.reference_crop_id_to_user_crop_id[reference_crop_id] if @ctx.reference_crop_id_to_user_crop_id.key?(reference_crop_id)

          user_crop = @ctx.user.crops.find_by(source_crop_id: reference_crop_id)
          if user_crop
            @ctx.reference_crop_id_to_user_crop_id[reference_crop_id] = user_crop.id
            return user_crop.id
          end

          nil
        end

        def get_reference_crop_ids
          @ctx.reference_crop_id_to_user_crop_id ||= {}
          @ctx.reference_crop_id_to_user_crop_id.keys
        end

        def get_reference_crop_groups
          reference_crop_ids = get_reference_crop_ids
          return [] if reference_crop_ids.empty?

          crops = ::Crop.where(id: reference_crop_ids)
          groups = crops.pluck(:name)
          crops.each do |crop|
            groups.concat(crop.groups) if crop.groups.present?
          end
          groups.compact.uniq
        end

        def copy_crop_stages(reference_crop, new_crop)
          @stage_copy_gateway.copy_reference_stages(
            reference_crop_id: reference_crop.id,
            new_crop_id: new_crop.id
          )
        rescue => e
          Rails.logger.error I18n.t("services.plan_save_service.errors.crop_stage_copy_failed", errors: e.message)
          raise e
        end
      end
    end
  end
end
