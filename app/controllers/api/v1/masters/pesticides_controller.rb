# frozen_string_literal: true

module Api
  module V1
    module Masters
      class PesticidesController < BaseController
        include ApiCrudResponder
        before_action :set_pesticide, only: [:show, :update, :destroy]

        # GET /api/v1/masters/pesticides
        def index
          # HTML側と同様、Policyのvisible_scopeを利用
          @pesticides = PesticidePolicy.visible_scope(current_user)
          respond_to_index(@pesticides)
        end

        # GET /api/v1/masters/pesticides/:id
        def show
          respond_to_show(@pesticide)
        end

        # POST /api/v1/masters/pesticides
        def create
          # HTML側と同様のownershipルールをPolicyに委譲（APIではis_referenceパラメータは許可していない）
          @pesticide = PesticidePolicy.build_for_create(current_user, pesticide_params)
          @pesticide.save
          respond_to_create(@pesticide)
        end

        # PATCH/PUT /api/v1/masters/pesticides/:id
        def update
          # HTML側と同様に、更新時のownership/参照フラグ調整はPolicyに委譲
          update_result = PesticidePolicy.apply_update!(current_user, @pesticide, pesticide_params)
          respond_to_update(@pesticide, update_result: update_result)
        end

        # DELETE /api/v1/masters/pesticides/:id
        def destroy
          destroy_result = @pesticide.destroy
          respond_to_destroy(@pesticide, destroy_result: destroy_result)
        end

        private

        def set_pesticide
          @pesticide = PesticidePolicy.find_editable!(current_user, params[:id])
        rescue PolicyPermissionDenied
          render json: { error: I18n.t('pesticides.flash.no_permission') }, status: :forbidden
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Pesticide not found' }, status: :not_found
        end

        def pesticide_params
          params.require(:pesticide).permit(:name, :active_ingredient, :description, :crop_id, :pest_id, :region)
        end
      end
    end
  end
end
