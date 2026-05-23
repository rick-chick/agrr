# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      class MastersCropPestsCreateInput
        attr_reader :crop_id, :pest_id_raw

        def initialize(crop_id:, pest_id_raw:)
          @crop_id = crop_id
          @pest_id_raw = pest_id_raw
        end
      end
    end
  end
end
