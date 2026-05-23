# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class PestHtmlCropSelectionLoadInteractor
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @user_id = user_id
          @gateway = gateway
          @user_lookup = user_lookup
        end

        # @param request_crop_ids [Symbol] :use_payload_associations のとき {PestMasterEditPayload#associated_crop_ids} を選択の素にする。
        #   配列を渡したときはその値（空配列可）を素にし、許可 ID との積集合で正規化する。
        def call(master_edit_payload:, request_crop_ids: :use_payload_associations)
          user = @user_lookup.find(@user_id)
          bundle = @gateway.pest_html_master_form_crop_selection_bundle!(
            user: user,
            master_edit_payload: master_edit_payload,
            request_crop_ids: request_crop_ids
          )
          @output_port.on_success(bundle)
        end
      end
    end
  end
end
