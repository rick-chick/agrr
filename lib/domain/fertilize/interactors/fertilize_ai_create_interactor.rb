# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      # agrr から肥料情報を取得し、新規作成または既存更新まで行う。
      class FertilizeAiCreateInteractor
        def initialize(
          output_port:,
          user_id:,
          user_lookup:,
          fertilize_gateway:,
          fertilize_ai_query_gateway:,
          create_interactor:,
          update_interactor:,
          logger:,
          translator:
        )
          @output_port = output_port
          @user_id = user_id
          @user_lookup = user_lookup
          @fertilize_gateway = fertilize_gateway
          @fertilize_ai_query_gateway = fertilize_ai_query_gateway
          @create_interactor = create_interactor
          @update_interactor = update_interactor
          @logger = logger
          @translator = translator
        end

        def call(fertilize_query_name:)
          user = @user_lookup.find(@user_id)
          if user.anonymous?
            return @output_port.on_failure(
              Domain::Fertilize::Dtos::FertilizeAiCreateFailure.new(
                http_status: :unauthorized,
                message: @translator.t("auth.api.login_required")
              )
            )
          end

          fertilize_name = fertilize_query_name&.strip
          if fertilize_name.nil? || fertilize_name.empty?
            return @output_port.on_failure(
              Domain::Fertilize::Dtos::FertilizeAiCreateFailure.new(
                http_status: :bad_request,
                message: @translator.t("api.errors.fertilizes.name_required")
              )
            )
          end

          @logger.info "🤖 [AI Fertilize] Querying fertilize info for: #{fertilize_name}"
          fertilize_info = @fertilize_ai_query_gateway.fetch_for_create(name: fertilize_name) || {}

          if fertilize_info["success"] == false
            error_msg = fertilize_info["error"] || @translator.t("api.errors.fertilizes.fetch_failed")
            status_code = fertilize_info["code"] == "daemon_not_running" ? :service_unavailable : :unprocessable_entity
            return @output_port.on_failure(
              Domain::Fertilize::Dtos::FertilizeAiCreateFailure.new(http_status: status_code, message: error_msg)
            )
          end

          fertilize_data = Domain::Fertilize::Mappers::FertilizeAiAgrrMapper.normalize_fertilize_payload(fertilize_info)

          unless fertilize_data
            return @output_port.on_failure(
              Domain::Fertilize::Dtos::FertilizeAiCreateFailure.new(
                http_status: :unprocessable_entity,
                message: @translator.t("api.errors.fertilizes.invalid_payload")
              )
            )
          end

          fertilize_name_from_agrr = fertilize_data["name"]

          base_attrs = {
            name: fertilize_name_from_agrr,
            n: fertilize_data["n"],
            p: fertilize_data["p"],
            k: fertilize_data["k"],
            description: fertilize_data["description"],
            package_size: fertilize_data["package_size"]
          }

          @logger.info "📊 [AI Fertilize] Retrieved data: name=#{fertilize_name_from_agrr}, n=#{fertilize_data['n']}, p=#{fertilize_data['p']}, k=#{fertilize_data['k']}, package_size=#{fertilize_data['package_size']}"

          existing_fertilize = @fertilize_gateway.find_by_name(
            user_id: @user_id,
            name: fertilize_name_from_agrr
          )

          if existing_fertilize
            @logger.info "🔄 [AI Fertilize] Updating existing fertilize##{existing_fertilize.id}: #{fertilize_name_from_agrr}"
            result = @update_interactor.call(existing_fertilize.id, base_attrs.symbolize_keys)
            http_status = :ok
          else
            @logger.info "🆕 [AI Fertilize] Creating new fertilize: #{fertilize_name_from_agrr}"
            normalized = Domain::Shared::Policies::FertilizePolicy.normalize_attrs_for_create(user, base_attrs)
            attrs_for_create = base_attrs.merge(
              user_id: normalized[:user_id],
              is_reference: normalized[:is_reference]
            )
            result = @create_interactor.call(attrs_for_create)
            http_status = :created
          end

          unless result.success?
            @logger.error "❌ [AI Fertilize] Failed to #{existing_fertilize ? 'update' : 'create'}: #{result.error}"
            return @output_port.on_failure(
              Domain::Fertilize::Dtos::FertilizeAiCreateFailure.new(
                http_status: :unprocessable_entity,
                message: result.error
              )
            )
          end

          fertilize_entity = result.data
          action = existing_fertilize ? "Updated" : "Created"
          @logger.info "✅ [AI Fertilize] #{action} fertilize##{fertilize_entity.id}: #{fertilize_entity.name}"

          @output_port.on_success(
            Domain::Fertilize::Dtos::FertilizeAiCreateOutput.new(
              http_status: http_status,
              fertilize_id: fertilize_entity.id,
              fertilize_name: fertilize_entity.name,
              n: fertilize_entity.n,
              p: fertilize_entity.p,
              k: fertilize_entity.k,
              description: fertilize_entity.description,
              package_size: fertilize_entity.package_size,
              message: @translator.t("api.messages.fertilizes.created_by_ai", name: fertilize_entity.name)
            )
          )
        end
      end
    end
  end
end
