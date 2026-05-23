# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      # 既存肥料を agrr 応答で更新する。
      class FertilizeAiUpdateInteractor
        def initialize(
          user_id:,
          user_lookup:,
          fertilize_gateway:,
          fertilize_ai_query_gateway:,
          update_interactor:,
          logger:,
          translator:
        )
          @user_id = user_id
          @user_lookup = user_lookup
          @fertilize_gateway = fertilize_gateway
          @fertilize_ai_query_gateway = fertilize_ai_query_gateway
          @update_interactor = update_interactor
          @logger = logger
          @translator = translator
        end

        # @return [Domain::Shared::Dtos::HttpJsonEnvelope]
        def call(fertilize_id:, fertilize_query_name:)
          user = @user_lookup.find(@user_id)

          fertilize_name = fertilize_query_name&.strip
          if fertilize_name.nil? || fertilize_name.empty?
            return Domain::Shared::Dtos::HttpJsonEnvelope.new(
              status: :bad_request,
              body: { error: @translator.t("api.errors.fertilizes.name_required") }
            )
          end

          fertilize_record = load_authorized_fertilize(user, fertilize_id)
          unless fertilize_record
            return Domain::Shared::Dtos::HttpJsonEnvelope.new(
              status: :not_found,
              body: { error: @translator.t("api.errors.fertilizes.not_found", default: "肥料が見つかりません") }
            )
          end

          @logger.info "🤖 [AI Fertilize] Querying fertilize info for update: #{fertilize_name} (ID: #{fertilize_record.id})"
          fertilize_info = @fertilize_ai_query_gateway.fetch_for_update(id: fertilize_record.id, name: fertilize_name)

          if fertilize_info["success"] == false
            error_msg = fertilize_info["error"] || @translator.t("api.errors.fertilizes.fetch_failed")
            status_code = fertilize_info["code"] == "daemon_not_running" ? :service_unavailable : :unprocessable_entity
            return Domain::Shared::Dtos::HttpJsonEnvelope.new(status: status_code, body: { error: error_msg })
          end

          fertilize_data = Domain::Fertilize::Mappers::FertilizeAiAgrrMapper.normalize_fertilize_payload(fertilize_info)
          unless fertilize_data
            return Domain::Shared::Dtos::HttpJsonEnvelope.new(
              status: :unprocessable_entity,
              body: { error: @translator.t("api.errors.fertilizes.invalid_payload") }
            )
          end

          fertilize_name_from_agrr = fertilize_data["name"]

          @logger.info "🔄 [AI Fertilize] Updating fertilize##{fertilize_record.id} with latest data from agrr"

          attrs = {
            name: fertilize_name_from_agrr,
            n: fertilize_data["n"],
            p: fertilize_data["p"],
            k: fertilize_data["k"],
            description: fertilize_data["description"],
            package_size: fertilize_data["package_size"]
          }

          result = @update_interactor.call(fertilize_record.id, attrs.symbolize_keys)

          unless result.success?
            @logger.error "❌ [AI Fertilize] Failed to update: #{result.error}"
            return Domain::Shared::Dtos::HttpJsonEnvelope.new(status: :unprocessable_entity, body: { error: result.error })
          end

          fertilize_entity = result.data
          @logger.info "✅ [AI Fertilize] Updated fertilize##{fertilize_entity.id}: #{fertilize_entity.name}"

          Domain::Shared::Dtos::HttpJsonEnvelope.new(
            status: :ok,
            body: {
              success: true,
              fertilize_id: fertilize_entity.id,
              fertilize_name: fertilize_entity.name,
              n: fertilize_entity.n,
              p: fertilize_entity.p,
              k: fertilize_entity.k,
              description: fertilize_entity.description,
              package_size: fertilize_entity.package_size,
              is_reference: fertilize_entity.is_reference,
              message: @translator.t("api.messages.fertilizes.updated_by_ai", name: fertilize_entity.name, default: "肥料「%{name}」を更新しました")
            }
          )
        end

        private

        def load_authorized_fertilize(user, fertilize_id)
          access_filter = Domain::Shared::Policies::FertilizePolicy.record_access_filter(user)
          entity = @fertilize_gateway.find_by_id(fertilize_id.to_i)
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, entity)
          entity
        rescue Domain::Shared::Policies::PolicyPermissionDenied, Domain::Shared::Exceptions::RecordNotFound
          nil
        end
      end
    end
  end
end
