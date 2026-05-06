# frozen_string_literal: true

module Adapters
  module Agrr
    # API 作物 AI 作成で AgrrService.crop を叩く処理とリトライ（Controller の rescue を不要にする）
    class CropAiDaemonQueryGateway
      DEFAULT_MAX_RETRIES = 3

      def initialize(logger:, translator:, agrr_service: nil)
        @logger = logger
        @translator = translator
        @agrr_service = agrr_service || AgrrService.new
      end

      # @return [Array(Hash, nil)] 成功時 [parsed_data, nil]
      # @return [Array(nil, Hash)] 失敗時 [nil, { message:, status: }]
      def fetch_crop_json(crop_name)
        [ fetch_crop_info_inner(crop_name), nil ]
      rescue AgrrService::AgrrError => e
        @logger.error "❌ [AI Crop] Error: #{e.message}"
        @logger.error "   Backtrace: #{e.backtrace&.first(3)&.join("\n   ")}"
        msg = @translator.t("api.errors.crops.fetch_failed_with_reason", message: e.message)
        [ nil, { message: msg, status: :internal_server_error } ]
      end

      private

      def fetch_crop_info_inner(crop_name, max_retries: DEFAULT_MAX_RETRIES)
        attempt = 0
        last_error = nil

        max_retries.times do |retry_count|
          attempt = retry_count + 1

          begin
            @logger.debug "🔧 [AGRR Crop Query] crop --query #{crop_name} --json (attempt #{attempt}/#{max_retries})"

            stdout = @agrr_service.crop(query: crop_name, json: true)

            @logger.debug "📥 [AGRR Crop Output] #{stdout[0..500]}#{'...' if stdout.length > 500}"

            parsed_data = JSON.parse(stdout)

            if parsed_data["success"] == false
              @logger.error "📊 [AGRR Crop Error] #{parsed_data['error']} (code: #{parsed_data['code']})"
            else
              crop_data = parsed_data["crop"]
              stage_requirements = parsed_data["stage_requirements"]
              @logger.debug "📊 [AGRR Crop Data] crop_id: #{crop_data&.dig('crop_id')}"
              @logger.debug "📊 [AGRR Crop Data] name: #{crop_data&.dig('name')}"
              @logger.debug "📊 [AGRR Crop Data] area_per_unit: #{crop_data&.dig('area_per_unit')}"
              @logger.debug "📊 [AGRR Crop Data] revenue_per_area: #{crop_data&.dig('revenue_per_area')}"
              @logger.debug "📊 [AGRR Crop Data] stages_count: #{stage_requirements&.count || 0}"

              @logger.info "✅ [AGRR Crop Query] Succeeded after #{attempt} attempts" if attempt > 1
            end

            return parsed_data

          rescue AgrrService::DaemonNotRunningError => e
            @logger.error "❌ [AGRR Crop Query] Daemon not running: #{e.message}"
            raise AgrrService::DaemonNotRunningError, "AGRR daemon is not running: #{e.message}"
          rescue AgrrService::CommandExecutionError => e
            error_msg = e.message

            if error_msg.include?("decompressing") ||
               error_msg.include?("Connection") ||
               error_msg.include?("timeout") ||
               error_msg.include?("Network")

              @logger.warn "⚠️  [AGRR Crop Query] Transient error (attempt #{attempt}/#{max_retries}): #{error_msg}"

              if attempt < max_retries
                sleep_time = 2 ** attempt
                @logger.info "⏳ [AGRR Crop Query] Retrying in #{sleep_time} seconds..."
                sleep(sleep_time)
                next
              end
            end

            @logger.error "❌ [AGRR Crop Query Error] Command failed: #{error_msg}"
            raise AgrrService::CommandExecutionError, "Failed to query crop info from agrr: #{error_msg}"
          rescue JSON::ParserError => e
            @logger.error "❌ [AGRR Crop Query] JSON parse error: #{e.message}"
            raise AgrrService::CommandExecutionError, "Invalid JSON response from agrr: #{e.message}"

          rescue SystemCallError, IOError, SocketError, Timeout::Error => e
            last_error = e
            @logger.warn "⚠️  [AGRR Crop Query] Unexpected error (attempt #{attempt}/#{max_retries}): #{e.message}"

            if attempt < max_retries
              sleep_time = 2 ** attempt
              @logger.info "⏳ [AGRR Crop Query] Retrying in #{sleep_time} seconds..."
              sleep(sleep_time)
              next
            end

            raise AgrrService::CommandExecutionError, e.message
          end
        end

        if last_error
          raise AgrrService::CommandExecutionError, last_error.message
        else
          raise AgrrService::CommandExecutionError, "Failed to query crop info after #{max_retries} attempts"
        end
      end
    end
  end
end
