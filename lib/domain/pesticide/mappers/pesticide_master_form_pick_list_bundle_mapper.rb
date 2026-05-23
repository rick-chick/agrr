# frozen_string_literal: true

module Domain
  module Pesticide
    module Mappers
      class PesticideMasterFormPickListBundleMapper
        # @param crop_pick_rows [Array<Domain::Pesticide::Dtos::PesticideMasterFormCropPickRow>]
        # @param pest_pick_rows [Array<Domain::Pesticide::Dtos::PesticideMasterFormPestPickRow>]
        # @return [Domain::Pesticide::Dtos::PesticideMasterFormPickListBundle]
        def self.from_pick_rows(crop_pick_rows:, pest_pick_rows:)
          Domain::Pesticide::Dtos::PesticideMasterFormPickListBundle.new(
            crop_pick_rows: crop_pick_rows,
            pest_pick_rows: pest_pick_rows
          )
        end
      end
    end
  end
end
