# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      # 既存害虫を agrr 応答で更新する。
      class PestAiUpdateInteractor
        def initialize(
          user_id:,
          user_lookup:,
          pest_gateway:,
          pest_ai_query_gateway:,
          update_interactor:,
          logger:,
          translator:
        )
          @user_id = user_id
          @user_lookup = user_lookup
          @pest_gateway = pest_gateway
          @pest_ai_query_gateway = pest_ai_query_gateway
          @update_interactor = update_interactor
          @logger = logger
          @translator = translator
        end

        # @return [Domain::Shared::Dtos::HttpJsonEnvelope]
        def call(pest_id:, pest_query_name:)
          user = @user_lookup.find(@user_id)

          pn = pest_query_name&.strip
          if pn.nil? || pn.empty?
            return Domain::Shared::Dtos::HttpJsonEnvelope.new(
              status: :bad_request,
              body: { error: @translator.t("api.errors.pests.name_required", default: "害虫名を入力してください") }
            )
          end

          pest_entity = load_authorized_pest_entity(user, pest_id)
          unless pest_entity
            return Domain::Shared::Dtos::HttpJsonEnvelope.new(
              status: :not_found,
              body: { error: @translator.t("api.errors.pests.not_found", default: "害虫が見つかりません") }
            )
          end

          @logger.info "🤖 [AI Pest] Querying pest info for update: #{pn} (ID: #{pest_entity.id})"
          pest_info = @pest_ai_query_gateway.fetch_pest_json(pn, [])

          interpreted = Domain::Pest::Mappers::PestAiResponseMapper.interpret(
            pest_info,
            translator: @translator,
            validate_affected_crops_shape: false
          )
          return interpreted.error_result if interpreted.error_result

          pest_data = interpreted.pest_data

          @logger.info "🔄 [AI Pest] Updating pest##{pest_entity.id} with latest data from agrr"

          attrs = {
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

          result = @update_interactor.call(pest_entity.id, attrs.symbolize_keys)

          unless result.success?
            @logger.error "❌ [AI Pest] Failed to update: #{result.error}"
            return Domain::Shared::Dtos::HttpJsonEnvelope.new(status: :unprocessable_entity, body: { error: result.error })
          end

          pest_entity = result.data
          @logger.info "✅ [AI Pest] Updated pest##{pest_entity.id}: #{pest_entity.name}"

          Domain::Shared::Dtos::HttpJsonEnvelope.new(
            status: :ok,
            body: {
              success: true,
              pest_id: pest_entity.id,
              pest_name: pest_entity.name,
              name_scientific: pest_entity.name_scientific,
              family: pest_entity.family,
              order: pest_entity.order,
              description: pest_entity.description,
              occurrence_season: pest_entity.occurrence_season,
              is_reference: pest_entity.is_reference,
              message: @translator.t("api.messages.pests.updated_by_ai", name: pest_entity.name, default: "害虫「%{name}」を更新しました")
            }
          )
        end

        private

        def load_authorized_pest_entity(user, pest_id)
          access_filter = Domain::Shared::Policies::PestPolicy.record_access_filter(user)
          @pest_gateway.find_authorized_for_edit(user, pest_id.to_i, access_filter: access_filter)
        rescue Domain::Shared::Policies::PolicyPermissionDenied, Domain::Shared::Exceptions::RecordNotFound
          nil
        end
      end
    end
  end
end
