# frozen_string_literal: true

module Api
  module V1
    module Masters
      class PesticidesController < BaseController
        before_action :set_pesticide, only: [:show, :update, :destroy]

        # GET /api/v1/masters/pesticides
        def index
          # HTML側と同様、Policyのvisible_scopeを利用
          @pesticides = PesticidePolicy.visible_scope(current_user)
          render json: @pesticides
        end

        # GET /api/v1/masters/pesticides/:id
        def show
          render json: @pesticide
        end

        # POST /api/v1/masters/pesticides
        def create
          # HTML側と同様のownershipルールをPolicyに委譲（APIではis_referenceパラメータは許可していない）
          @pesticide = PesticidePolicy.build_for_create(current_user, pesticide_params)

          if @pesticide.save
            render json: @pesticide, status: :created
          else
            render json: { errors: @pesticide.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PATCH/PUT /api/v1/masters/pesticides/:id
        def update
          # HTML側と同様に、更新時のownership/参照フラグ調整はPolicyに委譲
          if PesticidePolicy.apply_update!(current_user, @pesticide, pesticide_params)
            render json: @pesticide
          else
            render json: { errors: @pesticide.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/masters/pesticides/:id
        def destroy
          if @pesticide.destroy
            head :no_content
          else
            render json: { errors: @pesticide.errors.full_messages }, status: :unprocessable_entity
          end
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
