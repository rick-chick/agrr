# frozen_string_literal: true

module Api
  module V1
    module Masters
      class InteractionRulesController < BaseController
        before_action :set_interaction_rule, only: [:show, :update, :destroy]

        # GET /api/v1/masters/interaction_rules
        def index
          # HTML側と同様、Policyのvisible_scopeを利用
          @interaction_rules = InteractionRulePolicy.visible_scope(current_user)
          render json: @interaction_rules
        end

        # GET /api/v1/masters/interaction_rules/:id
        def show
          render json: @interaction_rule
        end

        # POST /api/v1/masters/interaction_rules
        def create
          # HTML側と同様のownershipルールをPolicyに委譲（APIではis_referenceパラメータは許可していない）
          @interaction_rule, = InteractionRulePolicy.build_for_create(current_user, interaction_rule_params.to_h)

          if @interaction_rule.save
            render json: @interaction_rule, status: :created
          else
            render json: { errors: @interaction_rule.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PATCH/PUT /api/v1/masters/interaction_rules/:id
        def update
          # HTML側と同様に、更新時のownership/参照フラグ調整はPolicyに委譲
          if InteractionRulePolicy.apply_update!(current_user, @interaction_rule, interaction_rule_params.to_h)
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
          @interaction_rule = InteractionRulePolicy.find_editable!(current_user, params[:id])
        rescue PolicyPermissionDenied
          render json: { error: I18n.t('interaction_rules.flash.no_permission') }, status: :forbidden
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
