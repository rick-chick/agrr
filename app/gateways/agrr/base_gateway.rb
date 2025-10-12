# frozen_string_literal: true

module Agrr
  class BaseGateway
    class ExecutionError < StandardError; end
    class ParseError < StandardError; end
    
    private
    
    def execute_command(*args)
      Rails.logger.debug "🔧 [AGRR] Executing: #{args.join(' ')}"
      
      stdout, stderr, status = Open3.capture3(*args)
      
      unless status.success?
        Rails.logger.error "❌ [AGRR] Command failed: #{stderr}"
        raise ExecutionError, stderr
      end
      
      JSON.parse(stdout)
    rescue JSON::ParserError => e
      Rails.logger.error "❌ [AGRR] Failed to parse JSON: #{e.message}"
      raise ParseError, "Failed to parse JSON: #{e.message}"
    end
    
    def agrr_path
      @agrr_path ||= Rails.root.join('lib/core/agrr').to_s
    end
    
    def write_temp_file(data, prefix: 'agrr_data')
      file = Tempfile.new([prefix, '.json'])
      file.write(data.to_json)
      file.flush
      file
    end
  end
end

