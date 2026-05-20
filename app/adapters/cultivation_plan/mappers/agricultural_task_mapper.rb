# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      # 公開プラン保存セッション用 AgriculturalTask マッパー（AR を扱うため Adapter 層）。
      class AgriculturalTaskMapper
        def initialize(ctx)
          @ctx = ctx
        end

        def copy_agricultural_tasks_for_region(region)
          crop_mapper = CropMapper.new(@ctx)
          reference_crop_ids = crop_mapper.get_reference_crop_ids
          return [] if reference_crop_ids.empty?

          reference_scope = ::AgriculturalTask.reference
          reference_scope = reference_scope.where(region: [ region, nil ]) if region.present?

          reference_scope = reference_scope.includes(crop_task_templates: :crop)

          user_tasks = []
          @ctx.reference_agricultural_task_id_to_user_task_id ||= {}

          reference_scope.find_each do |reference_task|
            task_crop_ids = reference_task.crop_task_templates.pluck(:crop_id)
            next unless (task_crop_ids & reference_crop_ids).any?

            existing_task = @ctx.user.agricultural_tasks.find_by(source_agricultural_task_id: reference_task.id)

            if existing_task
              copy_agricultural_task_crop_relationships(reference_task, existing_task, crop_mapper)
              @ctx.result.add_skip(:agricultural_tasks, existing_task.id)
              user_tasks << existing_task
              @ctx.reference_agricultural_task_id_to_user_task_id[reference_task.id] = existing_task.id
              next
            end

            new_task = @ctx.user.agricultural_tasks.build(
              name: reference_task.name,
              description: reference_task.description,
              time_per_sqm: reference_task.time_per_sqm,
              weather_dependency: reference_task.weather_dependency,
              required_tools: reference_task.required_tools ? reference_task.required_tools.dup : [],
              skill_level: reference_task.skill_level,
              task_type: reference_task.task_type,
              task_type_id: reference_task.task_type_id,
              region: reference_task.region || region,
              is_reference: false,
              source_agricultural_task_id: reference_task.id
            )

            unless new_task.save
              error_message = new_task.errors.full_messages.join(", ")
              Rails.logger.error "❌ [PlanSaveService] Agricultural task creation failed: #{error_message}"
              raise Domain::Shared::Exceptions::RecordInvalid, error_message
            end

            copy_agricultural_task_crop_relationships(reference_task, new_task, crop_mapper)

            user_tasks << new_task
            @ctx.reference_agricultural_task_id_to_user_task_id[reference_task.id] = new_task.id
            Rails.logger.info I18n.t("services.plan_save_service.messages.agricultural_task_created", task_name: new_task.name)
          end

          user_tasks
        end

        def user_agricultural_task_id_for(reference_task_id)
          @ctx.reference_agricultural_task_id_to_user_task_id ||= {}
          return @ctx.reference_agricultural_task_id_to_user_task_id[reference_task_id] if @ctx.reference_agricultural_task_id_to_user_task_id.key?(reference_task_id)

          user_task = @ctx.user.agricultural_tasks.find_by(source_agricultural_task_id: reference_task_id)
          if user_task
            @ctx.reference_agricultural_task_id_to_user_task_id[reference_task_id] = user_task.id
            return user_task.id
          end

          nil
        end

        def mapped_agricultural_task_id(reference_item)
          task = reference_item.agricultural_task
          return task.id if task&.user_id == @ctx.user.id

          reference_task_id = task&.id
          return nil unless reference_task_id

          user_agricultural_task_id_for(reference_task_id)
        end

        private

        def copy_agricultural_task_crop_relationships(reference_task, new_task, crop_mapper)
          reference_task.crop_task_templates.each do |template|
            user_crop_id = crop_mapper.user_crop_id_for_reference_crop(template.crop_id)
            next unless user_crop_id

            ensure_crop_task_template!(crop_id: user_crop_id, task: new_task)
          end
        end

        def ensure_crop_task_template!(crop_id:, task:)
          crop = ::Crop.find_by(id: crop_id)
          return unless crop

          template = crop.crop_task_templates.find_or_initialize_by(agricultural_task_id: task.id)
          return if template.persisted?

          template.assign_attributes(
            name: task.name,
            description: task.description,
            time_per_sqm: task.time_per_sqm,
            weather_dependency: task.weather_dependency,
            required_tools: task.required_tools,
            skill_level: task.skill_level,
            task_type: task.task_type,
            task_type_id: task.task_type_id,
            is_reference: task.is_reference
          )
          template.save!
        end
      end
    end
  end
end
