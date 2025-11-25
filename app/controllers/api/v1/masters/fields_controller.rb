# frozen_string_literal: true

module Api
  module V1
    module Masters
      class FieldsController < BaseController
        before_action :set_field, only: [:show, :update, :destroy]

        # GET /api/v1/masters/farms/:farm_id/fields
        def index
          farm = current_user.farms.where(is_reference: false).find(params[:farm_id])
          @fields = farm.fields
          render json: @fields
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Farm not found' }, status: :not_found
        end

        # GET /api/v1/masters/fields/:id
        def show
          render json: @field
        end

        # POST /api/v1/masters/farms/:farm_id/fields
        def create
          farm = current_user.farms.where(is_reference: false).find(params[:farm_id])
          @field = farm.fields.build(field_params)
          @field.user = current_user

          if @field.save
            render json: @field, status: :created
          else
            render json: { errors: @field.errors.full_messages }, status: :unprocessable_entity
          end
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Farm not found' }, status: :not_found
        end

        # PATCH/PUT /api/v1/masters/fields/:id
        def update
          if @field.update(field_params)
            render json: @field
          else
            render json: { errors: @field.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/masters/fields/:id
        def destroy
          if @field.destroy
            head :no_content
          else
            render json: { errors: @field.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def set_field
          # ユーザーが所有する農場の圃場のみアクセス可能
          if params[:farm_id].present?
            # ネストされたルートの場合
            farm = current_user.farms.where(is_reference: false).find(params[:farm_id])
            @field = farm.fields.find(params[:id])
          else
            # 直接アクセスの場合
            farm = current_user.farms.where(is_reference: false).joins(:fields).where(fields: { id: params[:id] }).first
            unless farm
              render json: { error: 'Field not found' }, status: :not_found
              return
            end
            @field = farm.fields.find(params[:id])
          end
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Field not found' }, status: :not_found
        end

        def field_params
          params.require(:field).permit(:name, :area, :daily_fixed_cost, :region)
        end
      end
    end
  end
end
