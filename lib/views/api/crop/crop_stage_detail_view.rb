# frozen_string_literal: true

module Views
  module Api
    module Crop
      module CropStageDetailView
        def render_response(json:, status:)
          raise NotImplementedError, "#{self.class}#render_response"
        end
      end
    end
  end
end