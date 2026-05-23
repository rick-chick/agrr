# frozen_string_literal: true

module Domain
  module Pesticide
    module Dtos
      # 農薬マスタフォーム用（スナップショット + プルダウン行）。Interactor が gateway 読み取りを組み立てる。
      class PesticideMasterFormBundle
        attr_reader :pesticide_master_form_snapshot, :crop_pick_rows, :pest_pick_rows

        # @param pesticide_master_form_snapshot [Domain::Pesticide::Dtos::PesticideMasterFormSnapshot]
        # @param crop_pick_rows [Array<Domain::Pesticide::Dtos::PesticideMasterFormCropPickRow>]
        # @param pest_pick_rows [Array<Domain::Pesticide::Dtos::PesticideMasterFormPestPickRow>]
        def initialize(pesticide_master_form_snapshot:, crop_pick_rows:, pest_pick_rows:)
          @pesticide_master_form_snapshot = pesticide_master_form_snapshot
          @crop_pick_rows = crop_pick_rows
          @pest_pick_rows = pest_pick_rows
        end
      end
    end
  end
end
