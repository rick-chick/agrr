# frozen_string_literal: true

module Api
  module V1
    module Masters
      class FieldsController < BaseController
        before_action :set_field, only: [:show, :update, :destroy]

        # GET /api/v1/masters/farms/:farm_id/fields
        def index
          farm =
            begin
              FarmPolicy.find_owned!(current_user, params[:farm_id])
            rescue PolicyPermissionDenied, ActiveRecord::RecordNotFound
              nil
            end

          unless farm
            render json: { error: 'Farm not found' }, status: :not_found
            return
          end

          @fields = FieldPolicy.scope_for_farm(current_user, farm)
          render json: @fields
        end

        # GET /api/v1/masters/fields/:id
        def show
          render json: @field
        end

        # POST /api/v1/masters/farms/:farm_id/fields
        def create
          farm =
            begin
              FarmPolicy.find_owned!(current_user, params[:farm_id])
            rescue PolicyPermissionDenied, ActiveRecord::RecordNotFound
              nil
            end

          unless farm
            render json: { error: 'Farm not found' }, status: :not_found
            return
          end

          @field = FieldPolicy.build_for_create(current_user, farm, field_params)

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
            farm =
              begin
                FarmPolicy.find_owned!(current_user, params[:farm_id])
              rescue PolicyPermissionDenied, ActiveRecord::RecordNotFound
                nil
              end

            unless farm
              render json: { error: 'Field not found' }, status: :not_found
              return
            end

            @field =
              begin
                FieldPolicy.scope_for_farm(current_user, farm).find(params[:id])
              rescue ActiveRecord::RecordNotFound, PolicyPermissionDenied
                nil
              end
          else
            @field =
              begin
                FieldPolicy.find_owned!(current_user, params[:id])
              rescue PolicyPermissionDenied, ActiveRecord::RecordNotFound
                nil
              end
          end

          unless @field
            render json: { error: 'Field not found' }, status: :not_found
          end
        end

        def field_params
          params.require(:field).permit(:name, :area, :daily_fixed_cost, :region)
        end
      end
    end
  end
end
