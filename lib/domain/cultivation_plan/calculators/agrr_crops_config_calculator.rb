# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Calculators
      class AgrrCropsConfigCalculator
        # @param entries [Array<Hash>] :crop_id, :crop_name, :has_growth_stages, :requirement
        # @param logger [#warn, nil]
        # @return [Array<Hash>]
        def self.build(entries:, logger:)
          Array(entries).filter_map do |entry|
            crop_id = entry.fetch(:crop_id).to_s
            crop_name = entry.fetch(:crop_name)
            has_growth_stages = entry.fetch(:has_growth_stages)

            unless has_growth_stages
              logger&.warn("⚠️ [AGRR] Skipping crop '#{crop_name}' (id=#{crop_id}): no growth stages")
              next
            end

            crop_data = (entry[:requirement] || {}).dup
            crop_data["crop"] = crop_data["crop"].dup if crop_data["crop"].is_a?(Hash)
            crop_data["crop"] ||= {}
            crop_data["crop"]["crop_id"] = crop_id
            crop_data
          end
        end
      end
    end
  end
end
