# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmListInteractor < Domain::Farm::Ports::FarmListInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(input_dto = nil)
          input_dto ||= Domain::Farm::Dtos::FarmListInputDto.new(is_admin: false)
          user = User.find(@user_id)
          farms = @gateway.list

          if input_dto.is_admin
            # 管理者は自分の農場と参照農場の両方を表示
            owned_farms = Domain::Shared::Policies::FarmPolicy.visible_scope(::Farm, user)
            reference_farms = ::Farm.reference
            all_farms = owned_farms.or(reference_farms)
            filtered_farms = farms.select { |farm_entity| all_farms.exists?(farm_entity.id) }
          else
            # 通常ユーザーは自分の農場のみ
            visible_farms = Domain::Shared::Policies::FarmPolicy.visible_scope(::Farm, user)
            filtered_farms = farms.select { |farm_entity| visible_farms.exists?(farm_entity.id) }
          end

          @output_port.on_success(filtered_farms)
        rescue ActiveRecord::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end