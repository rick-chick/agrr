# frozen_string_literal: true

module Domain
  module InteractionRule
    module Dtos
      class InteractionRuleListInputDto
        attr_reader :user_id, :include_reference

        def initialize(user_id:, include_reference: false)
          @user_id = user_id
          @include_reference = include_reference
        end
      end
    end
  end
end