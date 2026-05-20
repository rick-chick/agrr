# frozen_string_literal: true

module Adapters
  module Agrr
    module Gateways
      # API 害虫 AI で ::Adapters::Agrr::Gateways::DaemonClient.pest_to_crop を叩く処理とリトライ
      class PestAiQueryDaemonGateway
        DEFAULT_MAX_RETRIES = 3

        def initialize(logger:, translator:, agrr_service: nil)
          @logger = logger
          @translator = translator
          @agrr_service = agrr_service || ::Adapters::Agrr::Gateways::DaemonClient.new
        end

        # @return [Hash] agrr の JSON 応答（success false のハッシュを含む）
        def fetch_pest_json(pest_name, affected_crops = [], max_retries: DEFAULT_MAX_RETRIES)
          fetch_pest_info_inner(pest_name, affected_crops, max_retries: max_retries)
        rescue ::Adapters::Agrr::Gateways::DaemonClient::AgrrError => e
          @logger.error "❌ [AI Pest] Error: #{e.message}"
          @logger.error "   Backtrace: #{e.backtrace&.first(3)&.join("\n   ")}"
          {
            "error_response" => true,
            "message" => @translator.t("api.errors.pests.fetch_failed_with_reason", message: e.message, default: "害虫情報の取得に失敗しました: %{message}"),
            "http_status" => :internal_server_error
          }
        end

        private

        def fetch_pest_info_inner(pest_name, affected_crops, max_retries:)
          attempt = 0
          last_error = nil

          max_retries.times do |retry_count|
            attempt = retry_count + 1

            begin
              crops_json = affected_crops.to_json
              @logger.debug "🔧 [AGRR Pest-to-Crop Query] pest-to-crop --pest #{pest_name} --crops #{crops_json} (attempt #{attempt}/#{max_retries})"

              stdout = @agrr_service.pest_to_crop(pest: pest_name, crops: crops_json, language: "ja")

              @logger.debug "📥 [AGRR Pest-to-Crop Output] #{stdout[0..500]}#{'...' if stdout.length > 500}"

              parsed_data = JSON.parse(stdout)

              if parsed_data["success"] == false
                @logger.error "📊 [AGRR Pest-to-Crop Error] #{parsed_data['error']} (code: #{parsed_data['code']})"
              else
                pest_data = parsed_data["data"]&.dig("pest")
                @logger.debug "📊 [AGRR Pest-to-Crop Data] name: #{pest_data&.dig('name')}"
                @logger.debug "📊 [AGRR Pest-to-Crop Data] family: #{pest_data&.dig('family')}"

                @logger.info "✅ [AGRR Pest-to-Crop Query] Succeeded after #{attempt} attempts" if attempt > 1
              end

              return parsed_data

            rescue ::Adapters::Agrr::Gateways::DaemonClient::DaemonNotRunningError => e
              @logger.error "❌ [AGRR Pest-to-Crop Query] Daemon not running: #{e.message}"
              return {
                "success" => false,
                "error" => @translator.t("api.errors.pests.daemon_not_running", default: "AGRRサービスが起動していません。サービスを起動してから再度お試しください。"),
                "code" => "daemon_not_running"
              }
            rescue ::Adapters::Agrr::Gateways::DaemonClient::CommandExecutionError => e
              error_msg = e.message

              if error_msg.include?("decompressing") ||
                 error_msg.include?("Connection") ||
                 error_msg.include?("timeout") ||
                 error_msg.include?("Network")

                @logger.warn "⚠️  [AGRR Pest-to-Crop Query] Transient error (attempt #{attempt}/#{max_retries}): #{error_msg}"

                if attempt < max_retries
                  sleep_time = 2 ** attempt
                  @logger.info "⏳ [AGRR Pest-to-Crop Query] Retrying in #{sleep_time} seconds..."
                  sleep(sleep_time)
                  next
                end
              end

              @logger.error "❌ [AGRR Pest-to-Crop Query Error] Command failed: #{error_msg}"
              raise ::Adapters::Agrr::Gateways::DaemonClient::CommandExecutionError, "Failed to query pest info from agrr: #{error_msg}"
            rescue JSON::ParserError => e
              @logger.error "❌ [AGRR Pest-to-Crop Query] JSON parse error: #{e.message}"
              raise ::Adapters::Agrr::Gateways::DaemonClient::CommandExecutionError, "Invalid JSON response from agrr: #{e.message}"

            rescue SystemCallError, IOError, SocketError, Timeout::Error => e
              last_error = e
              @logger.warn "⚠️  [AGRR Pest-to-Crop Query] Unexpected error (attempt #{attempt}/#{max_retries}): #{e.message}"

              if attempt < max_retries
                sleep_time = 2 ** attempt
                @logger.info "⏳ [AGRR Pest-to-Crop Query] Retrying in #{sleep_time} seconds..."
                sleep(sleep_time)
                next
              end

              raise ::Adapters::Agrr::Gateways::DaemonClient::CommandExecutionError, e.message
            end
          end

          if last_error
            raise ::Adapters::Agrr::Gateways::DaemonClient::CommandExecutionError, last_error.message
          else
            raise ::Adapters::Agrr::Gateways::DaemonClient::CommandExecutionError, "Failed to query pest info after #{max_retries} attempts"
          end
        end
      end
    end
  end
end
