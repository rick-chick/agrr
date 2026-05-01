# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      # 農場一覧（HTML）: gateway のみでデータを充足し、カード表示用 DTO を Port に渡す（AR は境界を越えない）。
      class FarmListHtmlInteractor < Domain::Farm::Ports::FarmListInputPort
        def initialize(output_port:, user_id:, gateway:)
          @output_port = output_port
          @gateway = gateway
          @gateway.user_id = user_id if @gateway.respond_to?(:user_id=)
          @user_id = user_id
        end

        def call(input_dto = nil)
          input_dto ||= Domain::Farm::Dtos::FarmListInputDto.new(is_admin: false)
          @gateway.user_id = @user_id

          success = @gateway.farm_list_html_index(input_dto)
          @output_port.on_success(success)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
