# frozen_string_literal: true

require "forwardable"

module Domain
  module Pest
    module Dtos
      class PestDetailOutput
        extend Forwardable

        def_delegators :pest, :id, :user_id, :name, :name_scientific, :family, :order, :description,
                       :occurrence_season, :region, :is_reference, :created_at, :updated_at

        attr_reader :pest, :temperature_profile, :thermal_requirement, :control_methods, :associated_crops,
                    :html_display

        def initialize(pest:, temperature_profile:, thermal_requirement:, control_methods:, associated_crops:,
                       html_display: nil)
          @pest = pest
          @temperature_profile = temperature_profile
          @thermal_requirement = thermal_requirement
          @control_methods = control_methods
          @associated_crops = associated_crops
          @html_display = html_display
        end

        alias_method :pest_temperature_profile, :temperature_profile
        alias_method :pest_thermal_requirement, :thermal_requirement
        alias_method :pest_control_methods, :control_methods
      end
    end
  end
end
