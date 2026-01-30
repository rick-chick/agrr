# frozen_string_literal: true

module Views
  module Api
    module AgriculturalTask
      module AgriculturalTaskListView
        def render_response(json:, status:)
          raise NotImplementedError, "#{self.class}#render_response"
        end
      end
    end
  end
end
