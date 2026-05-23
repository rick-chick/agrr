# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      class FieldNewMasterFormInteractor
        def initialize(output_port:, user_id:, farm_id:, gateway:, user_lookup:)
          @output_port = output_port
          @user_id = user_id
          @farm_id = farm_id
          @gateway = gateway
          @user_lookup = user_lookup
        end

        def call
          user = @user_lookup.find(@user_id)
          list = @gateway.farm_fields_list(@farm_id)
          Domain::Field::Policies::FieldAccess.assert_field_edit_on_farm_allowed!(user, list.farm)
          Domain::Field::Policies::FieldAccess.assert_farm_fields_list_allowed!(user, list.farm)
          snapshot = @gateway.build_blank_field_for_master_form!(farm_id: @farm_id)
          @output_port.on_success(snapshot)
        end
      end
    end
  end
end
