# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanActiveRecordGateway < Domain::CultivationPlan::Gateways::CultivationPlanGateway
        include Adapters::Shared::Concerns::ActiveRecordTransactional

        attr_accessor :translator

        def initialize(translator:)
          @translator = translator
        end

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
            raise StandardError, result.errors.join(", ")
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
        # @raise [StandardError] 削除に失敗した場合（RecordNotFound, InvalidForeignKey, DeleteRestrictionError, DeletionUndo::Error 等）
        def destroy(plan_id, user)
          plan_model = PlanPolicy.find_private_owned!(user, plan_id)

          DeletionUndo::Manager.schedule(
            record: plan_model,
            actor: Adapters::Shared::UserActorResolver.user_for_deleted_by(user),
            toast_message: @translator.t("plans.undo.toast", name: plan_model.display_name)
          )
        rescue ::PolicyPermissionDenied, Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue ActiveRecord::RecordNotFound, Domain::Shared::Exceptions::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, @translator.t("plans.errors.not_found")
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
          raise Domain::Shared::Exceptions::AssociationInUse, @translator.t("plans.errors.delete_failed")
        rescue DeletionUndo::Error
          raise
        end

        # phase 更新
        def update_phase(plan_id, phase_name, *args)
          plan = ::CultivationPlan.find(plan_id)
          plan.public_send("#{phase_name}!", *args)
          true
        end

        def copy_private_plan_for_year(source_cultivation_plan_id:, new_year:, user:, session_id: nil, logger:)
          PlanCopyGateway.copy_private_plan_for_year(
            source_cultivation_plan_id: source_cultivation_plan_id,
            new_year: new_year,
            user: user,
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
          raise StandardError,
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
      end
    end
  end
end
