# frozen_string_literal: true

module Adapters
  module Backdoor
    # バックドアの死活監視などでバッククォート実行する。SystemCallError は境界で潰し nil を返す。
    class ShellStdoutCaptureGateway
      def initialize(logger:)
        @logger = logger
      end

      # @return [String, nil] 標準出力全体（strip 済み）。失敗時は nil。
      def capture(command)
        `#{command}`.strip
      rescue SystemCallError => e
        @logger.error "Backdoor shell capture failed: #{e.message}"
        nil
      end
    end
  end
end
