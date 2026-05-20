# frozen_string_literal: true

module Domain
  module Backdoor
    module Interactors
      class BackdoorClearDatabaseInteractor
        def initialize(output_port:, gateway:, logger:)
          @output_port = output_port
          @gateway = gateway
          @logger = logger
        end

        def call
          r = @gateway.clear_application_data_preserving_anonymous_users
          case r.kind
          when :success
            @logger.error("✅ Database cleared successfully. Before: #{r.before_stats.to_h}, After: #{r.after_stats.to_h}")
            @output_port.on_success(
              Dtos::BackdoorClearDatabaseOutput.new(
                before_stats: r.before_stats,
                after_stats: r.after_stats
              )
            )
          when :failure
            @output_port.on_failure(Dtos::BackdoorClearDatabaseFailure.new(message: r.error_message))
          else
            raise ArgumentError, "unexpected gateway result kind: #{r.kind.inspect}"
          end
        end
      end
    end
  end
end
