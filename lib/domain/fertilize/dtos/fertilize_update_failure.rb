# frozen_string_literal: true

module Domain
  module Fertilize
    module Dtos
      # 肥料更新失敗時に Output Port へ渡す。HTML 再表示用スナップショットは Interactor が Entity から構築（AR なし）。
      class FertilizeUpdateFailure
        attr_reader :message, :master_form_snapshot

        # @param message [String]
        # @param master_form_snapshot [Domain::Fertilize::Dtos::FertilizeMasterFormSnapshot, nil]
        def initialize(message:, master_form_snapshot: nil)
          @message = message
          @master_form_snapshot = master_form_snapshot
        end
      end
    end
  end
end
