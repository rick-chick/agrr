# frozen_string_literal: true

module Domain
  module Fertilize
    module Dtos
      # 肥料作成（HTML）の検証失敗時。Interactor がゲートウェイで検証済みスナップショットを渡す。
      class FertilizeCreateFailure
        attr_reader :message, :master_form_snapshot

        # @param master_form_snapshot [Domain::Fertilize::Dtos::FertilizeMasterFormSnapshot]
        def initialize(message:, master_form_snapshot:)
          @message = message
          @master_form_snapshot = master_form_snapshot
        end
      end
    end
  end
end
