# frozen_string_literal: true

module Domain
  module PublicPlan
    module Mappers
      class PublicPlanWizardPlanIdMapper
        def self.normalize(*candidates)
          candidates.each do |raw|
            next if raw.blank?

            i = Integer(raw, exception: false)
            return i if i&.positive?
          end
          nil
        end
      end
    end
  end
end
