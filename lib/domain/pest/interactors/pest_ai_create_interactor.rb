# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      # agrr 取得〜保存〜作物関連付けまで（エッジの runner で AR User を閉じ込める）。
      class PestAiCreateInteractor
        def initialize(
          user_id:,
          user_lookup:,
          pest_gateway:,
          pest_ai_query_gateway:,
          create_interactor:,
          update_interactor:,
          logger:,
          translator:,
          associate_affected_crops_runner:
        )
          @user_id = user_id
          @user_lookup = user_lookup
          @pest_gateway = pest_gateway
          @pest_ai_query_gateway = pest_ai_query_gateway
          @create_interactor = create_interactor
          @update_interactor = update_interactor
          @logger = logger
          @translator = translator
          @associate_affected_crops_runner = associate_affected_crops_runner
        end

        # @param pest_name [String, nil]
        # @param affected_crops [Array<Hash>] crop_id / crop_name を含む素のハッシュ（コントローラで Parameters を除去済み）
        # @return [Domain::Shared::Dtos::ApiJsonResult]
        def call(pest_name:, affected_crops:)
          user = @user_lookup.find(@user_id)
          if user.anonymous?
            return Domain::Shared::Dtos::ApiJsonResult.new(
              status: :unauthorized,
              body: { error: @translator.t("auth.api.login_required") }
            )
          end

          pn = pest_name&.strip
          if pn.nil? || pn.empty?
            return Domain::Shared::Dtos::ApiJsonResult.new(
              status: :bad_request,
              body: { error: @translator.t("api.errors.pests.name_required", default: "害虫名を入力してください") }
            )
          end

          crops_arg = affected_crops.is_a?(Array) ? affected_crops : []

          @logger.info "🔍 [AI Pest] Received params: name=#{pn}"
          @logger.info "🔍 [AI Pest] affected_crops (processed): #{crops_arg.inspect}"
          @logger.info "🔍 [AI Pest] affected_crops count: #{crops_arg.count}"

          @logger.info "🤖 [AI Pest] Querying pest info for: #{pn}"
          pest_info = @pest_ai_query_gateway.fetch_pest_json(pn, crops_arg)

          interpreted = Domain::Pest::Services::PestAiDaemonResponseInterpreter.interpret(
            pest_info,
            translator: @translator,
            validate_affected_crops_shape: true
          )
          return interpreted.error_result if interpreted.error_result

          pest_data = interpreted.pest_data
          affected_crops_from_agrr = interpreted.affected_crops_from_agrr

          @logger.info "📊 [AI Pest] Retrieved data: name=#{pest_data['name']}, family=#{pest_data['family']}"

          existing_pest = @pest_gateway.find_user_owned_non_reference_pest_record_by_name(
            user_id: @user_id,
            name: pest_data["name"]
          )

          base_attrs = {
            name: pest_data["name"],
            name_scientific: pest_data["name_scientific"],
            family: pest_data["family"],
            order: pest_data["order"],
            description: pest_data["description"],
            occurrence_season: pest_data["occurrence_season"],
            temperature_profile: pest_data["temperature_profile"],
            thermal_requirement: pest_data["thermal_requirement"],
            control_methods: pest_data["control_methods"] || []
          }

          if existing_pest
            @logger.info "🔄 [AI Pest] Updating existing pest##{existing_pest.id}: #{pest_data['name']}"
            result = @update_interactor.call(existing_pest.id, base_attrs)
            status_code = :ok
          else
            @logger.info "🆕 [AI Pest] Creating new pest: #{pest_data['name']}"
            normalized = Domain::Shared::Policies::PestPolicy.normalize_attrs_for_create(user, {})
            attrs_for_create = base_attrs.merge(
              user_id: normalized[:user_id],
              is_reference: normalized[:is_reference]
            )
            result = @create_interactor.call(attrs_for_create.symbolize_keys)
            status_code = :created
          end

          unless result.success?
            @logger.error "❌ [AI Pest] Failed to #{existing_pest ? 'update' : 'create'}: #{result.error}"
            return Domain::Shared::Dtos::ApiJsonResult.new(status: :unprocessable_entity, body: { error: result.error })
          end

          pest_entity = result.data
          action = existing_pest ? "Updated" : "Created"
          @logger.info "✅ [AI Pest] #{action} pest##{pest_entity.id}: #{pest_entity.name}"

          chosen_affected_crops = if affected_crops_from_agrr.is_a?(Array) && affected_crops_from_agrr.any?
            @logger.info "🔗 [AI Pest] Using affected_crops from agrr response: #{affected_crops_from_agrr.inspect}"
            affected_crops_from_agrr
          else
            @logger.info "🔗 [AI Pest] Using affected_crops from UI params: #{crops_arg.inspect}"
            crops_arg
          end

          if chosen_affected_crops.is_a?(Array) && !chosen_affected_crops.empty?
            @logger.info "🔗 [AI Pest] Starting crop association for pest##{pest_entity.id} (count=#{chosen_affected_crops.size})"
            @associate_affected_crops_runner.call(pest_entity.id, chosen_affected_crops)
          else
            @logger.warn "⚠️  [AI Pest] Skipping crop association: affected_crops is empty or not an array"
          end

          Domain::Shared::Dtos::ApiJsonResult.new(
            status: status_code,
            body: {
              success: true,
              pest_id: pest_entity.id,
              pest_name: pest_entity.name,
              name_scientific: pest_entity.name_scientific,
              family: pest_entity.family,
              order: pest_entity.order,
              description: pest_entity.description,
              occurrence_season: pest_entity.occurrence_season,
              message: @translator.t("api.messages.pests.created_by_ai", name: pest_entity.name, default: "害虫「%{name}」の情報を取得して保存しました")
            }
          )
        end
      end
    end
  end
end
