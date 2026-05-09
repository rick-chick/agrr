# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      # before_action 用。農場に属する圃場を認可付きで読み込み、失敗時は failure_presenter に委譲する。
      class FieldLoadAuthorizedInFarmInteractor
        def initialize(failure_presenter:, user_id:, gateway:, user_lookup:)
          @failure_presenter = failure_presenter
          @user_id = user_id
          @gateway = gateway
          @user_lookup = user_lookup
        end

        # @param farm_id [Integer, String]
        # @param field_id [Integer, String]
        # @return [Domain::Field::Dtos::AuthorizedFieldLoadedInFarmDto, nil]
        def call(farm_id, field_id)
          user = @user_lookup.find(@user_id)
          farm_access_filter = Domain::Shared::Policies::FarmPolicy.record_access_filter(user)
          @gateway.find_authorized_field_loaded_in_farm!(
            user,
            farm_id.to_i,
            field_id.to_i,
            farm_access_filter: farm_access_filter
          )
        rescue Domain::Shared::Policies::PolicyPermissionDenied, PolicyPermissionDenied
          @failure_presenter.on_permission_denied
          nil
        rescue Domain::Shared::Exceptions::RecordNotFound
          @failure_presenter.on_not_found
          nil
        end
      end
    end
  end
end
