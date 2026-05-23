# frozen_string_literal: true

module Domain
  module InteractionRule
    module Dtos
      class InteractionRuleDetailOutput
        attr_reader :rule, :html_display

        def initialize(rule:, html_display: nil)
          @rule = rule
          @html_display = html_display
        end
      end
    end
  end
end
