# frozen_string_literal: true

module Api
  module V1
    module Masters
      class PestsController < BaseController
        before_action :set_pest, only: [:show, :update, :destroy]

        # GET /api/v1/masters/pests
        def index
          # HTML側と同様、Policyのvisible_scopeを利用
          @pests = PestPolicy.visible_scope(current_user)
          render json: @pests
        end

        # GET /api/v1/masters/pests/:id
        def show
          render json: @pest
        end

        # POST /api/v1/masters/pests
        def create
          # HTML側と同様のownershipルールをPolicyに委譲（APIではis_referenceパラメータは許可していない）
          @pest = PestPolicy.build_for_create(current_user, pest_params)

          if @pest.save
            render json: @pest, status: :created
          else
            render json: { errors: @pest.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PATCH/PUT /api/v1/masters/pests/:id
        def update
          # HTML側と同様に、更新時のownership/参照フラグ調整はPolicyに委譲
          if PestPolicy.apply_update!(current_user, @pest, pest_params)
            render json: @pest
          else
            render json: { errors: @pest.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/masters/pests/:id
        def destroy
          if @pest.destroy
            head :no_content
          else
            render json: { errors: @pest.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def set_pest
          action = params[:action].to_sym

          @pest =
            if action.in?([:update, :destroy])
              PestPolicy.find_editable!(current_user, params[:id])
            else
              PestPolicy.find_visible!(current_user, params[:id])
            end
        rescue PolicyPermissionDenied
          render json: { error: I18n.t('pests.flash.no_permission') }, status: :forbidden
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Pest not found' }, status: :not_found
        end

        def pest_params
          params.require(:pest).permit(:name, :name_scientific, :family, :order, :description, :occurrence_season, :region)
        end
      end
    end
  end
end
