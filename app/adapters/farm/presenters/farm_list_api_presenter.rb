# frozen_string_literal: true

module Adapters
  module Farm
    module Presenters
      class FarmListApiPresenter < Domain::Farm::Ports::FarmListOutputPort
        def initialize(view:)
          @view = view
        end

        # reference_farms はポート互換のため受け取るが、API index は従来どおりメイン一覧のみ JSON 配列で返す
        def on_success(farms, reference_farms: [])
          json = farms.is_a?(Array) ? farms.map { |e| farm_entity_to_json(e) } : []
          @view.render_response(json: json, status: :ok)
        end

        def on_failure(err)
          if err.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.render_response(json: { error: I18n.t("farms.flash.no_permission") }, status: :forbidden)
          else
            msg = err.respond_to?(:message) ? err.message : err.to_s
            @view.render_response(json: { error: msg }, status: :unprocessable_entity)
          end
        end

        private

        def farm_entity_to_json(entity)
          {
            id: entity.id,
            name: entity.name,
            latitude: entity.latitude,
            longitude: entity.longitude,
            region: entity.region,
            user_id: entity.user_id,
            created_at: entity.created_at,
            updated_at: entity.updated_at,
            is_reference: entity.is_reference
          }
        end
      end
    end
  end
end
