# frozen_string_literal: true

module Api
  module V1
    module Masters
      class InteractionRulesController < BaseController
        include ApiCrudResponder
        before_action :set_interaction_rule, only: [:show, :update, :destroy]

        # GET /api/v1/masters/interaction_rules
        def index
          # HTML側と同様、Policyのvisible_scopeを利用
          @interaction_rules = InteractionRulePolicy.visible_scope(current_user)
          respond_to_index(@interaction_rules)
        end

        # GET /api/v1/masters/interaction_rules/:id
        def show
          respond_to_show(@interaction_rule)
        end

        # POST /api/v1/masters/interaction_rules
        def create
          # HTML側と同様のownershipルールをPolicyに委譲（APIではis_referenceパラメータは許可していない）
          @interaction_rule, = InteractionRulePolicy.build_for_create(current_user, interaction_rule_params.to_h)
          @interaction_rule.save
          respond_to_create(@interaction_rule)
        end

        # PATCH/PUT /api/v1/masters/interaction_rules/:id
        def update
          # HTML側と同様に、更新時のownership/参照フラグ調整はPolicyに委譲
          update_result = InteractionRulePolicy.apply_update!(current_user, @interaction_rule, interaction_rule_params.to_h)
          respond_to_update(@interaction_rule, update_result: update_result)
        end

        # DELETE /api/v1/masters/interaction_rules/:id
        def destroy
          destroy_result = @interaction_rule.destroy
          respond_to_destroy(@interaction_rule, destroy_result: destroy_result)
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
