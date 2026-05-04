# frozen_string_literal: true

module Domain
  module PublicPlan
    module Interactors
      # entry_schedule: farm_id から参照農場を解決（失敗は明示 DTO で Port へ）
      class EntryScheduleResolveReferenceFarmInteractor
        def initialize(output_port:, farm_loader:)
          @output_port = output_port
          @farm_loader = farm_loader
        end

        def call(farm_id)
          farm = @farm_loader.call(farm_id)
          @output_port.on_success(farm)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Dtos::EntryScheduleApiFailureDto.record_not_found(e.message))
        end
      end
    end
  end
end
