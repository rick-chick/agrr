# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      # 農場一覧（カード表示用の行 DTO 束を取得）。Gateway のみでデータを充足し AR は境界を越えない。
      class FarmListRowsBundleInteractor < Domain::Farm::Ports::FarmListInputPort
        def initialize(output_port:, user_id:, gateway:)
          @output_port = output_port
          @gateway = gateway
          @gateway.user_id = user_id if @gateway.respond_to?(:user_id=)
          @user_id = user_id
        end

        def call(input_dto = nil)
          input_dto ||= Domain::Farm::Dtos::FarmListInputDto.new(is_admin: false)
          @gateway.user_id = @user_id

          bundle = @gateway.farm_list_rows_bundle(input_dto)
          @output_port.on_success(bundle)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
