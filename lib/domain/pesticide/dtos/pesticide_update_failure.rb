# frozen_string_literal: true

module Domain
  module Pesticide
    module Dtos
      # 農薬更新失敗時に Presenter がフォームを再描画するためのメッセージとスナップショット。
      class PesticideUpdateFailure
        # @!attribute [r] message
        #   @return [String]
        # @!attribute [r] master_form_snapshot
        #   @return [Domain::Pesticide::Dtos::PesticideMasterFormSnapshot, nil]
        attr_reader :message, :master_form_snapshot

        # @param message [String]
        # @param master_form_snapshot [Domain::Pesticide::Dtos::PesticideMasterFormSnapshot, nil]
        def initialize(message:, master_form_snapshot: nil)
          @message = message
          @master_form_snapshot = master_form_snapshot
        end
      end
    end
  end
end
