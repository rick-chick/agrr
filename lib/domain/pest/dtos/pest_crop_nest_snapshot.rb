# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      # 作物にネストした害虫の読み取りスナップショット（関連・検証メッセージをプレーン構造で保持する）。
      class PestCropNestSnapshot
        attr_reader :id,
                    :user_id,
                    :name,
                    :name_scientific,
                    :family,
                    :order,
                    :description,
                    :occurrence_season,
                    :region,
                    :is_reference,
                    :created_at,
                    :updated_at,
                    :temperature_profile_row,
                    :thermal_requirement_row,
                    :control_method_rows,
                    :error_messages_by_attribute

        # @param temperature_profile_row [Hash, nil] id / base_temperature / max_temperature
        # @param thermal_requirement_row [Hash, nil] id / required_gdd / first_generation_gdd
        # @param control_method_rows [Array<Hash>]
        # @param error_messages_by_attribute [Hash] 属性 => メッセージ配列（検証結果の再生用）
        def initialize(
          id:,
          user_id:,
          name:,
          name_scientific:,
          family:,
          order:,
          description:,
          occurrence_season:,
          region:,
          is_reference:,
          created_at:,
          updated_at:,
          temperature_profile_row: nil,
          thermal_requirement_row: nil,
          control_method_rows: nil,
          error_messages_by_attribute: nil
        )
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
          @temperature_profile_row = temperature_profile_row.freeze if temperature_profile_row
          @thermal_requirement_row = thermal_requirement_row.freeze if thermal_requirement_row
          @control_method_rows = (control_method_rows || []).freeze
          @error_messages_by_attribute = (error_messages_by_attribute || {}).freeze
          freeze
        end

        def self.blank_for_nested_new(user_id: nil)
          new(
            id: nil,
            user_id: user_id,
            name: nil,
            name_scientific: nil,
            family: nil,
            order: nil,
            description: nil,
            occurrence_season: nil,
            region: nil,
            is_reference: false,
            created_at: nil,
            updated_at: nil,
            temperature_profile_row: {
              id: nil,
              base_temperature: nil,
              max_temperature: nil
            },
            thermal_requirement_row: {
              id: nil,
              required_gdd: nil,
              first_generation_gdd: nil
            },
            control_method_rows: [
              {
                id: nil,
                method_type: nil,
                method_name: nil,
                description: nil,
                timing_hint: nil
              }
            ],
            error_messages_by_attribute: {}
          )
        end
      end
    end
  end
end
