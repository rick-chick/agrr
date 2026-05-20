# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      module Api
        class CropRecordPresenter
          def initialize(view:)
            @view = view
          end

          def on_success(crop)
            @view.instance_variable_set(:@crop_record, crop)
          end

          def on_failure(_error_dto)
            @view.instance_variable_set(:@crop_record, nil)
          end
        end
      end
    end
  end
end
