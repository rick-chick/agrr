# frozen_string_literal: true

module Api
  module V1
    module Masters
      module Crops
        # 作物と害虫の関連管理API
        class PestsController < BaseController
          before_action :set_crop

          def index
            presenter = Presenters::Api::Pest::MastersCropPestsIndexPresenter.new(view: self)
            Domain::Pest::Interactors::MastersCropPestsIndexInteractor.new(output_port: presenter,
              user_id: current_user.id, user_lookup: CompositionRoot.user_lookup, pest_gateway: CompositionRoot.pest_gateway).call(crop_id: @crop.id)
          end

          def create
            presenter = Presenters::Api::Pest::MastersCropPestsCreatePresenter.new(view: self)
            Domain::Pest::Interactors::MastersCropPestsCreateInteractor.new(output_port: presenter,
              user_id: current_user.id, user_lookup: CompositionRoot.user_lookup, pest_gateway: CompositionRoot.pest_gateway).call(@crop.id, params[:pest_id])
          end

          def destroy
            presenter = Presenters::Api::Pest::MastersCropPestsDestroyPresenter.new(view: self)
            Domain::Pest::Interactors::MastersCropPestsDestroyInteractor.new(
              output_port: presenter,
              user_id: current_user.id,
              user_lookup: CompositionRoot.user_lookup,
              pest_gateway: CompositionRoot.pest_gateway
            ).call(crop_id: @crop.id, pest_id: params[:id])
          end

          private

          def set_crop
            presenter = Presenters::Api::Crop::MastersNestedCropContextPresenter.new(view: self)
            Domain::Crop::Interactors::CropLoadUserNonReferenceForMastersInteractor.new(output_port: presenter,
              user_id: current_user.id, gateway: CompositionRoot.crop_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:crop_id])
          end
        end
      end
    end
  end
end
