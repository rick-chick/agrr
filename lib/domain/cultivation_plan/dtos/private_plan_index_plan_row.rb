# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # プライベート計画一覧の 1 カード分。ActiveRecord は含めない。
      class PrivatePlanIndexPlanRow
        attr_reader :id, :farm_display_name, :total_area, :crops_count, :fields_count,
                    :status, :display_name, :created_at

        # @param id [Integer]
        # @param farm_display_name [String]
        # @param total_area [Numeric]
        # @param crops_count [Integer]
        # @param fields_count [Integer]
        # @param status [String]
        # @param display_name [String] カード本文には出さない。削除 undo トースト等（CultivationPlan#display_name 相当の文字列）
        # @param created_at [Time]
        def initialize(id:, farm_display_name:, total_area:, crops_count:, fields_count:, status:, display_name:,
                       created_at:)
          @id = id
          @farm_display_name = farm_display_name
          @total_area = total_area
          @crops_count = crops_count
          @fields_count = fields_count
          @status = status
          @display_name = display_name
          @created_at = created_at
        end

        def completed?
          status == "completed"
        end

        def optimizing?
          status == "optimizing"
        end

        def pending?
          status == "pending"
        end

        def failed?
          status == "failed"
        end
      end
    end
  end
end
