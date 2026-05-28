# frozen_string_literal: true

module Api
  module V1
    module Masters
      class InteractionRulesController < BaseController

        # GET /api/v1/masters/interaction_rules
        def index
          presenter = Adapters::InteractionRule::Presenters::InteractionRuleListApiPresenter.new(view: self)
          Domain::InteractionRule::Interactors::InteractionRuleListInteractor.new(
            output_port: presenter,
            user_id: current_user.id,
            gateway: interaction_rule_gateway,
            user_lookup: user_lookup_adapter
          ).call
        end

        # GET /api/v1/masters/interaction_rules/:id
        def show
          input_valid?(:show) || return
          presenter = Adapters::InteractionRule::Presenters::InteractionRuleDetailApiPresenter.new(view: self)
          Domain::InteractionRule::Interactors::InteractionRuleDetailInteractor.new(
            output_port: presenter,
            user_id: current_user.id,
            gateway: interaction_rule_gateway,
            user_lookup: user_lookup_adapter
          ).call(params[:id])
        end

        # POST /api/v1/masters/interaction_rules
        def create
          input_dto = Domain::InteractionRule::Dtos::InteractionRuleCreateInput.from_hash(params.to_unsafe_h.deep_symbolize_keys)
          unless valid_create_params?(input_dto)
            render_response(json: { errors: [ "rule_type, source_group, target_group, impact_ratio are required" ] }, status: :unprocessable_entity)
            return
          end
          presenter = Adapters::InteractionRule::Presenters::InteractionRuleCreateApiPresenter.new(view: self)
          Domain::InteractionRule::Interactors::InteractionRuleCreateInteractor.new(
            output_port: presenter,
            user_id: current_user.id,
            gateway: interaction_rule_gateway,
            translator: translator,
            user_lookup: user_lookup_adapter
          ).call(input_dto)
        end

        # PATCH/PUT /api/v1/masters/interaction_rules/:id
        def update
          input_valid?(:update) || return
          input_dto = Domain::InteractionRule::Dtos::InteractionRuleUpdateInput.from_hash(params.to_unsafe_h.deep_symbolize_keys, params[:id].to_i)
          presenter = Adapters::InteractionRule::Presenters::InteractionRuleUpdateApiPresenter.new(view: self)
          Domain::InteractionRule::Interactors::InteractionRuleUpdateInteractor.new(
            output_port: presenter,
            user_id: current_user.id,
            gateway: interaction_rule_gateway,
            translator: translator,
            user_lookup: user_lookup_adapter
          ).call(input_dto)
        end

        # DELETE /api/v1/masters/interaction_rules/:id
        def destroy
          input_valid?(:destroy) || return
          presenter = Adapters::InteractionRule::Presenters::InteractionRuleDeleteApiPresenter.new(view: self)
          Domain::InteractionRule::Interactors::InteractionRuleDestroyInteractor.new(
            output_port: presenter,
            user_id: current_user.id,
            gateway: interaction_rule_gateway,
            translator: translator,
            user_lookup: user_lookup_adapter
          ).call(params[:id])
        end

        def undo_deletion_path(undo_token:)
          Rails.application.routes.url_helpers.undo_deletion_path(undo_token: undo_token)
        end

        private

        def interaction_rule_gateway
          @interaction_rule_gateway ||= Adapters::InteractionRule::Gateways::InteractionRuleActiveRecordGateway.new(
            deletion_undo_gateway: CompositionRoot.deletion_undo_gateway,
            translator: CompositionRoot.translator
          )
        end

        def input_valid?(action)
          case action
          when :show, :destroy, :update
            return true if params[:id].present?
            render_response(json: { error: "InteractionRule not found" }, status: :not_found)
            false
          else
            true
          end
        end

        def valid_create_params?(input_dto)
          input_dto.rule_type.present? && input_dto.source_group.present? && input_dto.target_group.present? && !input_dto.impact_ratio.nil?
        end
      end
    end
  end
end
