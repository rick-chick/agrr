# frozen_string_literal: true

module Api
  module V1
    module Masters
      class FieldsController < BaseController
        include ApiCrudResponder
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
          respond_to_index(@fields)
        end

        # GET /api/v1/masters/fields/:id
        def show
          respond_to_show(@field)
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
          @field.save
          respond_to_create(@field)
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Farm not found' }, status: :not_found
        end

        # PATCH/PUT /api/v1/masters/fields/:id
        def update
          update_result = @field.update(field_params)
          respond_to_update(@field, update_result: update_result)
        end

        # DELETE /api/v1/masters/fields/:id
        def destroy
          destroy_result = @field.destroy
          respond_to_destroy(@field, destroy_result: destroy_result)
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
