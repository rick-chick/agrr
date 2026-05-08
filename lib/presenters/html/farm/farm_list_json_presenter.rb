# frozen_string_literal: true

module Presenters
  module Html
    module Farm
      class FarmListJsonPresenter < Domain::Farm::Ports::FarmListRowsBundleOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(rows_bundle_dto)
          farm_rows = rows_bundle_dto.farm_rows.is_a?(Array) ? rows_bundle_dto.farm_rows : []
          ref_rows = rows_bundle_dto.reference_farm_rows.is_a?(Array) ? rows_bundle_dto.reference_farm_rows : []
          farms = farm_rows.map { |row| farm_list_row_to_json(row) }
          reference_farms = ref_rows.map { |row| farm_list_row_to_json(row) }
          @view.render_response(json: { farms: farms, reference_farms: reference_farms }, status: :ok)
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

        def farm_list_row_to_json(row)
          {
            id: row.id,
            name: row.display_name,
            latitude: row.latitude,
            longitude: row.longitude,
            region: row.region,
            user_id: row.user_id,
            created_at: row.created_at,
            updated_at: row.updated_at,
            is_reference: row.is_reference
          }
        end
      end
    end
  end
end
