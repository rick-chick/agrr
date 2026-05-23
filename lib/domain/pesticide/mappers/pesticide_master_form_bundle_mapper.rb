# frozen_string_literal: true

module Domain
  module Pesticide
    module Mappers
      class PesticideMasterFormBundleMapper
        # @param pesticide_master_form_snapshot [Domain::Pesticide::Dtos::PesticideMasterFormSnapshot]
        # @param crop_pick_rows [Array<Domain::Pesticide::Dtos::PesticideMasterFormCropPickRow>]
        # @param pest_pick_rows [Array<Domain::Pesticide::Dtos::PesticideMasterFormPestPickRow>]
        # @return [Domain::Pesticide::Dtos::PesticideMasterFormBundle]
        def self.from_parts(pesticide_master_form_snapshot:, crop_pick_rows:, pest_pick_rows:)
          Domain::Pesticide::Dtos::PesticideMasterFormBundle.new(
            pesticide_master_form_snapshot: pesticide_master_form_snapshot,
            crop_pick_rows: crop_pick_rows,
            pest_pick_rows: pest_pick_rows
          )
        end
      end
    end
  end
end
