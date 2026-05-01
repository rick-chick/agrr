# frozen_string_literal: true

module Domain
  module InteractionRule
    module Interactors
      # show / edit / update 前処理: 認可済みルールを読み込み Output Port に渡す（チャネル名を型に含めない）。
      class InteractionRuleLoadInteractor
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(rule_id:, for_edit:)
          user = @user_lookup.find(@user_id)
          rule_entity =
            if for_edit
              @gateway.find_authorized_for_edit(user, rule_id)
            else
              @gateway.find_authorized_for_view(user, rule_id)
            end
          @output_port.on_success(rule_entity)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_failure(:no_permission)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(:not_found)
        end
      end
    end
  end
end
