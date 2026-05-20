# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class MastersCropTaskTemplateCreateOutput
        attr_reader :template, :failure

        def initialize(template: nil, failure: nil)
          @template = template
          @failure = failure
        end

        def success?
          !@template.nil?
        end

        def failure?
          !@failure.nil?
        end
      end
    end
  end
end
