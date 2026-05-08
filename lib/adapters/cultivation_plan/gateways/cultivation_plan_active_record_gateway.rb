# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanActiveRecordGateway < Domain::CultivationPlan::Gateways::CultivationPlanGateway
        include Adapters::Shared::Concerns::ActiveRecordTransactional

        def create(create_dto)
          result = initialize_plan_from_selection(
            farm: create_dto.farm,
            total_area: create_dto.total_area,
            crops: create_dto.crops,
            user: create_dto.user,
            plan_type: "private",
            plan_name: create_dto.plan_name,
            planning_start_date: Date.current.beginning_of_year,
            planning_end_date: Date.new(Date.current.year + 1, 12, 31)
          )
          unless result.success?
            raise Domain::Shared::Exceptions::RecordInvalid, result.errors.join(", ")
          end

          result
        end

        def find_with_field_cultivations_for_task_schedule(plan_id)
          plan = ::CultivationPlan.includes(
            field_cultivations: {
              cultivation_plan_crop: {
                crop: {
                  crop_task_templates: :agricultural_task,
                  crop_task_schedule_blueprints: :agricultural_task
                }
              }
            }
          ).find(plan_id)
          Adapters::CultivationPlan::Mappers::TaskScheduleGenerationContextMapper.from_plan_model(plan)
        end

        def total_field_area_for_farm(farm_id, user)
          return 0.0 unless ::Farm.find_by(id: farm_id, user_id: user.id)

          ::Field.where(farm_id: farm_id).sum(:area).to_f
        end

        # @return [Domain::CultivationPlan::Interactors::CultivationPlanInitializeInteractor::Result]
        def initialize_plan_from_selection(farm:, total_area:, crops:, user: nil, session_id: nil, plan_type: "public", plan_year: nil, plan_name: nil, planning_start_date: nil, planning_end_date: nil)
          ctx = InitializationContext.new(
            farm: normalize_farm_for_plan!(farm),
            total_area: total_area,
            crops: normalize_crops_for_plan!(crops),
            user: normalize_user_for_plan(user),
            session_id: session_id,
            plan_type: plan_type,
            plan_year: plan_year,
            plan_name: plan_name,
            planning_start_date: planning_start_date,
            planning_end_date: planning_end_date
          )

          if ctx.total_area <= 0
            error_msg = "総面積は0より大きい値である必要があります (total_area: #{ctx.total_area})"
            Rails.logger.error "❌ CultivationPlan creation failed: #{error_msg}"
            return Domain::CultivationPlan::Interactors::CultivationPlanInitializeInteractor::Result.new(
              cultivation_plan: nil,
              errors: [ error_msg ]
            )
          end

          within_transaction do
            ctx.create_cultivation_plan_and_relations
            entity = Adapters::CultivationPlan::Mappers::CultivationPlanEntityMapper.entity_from_model(ctx.cultivation_plan.reload)
            Domain::CultivationPlan::Interactors::CultivationPlanInitializeInteractor::Result.new(cultivation_plan: entity, errors: [])
          end
        rescue ActiveRecord::RecordInvalid => e
          raise Domain::Shared::Exceptions::RecordInvalid.new(
            e.message,
            errors: Domain::Shared::ValidationErrors.from_errors_like(e.record&.errors)
          )
        rescue StandardError => e
          # アダプタ境界: 永続化の例外を Result に畳み、Interactor が on_failure へ載せられるようにする（domain は AR を掴まない）。
          Rails.logger.error "❌ CultivationPlan creation failed: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          Domain::CultivationPlan::Interactors::CultivationPlanInitializeInteractor::Result.new(cultivation_plan: nil, errors: [ e.message ])
        end

        # プラン初期化の内部状態（Interactor から Gateway へ移した永続化ロジック）
        class InitializationContext
          attr_reader :farm, :total_area, :crops, :user, :session_id, :plan_type, :plan_year, :plan_name, :planning_start_date, :planning_end_date
          attr_accessor :cultivation_plan

          def initialize(farm:, total_area:, crops:, user: nil, session_id: nil, plan_type: "public", plan_year: nil, plan_name: nil, planning_start_date: nil, planning_end_date: nil)
            @farm = farm
            @total_area = total_area
            @crops = crops
            @user = user
            @session_id = session_id
            @plan_type = plan_type
            @plan_year = plan_year
            @plan_name = plan_name
            @planning_start_date = planning_start_date
            @planning_end_date = planning_end_date
          end

          def create_cultivation_plan_and_relations
            create_cultivation_plan
            create_cultivation_plan_crops
            create_cultivation_plan_fields
            Rails.logger.info "✅ Added #{@cultivation_plan.cultivation_plan_fields.count} fields and #{@cultivation_plan.cultivation_plan_crops.count} crops to CultivationPlan ##{@cultivation_plan.id}"
          end

          def fields_allocation
            @fields_allocation ||= ::FieldsAllocator.new(@total_area, @crops).allocate
          end

          def calculate_daily_cost(area)
            area * 1.0
          end

          def create_cultivation_plan
            plan_attrs = {
              farm: @farm,
              user: @user,
              total_area: @total_area,
              plan_type: @plan_type
            }
            plan_attrs[:session_id] = @session_id if @session_id.present?

            if @plan_type == "private"
              plan_attrs[:plan_year] = @plan_year
              plan_attrs[:plan_name] = @plan_name.presence || @farm.name
              plan_attrs[:planning_start_date] = @planning_start_date
              plan_attrs[:planning_end_date] = @planning_end_date
            else
              planning_dates = ::CultivationPlan.calculate_public_planning_dates
              plan_attrs[:planning_start_date] = planning_dates[:start_date]
              plan_attrs[:planning_end_date] = planning_dates[:end_date]
            end

            @cultivation_plan = ::CultivationPlan.create!(plan_attrs)
          end

          def create_cultivation_plan_crops
            @crops.each do |crop|
              ::CultivationPlanCrop.create!(
                cultivation_plan: @cultivation_plan,
                crop: crop,
                name: crop.name,
                variety: crop.variety,
                area_per_unit: crop.area_per_unit,
                revenue_per_area: crop.revenue_per_area
              )
            end
          end

          def create_cultivation_plan_fields
            fields_allocation.each_with_index do |allocation, index|
              ::CultivationPlanField.create!(
                cultivation_plan: @cultivation_plan,
                name: "#{index + 1}",
                area: allocation[:area],
                daily_fixed_cost: calculate_daily_cost(allocation[:area])
              )
            end
          end
        end
        private_constant :InitializationContext

        def find_existing(farm, user)
          plan = ::CultivationPlan.find_by(farm_id: farm.id, user_id: user.id, plan_type: "private")
          Adapters::CultivationPlan::Mappers::CultivationPlanEntityMapper.entity_from_model(plan)
        end

        def find_farm(farm_id, user)
          f = ::Farm.find_by(id: farm_id, user_id: user.id)
          f && Adapters::Farm::Mappers::FarmMapper.farm_entity_from_record(f)
        end

        def find_crops(crop_ids, user)
          ::Crop.where(id: crop_ids, user_id: user.id, is_reference: false).map do |c|
            Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(c)
          end
        end

        def find_by_id(plan_id)
          m = ::CultivationPlan.find(plan_id)
          Adapters::CultivationPlan::Mappers::CultivationPlanEntityMapper.entity_from_model(m)
        end

        # 栽培計画を削除し、DeletionUndo::Manager を使用して Undo トークンを返す
        #
        # @param plan_id [Integer] 削除する計画のID
        # @param user [User] 削除を実行するユーザー（所有権チェックに使用）
        # @return [DeletionUndoEvent] DeletionUndo::Manager.schedule が返すイベント
        # @raise [Domain::Shared::Exceptions::RecordNotFound, AssociationInUse, DeletionUndo::Error] 等
        def private_owned_plan_display_name(user:, plan_id:)
          plan_model = PlanPolicy.find_private_owned!(user, plan_id)
          plan_model.display_name
        rescue ::PolicyPermissionDenied, Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue ActiveRecord::RecordNotFound, Domain::Shared::Exceptions::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Cultivation plan not found"
        end

        def destroy(plan_id, user, toast_message:)
          plan_model = PlanPolicy.find_private_owned!(user, plan_id)

          DeletionUndo::Manager.schedule(
            record: plan_model,
            actor: Adapters::Shared::UserActorResolver.user_for_deleted_by(user),
            toast_message: toast_message
          )
        rescue ::PolicyPermissionDenied, Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue ActiveRecord::RecordNotFound, Domain::Shared::Exceptions::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Cultivation plan not found"
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError, Domain::Shared::Exceptions::AssociationInUse
          raise Domain::Shared::Exceptions::AssociationInUse, "Cultivation plan delete failed"
        rescue DeletionUndo::Error
          raise
        end

        # phase 更新
        def update_phase(plan_id, phase_name, *args)
          plan = ::CultivationPlan.find(plan_id)
          plan.public_send("#{phase_name}!", *args)
          true
        end

        def copy_private_plan_for_year(source_cultivation_plan_id:, new_year:, user_id:, session_id: nil, logger:)
          PlanCopyGateway.copy_private_plan_for_year(
            source_cultivation_plan_id: source_cultivation_plan_id,
            new_year: new_year,
            user_id: user_id,
            session_id: session_id,
            logger: logger
          )
        end

        def update_predicted_weather_data(cultivation_plan_id, payload)
          ::CultivationPlan.find(cultivation_plan_id).update!(predicted_weather_data: payload)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        rescue ActiveRecord::RecordInvalid => e
          raise Domain::Shared::Exceptions::RecordInvalid, e.message
        end

        def field_cultivations_present?(plan_id)
          ::CultivationPlan.find(plan_id).field_cultivations.exists?
        end

        def cultivation_plan_crops_with_crop(plan_id)
          rows = ::CultivationPlan.find(plan_id).cultivation_plan_crops.includes(
            crop: { crop_stages: [ :temperature_requirement, :thermal_requirement, :sunshine_requirement, :nutrient_requirement ] }
          )
          rows.map do |cpc|
            crop = cpc.crop
            Domain::CultivationPlan::Dtos::CultivationPlanCropWithAgrrDto.new(
              id: cpc.id,
              name: cpc.name,
              crop_id: cpc.crop_id,
              agrr_requirement: crop.to_agrr_requirement,
              revenue_per_area: crop.revenue_per_area,
              crop_name: crop.name
            )
          end
        end

        def clear_field_cultivations(plan_id)
          plan = ::CultivationPlan.find(plan_id)
          plan.field_cultivations.destroy_all
        end

        def create_field_cultivation(plan_id:, attrs:)
          plan = ::CultivationPlan.find(plan_id)
          fc = plan.field_cultivations.create!(attrs)
          Domain::CultivationPlan::Entities::FieldCultivationEntity.new(
            id: fc.id,
            cultivation_plan_id: fc.cultivation_plan_id,
            cultivation_plan_field_id: fc.cultivation_plan_field_id,
            cultivation_plan_crop_id: fc.cultivation_plan_crop_id,
            area: fc.area,
            start_date: fc.start_date,
            status: fc.status,
            created_at: fc.created_at,
            updated_at: fc.updated_at
          )
        end

        def upsert_cultivation_plan_field(plan_id:, name:, area:, daily_fixed_cost:)
          plan = ::CultivationPlan.find(plan_id)
          field = plan.cultivation_plan_fields.find_or_create_by!(name: name) do |f|
            f.area = area
            f.daily_fixed_cost = daily_fixed_cost
          end
          field.id
        end

        def find_plan_crop_id_by_crop_id!(plan_id, crop_id)
          plan = ::CultivationPlan.find(plan_id)
          cpc = plan.cultivation_plan_crops.find_by(crop_id: crop_id)
          return cpc.id if cpc

          available = plan.cultivation_plan_crops.pluck(:crop_id, :name)
          raise Domain::CultivationPlan::Errors::CultivationPlanCropMissingError,
                "CultivationPlanCrop not found for crop_id: #{crop_id}. This indicates a data integrity issue. Available CultivationPlanCrops: #{available.inspect}"
        end

        def apply_optimization_result(plan_id:, attrs:)
          ::CultivationPlan.find(plan_id).update!(attrs)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        rescue ActiveRecord::RecordInvalid => e
          raise Domain::Shared::Exceptions::RecordInvalid, e.message
        end

        def optimization_plan_snapshot(plan_id)
          plan = ::CultivationPlan.find(plan_id)
          wl = plan.farm&.weather_location
          farm = plan.farm
          wl_dto = if wl
            Domain::WeatherData::Dtos::WeatherLocationDto.new(
              id: wl.id,
              latitude: wl.latitude,
              longitude: wl.longitude,
              elevation: wl.elevation,
              timezone: wl.timezone,
              predicted_weather_data: wl.predicted_weather_data
            )
          end
          fm_dto = if farm
            Domain::WeatherData::Dtos::FarmWeatherPredictionDto.new(
              id: farm.id,
              weather_location_id: farm.weather_location_id,
              predicted_weather_data: farm.predicted_weather_data
            )
          end
          Domain::CultivationPlan::Dtos::OptimizationPlanSnapshotDto.new(
            plan_id: plan.id,
            plan_type_private: plan.plan_type_private?,
            calculated_planning_start_date: plan.calculated_planning_start_date,
            calculated_planning_end_date: plan.calculated_planning_end_date,
            prediction_target_end_date: plan.prediction_target_end_date,
            predicted_weather_data: plan.predicted_weather_data,
            total_area: plan.total_area,
            weather_location_present: wl.present?,
            weather_location_input: wl_dto,
            farm_weather_input: fm_dto
          )
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def private_plan_optimization_redirect_snapshot(user:, plan_id:)
          row = PlanPolicy.private_scope(user).where(id: plan_id).pick(:id, :status)
          raise Domain::Shared::Exceptions::RecordNotFound if row.nil?

          picked_id, status = row
          Domain::CultivationPlan::Dtos::PrivatePlanOptimizationRedirectDto.new(
            plan_id: picked_id,
            already_optimizing: Domain::CultivationPlan::PlanStatus.optimizing?(status)
          )
        end

        def private_plan_optimizing_read_model(plan_id:, user:)
          plan = PlanPolicy.private_scope(user).includes(:farm, :cultivation_plan_crops).find(plan_id)
          Domain::CultivationPlan::Dtos::PrivatePlanOptimizingReadModel.new(
            id: plan.id,
            plan_year: plan.plan_year,
            farm_display_name: plan.farm.display_name,
            cultivation_plan_crops_count: plan.cultivation_plan_crops.size,
            optimization_phase_message: plan.optimization_phase_message,
            status: plan.status
          )
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def public_plan_optimizing_read_model(plan_id:)
          plan = ::CultivationPlan.plan_type_public.includes(:farm, :cultivation_plan_crops).find(plan_id)
          Domain::CultivationPlan::Dtos::PublicPlanOptimizingReadModel.new(
            id: plan.id,
            plan_year: plan.plan_year,
            farm_display_name: plan.farm.display_name,
            cultivation_plan_crops_count: plan.cultivation_plan_crops.size,
            optimization_phase_message: plan.optimization_phase_message,
            status: plan.status
          )
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def find_private_cultivation_plan_detail(user:, plan_id:)
          Adapters::Shared::MapArPersistenceErrors.with_mapped_ar_persistence_failure do
            plan = PlanPolicy.private_scope(user)
                      .includes(
                        :farm,
                        field_cultivations: [ :cultivation_plan_field, :cultivation_plan_crop ],
                        cultivation_plan_fields: [],
                        cultivation_plan_crops: [ :crop ]
                      )
                      .find(plan_id)

            field_cultivations = plan.field_cultivations.map do |fc|
              Domain::CultivationPlan::Dtos::PrivateCultivationPlanDetailDto::FieldCultivationRead.new(
                id: fc.id,
                cultivation_plan_field_id: fc.cultivation_plan_field_id,
                field_display_name: fc.field_display_name,
                cultivation_plan_crop_id: fc.cultivation_plan_crop_id,
                crop_display_name: fc.crop_display_name,
                start_date: fc.start_date,
                completion_date: fc.completion_date,
                cultivation_days: fc.cultivation_days,
                area: fc.area,
                estimated_cost: fc.estimated_cost,
                optimization_profit: Domain::CultivationPlan::GanttChartRowHashes.profit_from_optimization_result(
                  fc.optimization_result
                )
              )
            end

            cultivation_plan_fields = plan.cultivation_plan_fields.map do |field|
              Domain::CultivationPlan::Dtos::PrivateCultivationPlanDetailDto::PlanFieldRead.new(
                id: field.id,
                name: field.name,
                area: field.area
              )
            end

            palette_used_crop_ids = plan.cultivation_plan_crops.map { |cpc| cpc.crop&.id }.compact
            palette_crops = ::Crop.user_owned
                               .where(user: user, is_reference: false)
                               .select(:id, :name, :variety, :groups)
                               .order(:name)
                               .map do |c|
              Domain::CultivationPlan::Dtos::PrivatePlanShowPaletteCropDto.new(
                id: c.id,
                name: c.name,
                variety: c.variety
              )
            end

            Domain::CultivationPlan::Dtos::PrivateCultivationPlanDetailDto.new(
              id: plan.id,
              display_name: plan.display_name,
              farm_display_name: plan.farm.display_name,
              total_area: plan.total_area,
              field_cultivations_count: plan.field_cultivations.size,
              cultivation_plan_fields_count: plan.cultivation_plan_fields.size,
              planning_start_date: plan.planning_start_date,
              planning_end_date: plan.planning_end_date,
              status: plan.status,
              field_cultivations: field_cultivations,
              cultivation_plan_fields: cultivation_plan_fields,
              palette_used_crop_ids: palette_used_crop_ids,
              palette_crops: palette_crops
            )
          end
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def task_schedule_timeline_read_model(user:, plan_id:)
          plan = PlanPolicy.private_scope(user).find(plan_id)
          schedules = TaskSchedule.where(cultivation_plan_id: plan.id)
                                  .includes(
                                    { task_schedule_items: :agricultural_task },
                                    field_cultivation: [
                                      :cultivation_plan_field,
                                      {
                                        cultivation_plan_crop: {
                                          crop: [
                                            :agricultural_tasks,
                                            { crop_task_templates: :agricultural_task }
                                          ]
                                        }
                                      }
                                    ]
                                  )

          timeline_generated_at = schedules.maximum(:generated_at)
          scheduled_dates = TaskScheduleItem
                              .joins(:task_schedule)
                              .where(task_schedules: { cultivation_plan_id: plan.id })
                              .where.not(scheduled_date: nil)
                              .pluck(:scheduled_date)

          fields = schedules.group_by(&:field_cultivation).map do |field_cultivation, field_schedules|
            build_task_schedule_timeline_field(field_cultivation, field_schedules)
          end

          Domain::CultivationPlan::Dtos::TaskScheduleTimelineReadModel.new(
            plan: Domain::CultivationPlan::Dtos::TaskScheduleTimelineReadModel::PlanRead.new(
              id: plan.id,
              display_name: plan.display_name,
              status: plan.status,
              planning_start_date: plan.planning_start_date,
              planning_end_date: plan.planning_end_date,
              timeline_generated_at: timeline_generated_at,
              farm_display_name: plan.farm.display_name,
              total_area: plan.total_area
            ),
            fields: fields,
            scheduled_dates: scheduled_dates
          )
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def aggregated_planning_schedule_fields(user:, farm_id:)
          farm = ::Farm.user_owned.by_user(user).find_by(id: farm_id)
          return [] unless farm

          plans = ::CultivationPlan
            .plan_type_private
            .by_user(user)
            .where(farm: farm)
            .includes(:cultivation_plan_fields)

          fields_hash = {}
          plans.each do |plan|
            plan.cultivation_plan_fields.each do |plan_field|
              field_name = plan_field.name
              unless fields_hash[field_name]
                fields_hash[field_name] = {
                  id: field_name.hash.abs,
                  name: field_name,
                  area: plan_field.area,
                  farm_name: farm.name
                }
              end
            end
          end

          fields_hash.values.sort_by { |f| f[:name] }
        end

        def planning_schedule_cultivations_for_field(user:, farm_id:, field_name:, period_start:, period_end:)
          farm = ::Farm.user_owned.by_user(user).find_by(id: farm_id)
          return [] unless farm

          plans = ::CultivationPlan
            .plan_type_private
            .by_user(user)
            .where(farm: farm)
            .includes(field_cultivations: [ :cultivation_plan_field, :cultivation_plan_crop ])

          cultivations = []
          plans.each do |plan|
            plan_start = plan.calculated_planning_start_date
            plan_end = plan.calculated_planning_end_date
            next unless plan_start && plan_end
            next unless plan_start <= period_end && plan_end >= period_start

            plan.field_cultivations.each do |field_cultivation|
              next unless field_cultivation.cultivation_plan_field.name == field_name &&
                field_cultivation.start_date &&
                field_cultivation.completion_date &&
                field_cultivation.start_date <= period_end &&
                field_cultivation.completion_date >= period_start

              if plan.plan_year.nil? || field_cultivation.start_date.year == plan.plan_year
                cultivations << {
                  crop_name: field_cultivation.cultivation_plan_crop.name,
                  start_date: field_cultivation.start_date,
                  completion_date: field_cultivation.completion_date,
                  area: field_cultivation.area
                }
              end
            end
          end

          cultivations.sort_by { |c| c[:start_date] }
        end

        # 部分 select の列は CultivationPlan#display_name（private）が参照する属性と一致させること
        def private_plan_index_plan_rows(user:)
          Adapters::Shared::MapArPersistenceErrors.with_mapped_ar_persistence_failure do
            plans = ::CultivationPlan
                      .plan_type_private
                      .by_user(user)
                      .select(
                        :id, :status, :plan_year, :plan_name, :plan_type,
                        :total_area, :farm_id, :planning_start_date, :planning_end_date,
                        :created_at, :updated_at
                      )
                      .preload(:farm)
                      .recent
                      .to_a

            plan_ids = plans.map(&:id)
            crops_count_hash = if plan_ids.empty?
              {}
            else
              ::CultivationPlanCrop.where(cultivation_plan_id: plan_ids)
                                   .group(:cultivation_plan_id)
                                   .count
            end
            fields_count_hash = if plan_ids.empty?
              {}
            else
              ::CultivationPlanField.where(cultivation_plan_id: plan_ids)
                                    .group(:cultivation_plan_id)
                                    .count
            end

            ordered_plans = plans.group_by(&:farm_id).values.flatten
            ordered_plans.map do |p|
              Domain::CultivationPlan::Dtos::PrivatePlanIndexPlanRowDto.new(
                id: p.id,
                farm_display_name: p.farm.display_name,
                total_area: p.total_area,
                crops_count: crops_count_hash[p.id] || 0,
                fields_count: fields_count_hash[p.id] || 0,
                status: p.status,
                display_name: p.display_name,
                created_at: p.created_at
              )
            end
          end
        end

        def normalize_farm_for_plan!(farm)
          return farm if farm.is_a?(::Farm)

          ::Farm.find(farm.id)
        end

        def normalize_user_for_plan(user)
          return nil if user.nil?
          return user if user.is_a?(::User)

          ::User.find(user.id)
        end

        def normalize_crops_for_plan!(crops)
          return [] if crops.blank?
          return crops if crops.first.is_a?(::Crop)

          crops.map { |c| ::Crop.find(c.id) }
        end

        def build_task_schedule_timeline_field(field_cultivation, schedules)
          task_options = build_task_schedule_task_options(field_cultivation)
          schedule_reads = schedules.map { |schedule| build_task_schedule_timeline_schedule(schedule) }

          Domain::CultivationPlan::Dtos::TaskScheduleTimelineReadModel::FieldRead.new(
            id: field_cultivation&.id,
            name: field_cultivation&.cultivation_plan_field&.name,
            crop_name: field_cultivation&.cultivation_plan_crop&.name || field_cultivation&.cultivation_plan_crop&.crop&.name,
            area_sqm: field_cultivation&.area,
            field_cultivation_id: field_cultivation&.id,
            crop_id: field_cultivation&.cultivation_plan_crop_id,
            task_options: task_options,
            schedules: schedule_reads
          )
        end

        def build_task_schedule_timeline_schedule(schedule)
          items = schedule.task_schedule_items.map do |item|
            Domain::CultivationPlan::Dtos::TaskScheduleTimelineReadModel::ItemRead.new(
              id: item.id,
              name: item.name,
              task_type: item.task_type,
              scheduled_date: item.scheduled_date,
              stage_name: item.stage_name,
              stage_order: item.stage_order,
              gdd_trigger: item.gdd_trigger,
              gdd_tolerance: item.gdd_tolerance,
              priority: item.priority,
              source: item.source,
              weather_dependency: item.weather_dependency,
              time_per_sqm: item.time_per_sqm,
              amount: item.amount,
              amount_unit: item.amount_unit,
              status: item.respond_to?(:status) ? item.status : nil,
              agricultural_task_id: item.agricultural_task_id,
              field_cultivation_id: schedule.field_cultivation_id,
              agricultural_task: build_task_schedule_task_master(item.agricultural_task),
              actual_date: item.actual_date,
              actual_notes: item.actual_notes,
              rescheduled_at: item.rescheduled_at,
              cancelled_at: item.cancelled_at,
              completed_at: item.completed_at
            )
          end

          Domain::CultivationPlan::Dtos::TaskScheduleTimelineReadModel::ScheduleRead.new(
            category: schedule.category,
            items: items
          )
        end

        def build_task_schedule_task_master(task)
          return nil unless task

          Domain::CultivationPlan::Dtos::TaskScheduleTimelineReadModel::AgriculturalTaskRead.new(
            name: task.name,
            description: task.description,
            time_per_sqm: task.time_per_sqm,
            weather_dependency: task.weather_dependency,
            required_tools: Array(task.required_tools).presence,
            skill_level: task.skill_level,
            task_type: task.task_type
          )
        end

        def build_task_schedule_task_options(field_cultivation)
          crop = field_cultivation&.cultivation_plan_crop&.crop
          return [] unless crop

          crop.crop_task_templates.sort_by(&:name).map do |template|
            Domain::CultivationPlan::Dtos::TaskScheduleTimelineReadModel::TaskOptionRead.new(
              template_id: template.id,
              name: template.name,
              task_type: template.task_type || TaskScheduleItem::FIELD_WORK_TYPE,
              agricultural_task_id: template.agricultural_task_id,
              description: template.description,
              weather_dependency: template.weather_dependency,
              time_per_sqm: template.time_per_sqm,
              required_tools: Array(template.required_tools).presence,
              skill_level: template.skill_level
            )
          end
        end

        def session_data_for_public_plan_save_from_plan_id(plan_id:)
          plan = ::CultivationPlan.find_by(id: plan_id)
          return nil unless plan

          {
            plan_id: plan.id,
            farm_id: plan.farm_id,
            crop_ids: plan.crops.pluck(:id),
            field_data: plan.cultivation_plan_fields.map do |field|
              {
                name: field.name,
                area: field.area,
                coordinates: [ 35.0, 139.0 ]
              }
            end
          }
        end

        def public_plan_results_page_read_model(plan_id:)
          plan = ::CultivationPlan.includes(
            :farm,
            cultivation_plan_fields: [],
            field_cultivations: [ :cultivation_plan_field, :cultivation_plan_crop ],
            cultivation_plan_crops: [ :crop ]
          ).find_by(id: plan_id)
          return nil unless plan

          gantt_cultivation_rows = plan.field_cultivations.map do |fc|
            Domain::CultivationPlan::GanttChartRowHashes.cultivation_row_from_ar(fc)
          end
          gantt_field_rows = plan.cultivation_plan_fields.map do |field|
            Domain::CultivationPlan::GanttChartRowHashes.field_row_from_ar(field)
          end

          used_crop_ids = plan.cultivation_plan_crops.map(&:crop_id).compact
          region = plan.farm&.region
          crop_rows = if region.present?
            ::Crop.reference.where(region: region).order(:name).map do |c|
              { id: c.id, name: c.name, variety: c.variety }
            end
          else
            []
          end
          crop_palette_embed = { used_crop_ids: used_crop_ids, crops: crop_rows }

          Domain::CultivationPlan::Dtos::PublicPlanResultsPageReadModel.new(
            plan_id: plan.id,
            status_completed: plan.status_completed?,
            planning_start_date: plan.planning_start_date,
            planning_end_date: plan.planning_end_date,
            farm_name: plan.farm&.name,
            total_area: plan.total_area,
            field_cultivations_count: plan.field_cultivations.size,
            total_cost: plan.total_cost,
            total_revenue: plan.total_revenue,
            total_profit: plan.total_profit,
            gantt_cultivation_rows: gantt_cultivation_rows,
            gantt_field_rows: gantt_field_rows,
            crop_palette_embed: crop_palette_embed,
            show_schedule_warning: public_plan_schedule_items_coverage_warning?(plan)
          )
        end

        def public_plan_wizard_plan_exists?(plan_id:)
          return false if plan_id.blank?

          ::CultivationPlan.find_by(id: plan_id).present?
        end

        def public_plan_html_save_session_payload(plan_id:, farm_id:, crop_ids:)
          plan = ::CultivationPlan.find_by(id: plan_id)
          return nil unless plan

          {
            plan_id: plan.id,
            farm_id: farm_id,
            crop_ids: crop_ids,
            field_data: plan.cultivation_plan_fields.map do |field|
              {
                name: field.name,
                area: field.area,
                coordinates: [ 35.0, 139.0 ]
              }
            end
          }
        end

        private

        # 結果ページ ReadModel の `show_schedule_warning` 用（SQL 条件は同一）
        def public_plan_schedule_items_coverage_warning?(plan_model)
          total_fc = plan_model.field_cultivations.count
          return false if total_fc.zero?

          with_items_fc = ::TaskSchedule
            .where(cultivation_plan_id: plan_model.id)
            .joins(:task_schedule_items)
            .distinct
            .count(:field_cultivation_id)

          with_items_fc < total_fc
        end
      end
    end
  end
end
