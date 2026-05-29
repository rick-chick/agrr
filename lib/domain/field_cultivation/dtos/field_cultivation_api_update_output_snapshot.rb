# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      FieldCultivationApiUpdateOutputSnapshot = Data.define(
        :field_cultivation_id,
        :start_date,
        :completion_date,
        :cultivation_days
      )
    end
  end
end
