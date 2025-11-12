require 'open3'
require 'json'

module Adapters
  module Fertilize
    module Gateways
      class FertilizeCliGateway
        DEFAULT_MAX_RETRIES = 3

        def initialize(logger: Rails.logger)
          @logger = logger
        end

        def fetch_for_create(name:, max_retries: DEFAULT_MAX_RETRIES)
          fetch_from_agrr(name: name, max_retries: max_retries)
        end

        def fetch_for_update(id:, name:, max_retries: DEFAULT_MAX_RETRIES)
          fetch_from_agrr(name: name, max_retries: max_retries)
        end

        private

        def fetch_from_agrr(name:, max_retries:)
          raise ArgumentError, "name can't be blank" if name.blank?

          attempt = 0
          last_error = nil
          client_path = Rails.root.join('bin', 'agrr_client').to_s

          max_retries.times do |retry_count|
            attempt = retry_count + 1

            begin
              @logger.debug "🔧 [AGRR Fertilize Query] fertilize get --name #{name} --json (attempt #{attempt}/#{max_retries})"

              stdout, stderr, status = Open3.capture3(client_path, 'fertilize', 'get', '--name', name, '--json')

              unless status.success?
                error_msg = stderr.strip

                if error_msg.include?('FileNotFoundError') ||
                   error_msg.include?('No such file or directory') ||
                   error_msg.include?('SOCKET_PATH')
                  @logger.error "❌ [AGRR Fertilize Query] Daemon not running: #{error_msg}"
                  return {
                    'success' => false,
                    'error' => I18n.t('api.errors.fertilizes.daemon_not_running', default: 'AGRRサービスが起動していません。サービスを起動してから再度お試しください。'),
                    'code' => 'daemon_not_running'
                  }
                end

                if error_msg.include?('decompressing') ||
                   error_msg.include?('Connection') ||
                   error_msg.include?('timeout') ||
                   error_msg.include?('Network')
                  @logger.warn "⚠️  [AGRR Fertilize Query] Transient error (attempt #{attempt}/#{max_retries}): #{error_msg}"

                  if attempt < max_retries
                    sleep_time = 2**attempt
                    @logger.info "⏳ [AGRR Fertilize Query] Retrying in #{sleep_time} seconds..."
                    sleep(sleep_time)
                    next
                  end
                end

                @logger.error "❌ [AGRR Fertilize Query Error] Command failed: fertilize get --name #{name} --json"
                @logger.error "   stderr: #{error_msg}"
                raise "Failed to query fertilize info from agrr: #{error_msg}"
              end

              @logger.debug "📥 [AGRR Fertilize Output] #{stdout[0..500]}#{'...' if stdout.length > 500}"

              parsed_data = JSON.parse(stdout)

              if parsed_data['success'] == false
                @logger.error "📊 [AGRR Fertilize Error] #{parsed_data['error']} (code: #{parsed_data['code']})"
              else
                fertilize_data = parsed_data['fertilize'] || parsed_data

                if fertilize_data['npk'] && !fertilize_data['n']
                  npk_values = fertilize_data['npk'].split('-').map { |v| v.to_f }
                  fertilize_data['n'] = npk_values[0] if npk_values[0]&.positive?
                  fertilize_data['p'] = npk_values[1] if npk_values[1]&.positive?
                  fertilize_data['k'] = npk_values[2] if npk_values[2]&.positive?
                end

                @logger.debug "📊 [AGRR Fertilize Data] name: #{fertilize_data&.dig('name')}"
                @logger.debug "📊 [AGRR Fertilize Data] n: #{fertilize_data&.dig('n')}, p: #{fertilize_data&.dig('p')}, k: #{fertilize_data&.dig('k')}"
                @logger.debug "📊 [AGRR Fertilize Data] package_size: #{fertilize_data&.dig('package_size')}"

                if attempt > 1
                  @logger.info "✅ [AGRR Fertilize Query] Succeeded after #{attempt} attempts"
                end

                parsed_data = { 'fertilize' => fertilize_data, 'success' => true } unless parsed_data['fertilize']
              end

              return parsed_data
            rescue JSON::ParserError => e
              @logger.error "❌ [AGRR Fertilize Query] JSON parse error: #{e.message}"
              raise "Invalid JSON response from agrr: #{e.message}"
            rescue => e
              last_error = e
              @logger.warn "⚠️  [AGRR Fertilize Query] Unexpected error (attempt #{attempt}/#{max_retries}): #{e.message}"

              if attempt < max_retries
                sleep_time = 2**attempt
                @logger.info "⏳ [AGRR Fertilize Query] Retrying in #{sleep_time} seconds..."
                sleep(sleep_time)
                next
              end

              raise
            end
          end

          raise last_error if last_error
          raise "Failed to query fertilize info after #{max_retries} attempts"
        end
      end
    end
  end
end

