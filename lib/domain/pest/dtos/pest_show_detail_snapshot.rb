# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      class PestShowDetailCropSnapshot
        attr_reader :id, :user_id, :name, :variety, :is_reference, :area_per_unit,
                    :revenue_per_area, :region, :created_at, :updated_at

        def initialize(id:, user_id:, name:, variety:, is_reference:, area_per_unit:,
                       revenue_per_area:, region:, created_at:, updated_at:)
          @id = id
          @user_id = user_id
          @name = name
          @variety = variety
          @is_reference = is_reference
          @area_per_unit = area_per_unit
          @revenue_per_area = revenue_per_area
          @region = region
          @created_at = created_at
          @updated_at = updated_at
          freeze
        end
      end

      class PestShowDetailControlMethodSnapshot
        attr_reader :id, :method_type, :method_name, :description, :timing_hint

        def initialize(id:, method_type:, method_name:, description:, timing_hint:)
          @id = id
          @method_type = method_type
          @method_name = method_name
          @description = description
          @timing_hint = timing_hint
          freeze
        end
      end

      class PestShowDetailPestSnapshot
        attr_reader :id, :user_id, :name, :name_scientific, :family, :order,
                    :description, :occurrence_season, :region, :is_reference,
                    :created_at, :updated_at

        def initialize(id:, user_id:, name:, name_scientific:, family:, order:,
                       description:, occurrence_season:, region:, is_reference:,
                       created_at:, updated_at:)
          @id = id
          @user_id = user_id
          @name = name
          @name_scientific = name_scientific
          @family = family
          @order = order
          @description = description
          @occurrence_season = occurrence_season
          @region = region
          @is_reference = is_reference
          @created_at = created_at
          @updated_at = updated_at
          freeze
        end
      end

      class PestShowDetailSnapshot
        attr_reader :pest, :temperature_profile, :thermal_requirement, :control_methods, :crops

        def initialize(pest:, temperature_profile:, thermal_requirement:, control_methods:, crops:)
          @pest = pest
          @temperature_profile = temperature_profile
          @thermal_requirement = thermal_requirement
          @control_methods = control_methods
          @crops = crops
          freeze
        end
      end
    end
  end
end
