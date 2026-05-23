# frozen_string_literal: true

require "domain_lib_test_helper"

class Domain::Pest::Interactors::PestHtmlCropSelectionLoadInteractorTest < DomainLibTestCase
  test "call resolves user and forwards gateway bundle to output port" do
    user = Object.new
    def user.id; 7; end

    user_lookup = mock
    user_lookup.expects(:find).with(7).returns(user)

    payload = Domain::Pest::Dtos::PestMasterEditPayload.for_blank_new
    bundle = Domain::Pest::Dtos::PestHtmlCropSelectionLoadBundle.new(
      accessible_crops: [ :c1 ],
      selected_crop_ids: [ 1 ],
      crop_cards: [ { crop: :c1, selected: true } ]
    )

    gateway = mock
    gateway.expects(:pest_html_master_form_crop_selection_bundle!).with(
      user: user,
      master_edit_payload: payload,
      request_crop_ids: :use_payload_associations
    ).returns(bundle)

    output = mock
    output.expects(:on_success).with(bundle)

    Domain::Pest::Interactors::PestHtmlCropSelectionLoadInteractor.new(
      output_port: output,
      user_id: 7,
      gateway: gateway,
      user_lookup: user_lookup
    ).call(master_edit_payload: payload)
  end

  test "call passes explicit request_crop_ids array to gateway" do
    user = Object.new
    def user.id; 3; end

    user_lookup = mock
    user_lookup.expects(:find).with(3).returns(user)

    payload = Domain::Pest::Dtos::PestMasterEditPayload.for_blank_new
    bundle = Domain::Pest::Dtos::PestHtmlCropSelectionLoadBundle.new(
      accessible_crops: [],
      selected_crop_ids: [],
      crop_cards: []
    )

    gateway = mock
    gateway.expects(:pest_html_master_form_crop_selection_bundle!).with(
      user: user,
      master_edit_payload: payload,
      request_crop_ids: [ 9, 9 ]
    ).returns(bundle)

    output = mock
    output.expects(:on_success).with(bundle)

    Domain::Pest::Interactors::PestHtmlCropSelectionLoadInteractor.new(
      output_port: output,
      user_id: 3,
      gateway: gateway,
      user_lookup: user_lookup
    ).call(master_edit_payload: payload, request_crop_ids: [ 9, 9 ])
  end
end
