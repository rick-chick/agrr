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
          access_filter = Domain::Shared::Policies::InteractionRulePolicy.record_access_filter(user)
          rule_entity = @gateway.find_by_id(rule_id)
          if for_edit
            Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, rule_entity)
          else
            Domain::Shared::ReferenceRecordAuthorization.assert_view_allowed!(access_filter, rule_entity)
          end
          html_display = Domain::Shared::Dtos::ResourceDisplayCapabilities.for_detail_record(user, rule_entity)
          @output_port.on_success(rule_entity, html_display: html_display)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_failure(:no_permission)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(:not_found)
        end
      end
    end
  end
end
