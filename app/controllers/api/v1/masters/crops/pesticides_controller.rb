# frozen_string_literal: true

module Api
  module V1
    module Masters
      module Crops
        class PesticidesController < BaseController
          before_action :set_crop

          def index
            presenter = Presenters::Api::Pesticide::MastersCropPesticidesIndexPresenter.new(view: self)
            Domain::Pesticide::Interactors::MastersCropPesticidesIndexInteractor.new(output_port: presenter,
              user_id: current_user.id, user_lookup: CompositionRoot.user_lookup, pesticide_gateway: CompositionRoot.pesticide_gateway).call(@crop)
          end

          private

          def set_crop
            presenter = Presenters::Api::Crop::MastersNestedCropContextPresenter.new(
              view: self,
              not_found_message: "Crop not found"
            )
            Domain::Crop::Interactors::CropLoadUserNonReferenceForMastersInteractor.new(output_port: presenter,
              user_id: current_user.id, gateway: CompositionRoot.crop_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:crop_id])
          end
        end
      end
    end
  end
end
