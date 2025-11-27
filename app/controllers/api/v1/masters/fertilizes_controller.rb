# frozen_string_literal: true

module Api
  module V1
    module Masters
      class FertilizesController < BaseController
        include ApiCrudResponder
        before_action :set_fertilize, only: [:show, :update, :destroy]

        # GET /api/v1/masters/fertilizes
        def index
          # HTML側と同様、Policyのvisible_scopeを利用
          @fertilizes = FertilizePolicy.visible_scope(current_user)
          respond_to_index(@fertilizes)
        end

        # GET /api/v1/masters/fertilizes/:id
        def show
          respond_to_show(@fertilize)
        end

        # POST /api/v1/masters/fertilizes
        def create
          # HTML側と同様のownershipルールをPolicyに委譲（APIではis_referenceパラメータは許可していない）
          @fertilize = FertilizePolicy.build_for_create(current_user, fertilize_params)
          @fertilize.save
          respond_to_create(@fertilize)
        end

        # PATCH/PUT /api/v1/masters/fertilizes/:id
        def update
          # HTML側と同様に、更新時のownership/参照フラグ調整はPolicyに委譲
          update_result = FertilizePolicy.apply_update!(current_user, @fertilize, fertilize_params)
          respond_to_update(@fertilize, update_result: update_result)
        end

        # DELETE /api/v1/masters/fertilizes/:id
        def destroy
          destroy_result = @fertilize.destroy
          respond_to_destroy(@fertilize, destroy_result: destroy_result)
        end

        private

        def set_fertilize
          @fertilize = FertilizePolicy.find_editable!(current_user, params[:id])
        rescue PolicyPermissionDenied
          render json: { error: I18n.t('fertilizes.flash.no_permission') }, status: :forbidden
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Fertilize not found' }, status: :not_found
        end

        def fertilize_params
          params.require(:fertilize).permit(:name, :n, :p, :k, :description, :package_size, :region)
        end
      end
    end
  end
end
