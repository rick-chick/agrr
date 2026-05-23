# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      # 農場一覧（カード表示用の行 DTO 束を取得）。Gateway のみでデータを充足し AR は境界を越えない。
      class FarmListRowsBundleInteractor < Domain::Farm::Ports::FarmListInputPort
        def initialize(output_port:, user_id:, gateway:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(input_dto = nil)
          input_dto ||= Domain::Farm::Dtos::FarmListInput.new(is_admin: false)

          farm_rows = if input_dto.is_admin
                        @gateway.list_user_and_reference_farm_rows(user_id: @user_id)
                      else
                        @gateway.list_user_owned_farm_rows(user_id: @user_id)
                      end
          reference_farm_rows = input_dto.is_admin ? @gateway.list_reference_farm_rows : []

          bundle = Domain::Farm::Dtos::FarmListRowsBundle.new(
            farm_rows: farm_rows,
            reference_farm_rows: reference_farm_rows
          )
          @output_port.on_success(bundle)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
