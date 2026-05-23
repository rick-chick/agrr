# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Mappers
      class FarmSizeI18nMapper
        def self.enrich(sizes)
          sizes.map do |size|
            size.merge(
              name: I18n.t("public_plans.farm_sizes.#{size[:id]}.name"),
              description: I18n.t("public_plans.farm_sizes.#{size[:id]}.description")
            )
          end
        end

        def self.enrich_one(size)
          return size if size.blank?

          enrich([ size ]).first
        end
      end
    end
  end
end
