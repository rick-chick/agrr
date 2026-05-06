# frozen_string_literal: true

module Domain
  module Backdoor
    module Dtos
      class BackdoorClearDatabaseSuccessDto
        attr_reader :before_stats, :after_stats

        def initialize(before_stats:, after_stats:)
          @before_stats = before_stats
          @after_stats = after_stats
        end
      end
    end
  end
end
