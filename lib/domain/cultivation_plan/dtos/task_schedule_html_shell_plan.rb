# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # HTML 作業予定ページのヘッダー・パス生成用（AR をビューに渡さない）
      class TaskScheduleHtmlShellPlan
        attr_reader :id, :display_name, :total_area, :farm

        def initialize(id:, display_name:, total_area:, farm_display_name:)
          @id = id
          @display_name = display_name
          @total_area = total_area
          @farm = FarmShell.new(display_name: farm_display_name)
        end

        class FarmShell
          attr_reader :display_name

          def initialize(display_name:)
            @display_name = display_name
          end
        end
      end
    end
  end
end
