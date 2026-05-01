# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskLoadAuthorizedModelForViewInteractor
        def initialize(output_port:, user_id:, gateway:, logger:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @user_lookup = user_lookup
        end

        def call(task_id)
          user = @user_lookup.find(@user_id)
          task = @gateway.authorized_record_for_view(user, task_id)
          @output_port.on_success(task)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @logger.warn("[AgriculturalTaskLoadAuthorizedModelForViewInteractor] #{e.message}")
          @output_port.on_failure(:no_permission)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @logger.warn("[AgriculturalTaskLoadAuthorizedModelForViewInteractor] #{e.message}")
          @output_port.on_failure(:not_found)
        end
      end
    end
  end
end
