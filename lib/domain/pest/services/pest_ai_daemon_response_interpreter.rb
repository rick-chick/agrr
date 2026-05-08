# frozen_string_literal: true

module Domain
  module Pest
    module Services
      # agrr 害虫応答ハッシュを API 向けに解釈する（コントローラの分岐を集約）。
      class PestAiDaemonResponseInterpreter
        Interpretation = Struct.new(:error_result, :pest_data, :affected_crops_from_agrr, keyword_init: true)

        class << self
          def interpret(pest_info, translator:, validate_affected_crops_shape:)
            if pest_info["error_response"]
              return Interpretation.new(
                error_result: Domain::Shared::Dtos::HttpJsonEnvelope.new(
                  status: pest_info["http_status"],
                  body: { error: pest_info["message"] }
                ),
                pest_data: nil,
                affected_crops_from_agrr: nil
              )
            end

            if pest_info["success"] == false
              error_msg = pest_info["error"] || translator.t("api.errors.pests.fetch_failed", default: "害虫情報の取得に失敗しました")
              status_code = pest_info["code"] == "daemon_not_running" ? :service_unavailable : :unprocessable_entity
              return Interpretation.new(
                error_result: Domain::Shared::Dtos::HttpJsonEnvelope.new(status: status_code, body: { error: error_msg }),
                pest_data: nil,
                affected_crops_from_agrr: nil
              )
            end

            pest_data = pest_info["data"]&.dig("pest")
            unless pest_data
              return Interpretation.new(
                error_result: Domain::Shared::Dtos::HttpJsonEnvelope.new(
                  status: :unprocessable_entity,
                  body: { error: translator.t("api.errors.pests.invalid_payload", default: "不正なデータ形式です") }
                ),
                pest_data: nil,
                affected_crops_from_agrr: nil
              )
            end

            affected_crops_from_agrr = pest_info.dig("data", "affected_crops")
            if validate_affected_crops_shape && !affected_crops_from_agrr.nil? && !affected_crops_from_agrr.is_a?(Array)
              message = translator.t(
                "api.errors.pests.invalid_affected_crops",
                default: "agrr応答のaffected_cropsが不正です"
              )
              return Interpretation.new(
                error_result: Domain::Shared::Dtos::HttpJsonEnvelope.new(status: :unprocessable_entity, body: { error: message }),
                pest_data: nil,
                affected_crops_from_agrr: nil
              )
            end

            Interpretation.new(error_result: nil, pest_data: pest_data, affected_crops_from_agrr: affected_crops_from_agrr)
          end
        end
      end
    end
  end
end
