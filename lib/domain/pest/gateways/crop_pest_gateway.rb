# frozen_string_literal: true

module Domain
  module Pest
    module Gateways
      class CropPestGateway
        # @return [Domain::Pest::Entities::CropPestLinkEntity, nil]
        def find_by_crop_id_and_pest_id(crop_id:, pest_id:)
          raise NotImplementedError, "Subclasses must implement find_by_crop_id_and_pest_id"
        end

        # @return [Array<Integer>] crop ids linked to the pest
        def list_by_pest_id(pest_id:)
          raise NotImplementedError, "Subclasses must implement list_by_pest_id"
        end

        # @return [Domain::Pest::Entities::CropPestLinkEntity]
        def create(crop_id:, pest_id:)
          raise NotImplementedError, "Subclasses must implement create"
        end

        # @return [Boolean] true when a row was deleted
        def delete(crop_id:, pest_id:)
          raise NotImplementedError, "Subclasses must implement delete"
        end
      end
    end
  end
end
