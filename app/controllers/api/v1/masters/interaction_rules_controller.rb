# frozen_string_literal: true

module Api
  module V1
    module Masters
      class InteractionRulesController < BaseController
        include Views::Api::InteractionRule::InteractionRuleListView
        include Views::Api::InteractionRule::InteractionRuleDetailView
        include Views::Api::InteractionRule::InteractionRuleCreateView
        include Views::Api::InteractionRule::InteractionRuleUpdateView
        include Views::Api::InteractionRule::InteractionRuleDeleteView

        # GET /api/v1/masters/interaction_rules
        def index
          presenter = Presenters::Api::InteractionRule::InteractionRuleListPresenter.new(view: self)
          interactor = Domain::InteractionRule::Interactors::InteractionRuleListInteractor.new(
            output_port: presenter,
            gateway: interaction_rule_gateway,
            user_id: current_user.id
          )
          interactor.call
        end

        # GET /api/v1/masters/interaction_rules/:id
        def show
          input_valid?(:show) || return
          presenter = Presenters::Api::InteractionRule::InteractionRuleDetailPresenter.new(view: self)
          interactor = Domain::InteractionRule::Interactors::InteractionRuleDetailInteractor.new(
            output_port: presenter,
            gateway: interaction_rule_gateway,
            user_id: current_user.id
          )
          interactor.call(params[:id])
        end

        # POST /api/v1/masters/interaction_rules
        def create
          input_dto = Domain::InteractionRule::Dtos::InteractionRuleCreateInputDto.from_hash(params.to_unsafe_h.deep_symbolize_keys)
          unless valid_create_params?(input_dto)
            render_response(json: { errors: ['rule_type, source_group, target_group, impact_ratio are required'] }, status: :unprocessable_entity)
            return
          end
          presenter = Presenters::Api::InteractionRule::InteractionRuleCreatePresenter.new(view: self)
          interactor = Domain::InteractionRule::Interactors::InteractionRuleCreateInteractor.new(
            output_port: presenter,
            gateway: interaction_rule_gateway,
            user_id: current_user.id
          )
          interactor.call(input_dto)
        end

        # PATCH/PUT /api/v1/masters/interaction_rules/:id
        def update
          input_valid?(:update) || return
          input_dto = Domain::InteractionRule::Dtos::InteractionRuleUpdateInputDto.from_hash(params.to_unsafe_h.deep_symbolize_keys, params[:id].to_i)
          presenter = Presenters::Api::InteractionRule::InteractionRuleUpdatePresenter.new(view: self)
          interactor = Domain::InteractionRule::Interactors::InteractionRuleUpdateInteractor.new(
            output_port: presenter,
            gateway: interaction_rule_gateway,
            user_id: current_user.id
          )
          interactor.call(input_dto)
        end

        # DELETE /api/v1/masters/interaction_rules/:id
        def destroy
          input_valid?(:destroy) || return
          presenter = Presenters::Api::InteractionRule::InteractionRuleDeletePresenter.new(view: self)
          interactor = Domain::InteractionRule::Interactors::InteractionRuleDestroyInteractor.new(
            output_port: presenter,
            gateway: interaction_rule_gateway,
            user_id: current_user.id
          )
          interactor.call(params[:id])
        end

        def render_response(json:, status:)
          render(json: json, status: status)
        end

        def undo_deletion_path(undo_token:)
          Rails.application.routes.url_helpers.undo_deletion_path(undo_token: undo_token)
        end

        private

        def interaction_rule_gateway
          @interaction_rule_gateway ||= Adapters::InteractionRule::Gateways::InteractionRuleActiveRecordGateway.new
        end

        def input_valid?(action)
          case action
          when :show, :destroy, :update
            return true if params[:id].present?
            render_response(json: { error: 'InteractionRule not found' }, status: :not_found)
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
