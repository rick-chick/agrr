# frozen_string_literal: true

module Api
  module V1
    module Masters
      class InteractionRulesController < BaseController
        before_action :set_interaction_rule, only: [:show, :update, :destroy]

        # GET /api/v1/masters/interaction_rules
        def index
          @interaction_rules = current_user.interaction_rules.where(is_reference: false)
          render json: @interaction_rules
        end

        # GET /api/v1/masters/interaction_rules/:id
        def show
          render json: @interaction_rule
        end

        # POST /api/v1/masters/interaction_rules
        def create
          @interaction_rule = current_user.interaction_rules.build(interaction_rule_params)
          @interaction_rule.is_reference = false

          if @interaction_rule.save
            render json: @interaction_rule, status: :created
          else
            render json: { errors: @interaction_rule.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PATCH/PUT /api/v1/masters/interaction_rules/:id
        def update
          if @interaction_rule.update(interaction_rule_params)
            render json: @interaction_rule
          else
            render json: { errors: @interaction_rule.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/masters/interaction_rules/:id
        def destroy
          if @interaction_rule.destroy
            head :no_content
          else
            render json: { errors: @interaction_rule.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def set_interaction_rule
          @interaction_rule = current_user.interaction_rules.where(is_reference: false).find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'InteractionRule not found' }, status: :not_found
        end

        def interaction_rule_params
          params.require(:interaction_rule).permit(:rule_type, :source_group, :target_group, :impact_ratio, :is_directional, :description, :region)
        end
      end
    end
  end
end
