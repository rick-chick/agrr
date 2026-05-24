# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class SaveAdjustedAgrrPersistBundle
        attr_reader :upserts,
                    :creates,
                    :delete_field_cultivation_ids,
                    :used_crop_ids,
                    :plan_summary

        def initialize(
          upserts:,
          creates:,
          delete_field_cultivation_ids:,
          used_crop_ids:,
          plan_summary:
        )
          @upserts = Array(upserts).freeze
          @creates = Array(creates).freeze
          @delete_field_cultivation_ids = Array(delete_field_cultivation_ids).freeze
          @used_crop_ids = Array(used_crop_ids).freeze
          @plan_summary = plan_summary
          freeze
        end
      end
    end
  end
end
