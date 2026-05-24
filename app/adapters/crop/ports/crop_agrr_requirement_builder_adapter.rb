# frozen_string_literal: true

module Adapters
  module Crop
    module Ports
      class CropAgrrRequirementBuilderAdapter
        include Domain::Shared::Ports::CropAgrrRequirementBuilderPort

        def build_from(crop_source)
          Adapters::Crop::Mappers::CropAgrrRequirementMapper.build_from(crop_source)
        end
      end
    end
  end
end
