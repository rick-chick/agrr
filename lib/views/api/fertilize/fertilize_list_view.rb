# frozen_string_literal: true

module Views
  module Api
    module Fertilize
      module FertilizeListView
        def render_response(json:, status:)
          raise NotImplementedError, "#{self.class}#render_response"
        end
      end
    end
  end
end
