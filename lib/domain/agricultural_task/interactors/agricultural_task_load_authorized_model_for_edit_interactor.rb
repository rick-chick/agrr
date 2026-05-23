# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskLoadAuthorizedModelForEditInteractor
        def initialize(output_port:, user_id:, gateway:, logger:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @user_lookup = user_lookup
        end

        def call(task_id)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::AgriculturalTaskPolicy.record_access_filter(user)
          bundle = @gateway.find_agricultural_task_loaded_bundle!(task_id.to_i, for_edit: true)
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, bundle.agricultural_task_entity)
          @output_port.on_success(bundle)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @logger.warn("[AgriculturalTaskLoadAuthorizedModelForEditInteractor] #{e.message}")
          @output_port.on_failure(:no_permission)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @logger.warn("[AgriculturalTaskLoadAuthorizedModelForEditInteractor] #{e.message}")
          @output_port.on_failure(:not_found)
        end
      end
    end
  end
end
