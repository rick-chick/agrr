# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      FieldCultivationApiSummarySnapshot = Data.define(
        :id,
        :field_name,
        :crop_name,
        :area,
        :start_date,
        :completion_date,
        :cultivation_days,
        :estimated_cost,
        :gdd,
        :status
      )
    end
  end
end
