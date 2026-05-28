# frozen_string_literal: true

module Api
  module V1
    module Masters
      module Crops
        class PesticidesController < BaseController
          def index
            presenter = Adapters::Pesticide::Presenters::MastersCropPesticidesIndexApiPresenter.new(view: self)
            Domain::Pesticide::Interactors::MastersCropPesticidesIndexInteractor.new(
              output_port: presenter,
              user_id: current_user.id,
              user_lookup: CompositionRoot.user_lookup,
              pesticide_gateway: CompositionRoot.pesticide_gateway,
              crop_gateway: CompositionRoot.crop_gateway
            ).call(crop_id: params[:crop_id])
          end
        end
      end
    end
  end
end
