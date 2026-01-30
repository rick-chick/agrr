# frozen_string_literal: true

module Views
  module Api
    module AgriculturalTask
      module AgriculturalTaskDeleteView
        def render_response(json:, status:)
          raise NotImplementedError, "#{self.class}#render_response"
        end

        def undo_deletion_path(undo_token:)
          raise NotImplementedError, "#{self.class}#undo_deletion_path"
        end
      end
    end
  end
end
