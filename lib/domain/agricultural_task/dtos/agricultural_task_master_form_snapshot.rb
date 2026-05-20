# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Dtos
      # 農作業マスタ HTML フォーム用スナップショット（永続モデルをユースケース境界に載せない）。
      # 各属性は本クラスの `attr_reader` のとおり。
      #
      # @see Forms::AgriculturalTaskMasterForm
      class AgriculturalTaskMasterFormSnapshot
        attr_reader :id, :user_id, :name, :description, :time_per_sqm, :weather_dependency,
                    :required_tools, :skill_level, :region, :task_type, :is_reference, :error_messages

        # @param id [Integer, nil]
        # @param user_id [Integer, nil]
        # @param name [String]
        # @param description [String, nil]
        # @param time_per_sqm [Numeric, nil]
        # @param weather_dependency [String, nil]
        # @param required_tools [Array<String>, #to_a]
        # @param skill_level [String, nil]
        # @param region [String, nil]
        # @param task_type [String, nil]
        # @param is_reference [Boolean]
        # @param new_record [Boolean]
        # @param error_messages [Array<String>]
        def initialize(id:, user_id:, name:, description:, time_per_sqm:, weather_dependency:,
                       required_tools:, skill_level:, region:, task_type:, is_reference:, new_record:, error_messages: [])
          @id = id
          @user_id = user_id
          @name = name
          @description = description
          @time_per_sqm = time_per_sqm
          @weather_dependency = weather_dependency
          @required_tools = Array(required_tools)
          @skill_level = skill_level
          @region = region
          @task_type = task_type
          @is_reference = is_reference
          @new_record = new_record
          @error_messages = Array(error_messages)
        end

        # @return [Boolean]
        def new_record?
          @new_record
        end
      end
    end
  end
end
