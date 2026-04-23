# frozen_string_literal: true

module Domain
  module Crop
    module Gateways
      class CropStageCopyGateway
        class << self
          def default
            @default ||= Adapters::Crop::Gateways::CropStageCopyActiveRecordGateway.new
          end

          attr_writer :default

          def default_reset!
            @default = nil
          end
        end

        def copy_reference_stages(reference_crop:, new_crop:)
          raise NotImplementedError, "#{self.class} must implement #copy_reference_stages"
        end
      end
    end
  end
end
