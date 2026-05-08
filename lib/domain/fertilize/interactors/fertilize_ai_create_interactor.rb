# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      # agrr から肥料情報を取得し、新規作成または既存更新まで行う。
      class FertilizeAiCreateInteractor
        def initialize(
          user_id:,
          user_lookup:,
          fertilize_gateway:,
          fertilize_ai_query_gateway:,
          create_interactor:,
          update_interactor:,
          logger:,
          translator:
        )
          @user_id = user_id
          @user_lookup = user_lookup
          @fertilize_gateway = fertilize_gateway
          @fertilize_ai_query_gateway = fertilize_ai_query_gateway
          @create_interactor = create_interactor
          @update_interactor = update_interactor
          @logger = logger
          @translator = translator
        end

        # @return [Domain::Shared::Dtos::ApiJsonResult]
        def call(fertilize_query_name:)
          user = @user_lookup.find(@user_id)
          if user.anonymous?
            return Domain::Shared::Dtos::ApiJsonResult.new(
              status: :unauthorized,
              body: { error: @translator.t("auth.api.login_required") }
            )
          end

          fertilize_name = fertilize_query_name&.strip
          if fertilize_name.nil? || fertilize_name.empty?
            return Domain::Shared::Dtos::ApiJsonResult.new(
              status: :bad_request,
              body: { error: @translator.t("api.errors.fertilizes.name_required") }
            )
          end

          @logger.info "🤖 [AI Fertilize] Querying fertilize info for: #{fertilize_name}"
          fertilize_info = @fertilize_ai_query_gateway.fetch_for_create(name: fertilize_name)

          if fertilize_info["success"] == false
            error_msg = fertilize_info["error"] || @translator.t("api.errors.fertilizes.fetch_failed")
            status_code = fertilize_info["code"] == "daemon_not_running" ? :service_unavailable : :unprocessable_entity
            return Domain::Shared::Dtos::ApiJsonResult.new(status: status_code, body: { error: error_msg })
          end

          fertilize_data = Domain::Fertilize::Services::FertilizeAiAgrrPayloadNormalizer.normalize_fertilize_payload(fertilize_info)

          unless fertilize_data
            return Domain::Shared::Dtos::ApiJsonResult.new(
              status: :unprocessable_entity,
              body: { error: @translator.t("api.errors.fertilizes.invalid_payload") }
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

          existing_fertilize = @fertilize_gateway.find_user_owned_non_reference_fertilize_record_by_name(
            user_id: @user_id,
            name: fertilize_name_from_agrr
          )

          if existing_fertilize
            @logger.info "🔄 [AI Fertilize] Updating existing fertilize##{existing_fertilize.id}: #{fertilize_name_from_agrr}"
            result = @update_interactor.call(existing_fertilize.id, base_attrs.symbolize_keys)
            status_code = :ok
          else
            @logger.info "🆕 [AI Fertilize] Creating new fertilize: #{fertilize_name_from_agrr}"
            normalized = Domain::Shared::Policies::FertilizePolicy.normalize_attrs_for_create(user, base_attrs)
            attrs_for_create = base_attrs.merge(
              user_id: normalized[:user_id],
              is_reference: normalized[:is_reference]
            )
            result = @create_interactor.call(attrs_for_create)
            status_code = :created
          end

          unless result.success?
            @logger.error "❌ [AI Fertilize] Failed to #{existing_fertilize ? 'update' : 'create'}: #{result.error}"
            return Domain::Shared::Dtos::ApiJsonResult.new(status: :unprocessable_entity, body: { error: result.error })
          end

          fertilize_entity = result.data
          action = existing_fertilize ? "Updated" : "Created"
          @logger.info "✅ [AI Fertilize] #{action} fertilize##{fertilize_entity.id}: #{fertilize_entity.name}"

          Domain::Shared::Dtos::ApiJsonResult.new(
            status: status_code,
            body: {
              success: true,
              fertilize_id: fertilize_entity.id,
              fertilize_name: fertilize_entity.name,
              n: fertilize_entity.n,
              p: fertilize_entity.p,
              k: fertilize_entity.k,
              description: fertilize_entity.description,
              package_size: fertilize_entity.package_size,
              message: @translator.t("api.messages.fertilizes.created_by_ai", name: fertilize_entity.name)
            }
          )
        end
      end
    end
  end
end
