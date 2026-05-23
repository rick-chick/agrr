# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskHtmlNewMasterFormInteractor
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @user_id = user_id
          @gateway = gateway
          @user_lookup = user_lookup
        end

        def call
          user = @user_lookup.find(@user_id)
          task = @gateway.build_blank_agricultural_task_for_master_form(user)
          @output_port.on_success(task)
        end
      end
    end
  end
end
