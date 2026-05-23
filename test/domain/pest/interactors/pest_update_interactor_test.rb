# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pest
    module Interactors
      UserStub = Struct.new(:id, :admin?, keyword_init: true)

      class PestUpdateInteractorTest < DomainLibTestCase
        setup do
          @user = UserStub.new(id: 1, admin?: true)
          @user_id = @user.id
          @mock_gateway = mock
          @mock_output_port = mock
          @mock_translator = mock
          @mock_translator.stubs(:t) { |key| key }
          @mock_user_lookup = mock
          @mock_logger = mock
          @mock_logger.stubs(:info)
          @interactor = PestUpdateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: @user_id,
            logger: @mock_logger,
            translator: @mock_translator,
            user_lookup: @mock_user_lookup
          )
        end

        test "on_failure includes PestMasterFormFailure with crop bundle when update raises RecordInvalid" do
          input_dto = Domain::Pest::Dtos::PestUpdateInput.new(pest_id: 1, name: "x", crop_ids: [2])
          crop_bundle = Domain::Pest::Dtos::PestMasterFormCropSelectionBundle.new(selected_crop_ids: [2], crop_cards: [])

          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          current_pest = mock
          current_pest.expects(:reference?).at_least_once.returns(false)
          current_pest.stubs(:user_id).returns(@user_id)
          @mock_gateway.expects(:find_by_id).with(1).returns(current_pest)
          @mock_gateway.expects(:update_for_user).with(@user, 1, instance_of(Hash)).raises(Domain::Shared::Exceptions::RecordInvalid.new("update failed"))
          @mock_gateway.expects(:pest_master_form_crop_selection_bundle!).with do |**kwargs|
            assert_equal @user, kwargs[:user]
            assert_equal [2], kwargs[:request_crop_ids]
            assert_instance_of Domain::Pest::Dtos::PestMasterEditPayload, kwargs[:master_edit_payload]
            assert_equal 1, kwargs[:master_edit_payload].id
            true
          end.returns(crop_bundle)
          received = nil
          @mock_output_port.expects(:on_failure).with { |dto| received = dto }

          @interactor.call(input_dto)

          assert_instance_of Domain::Pest::Dtos::PestMasterFormFailure, received
          assert_equal "update failed", received.message
          assert_equal crop_bundle, received.crop_selection_bundle
          assert_equal "x", received.master_edit_payload.name
        end

        test "propagates StandardError when user lookup raises" do
          input_dto = Domain::Pest::Dtos::PestUpdateInput.new(pest_id: 1, name: "x")

          @mock_user_lookup.expects(:find).with(@user_id).raises(StandardError, "no user")
          @mock_gateway.expects(:find_by_id).never
          @mock_gateway.expects(:update_for_user).never
          @mock_gateway.expects(:pest_master_form_crop_selection_bundle!).never

          assert_raises(StandardError, "no user") do
            @interactor.call(input_dto)
          end
        end

        test "on_failure has nil crop_selection_bundle when crop bundle raises RecordNotFound" do
          input_dto = Domain::Pest::Dtos::PestUpdateInput.new(pest_id: 1, name: "x")

          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          current_pest = mock
          current_pest.expects(:reference?).at_least_once.returns(false)
          current_pest.stubs(:user_id).returns(@user_id)
          @mock_gateway.expects(:find_by_id).with(1).returns(current_pest)
          @mock_gateway.expects(:update_for_user).with(@user, 1, instance_of(Hash)).raises(Domain::Shared::Exceptions::RecordInvalid.new("update failed"))
          @mock_gateway.expects(:pest_master_form_crop_selection_bundle!).raises(
            Domain::Shared::Exceptions::RecordNotFound.new("reload failed")
          )
          received = nil
          @mock_output_port.expects(:on_failure).with { |dto| received = dto }

          @interactor.call(input_dto)

          assert_instance_of Domain::Pest::Dtos::PestMasterFormFailure, received
          assert_equal "update failed", received.message
          assert_nil received.crop_selection_bundle
          assert_instance_of Domain::Pest::Dtos::PestMasterEditPayload, received.master_edit_payload
        end

        test "一般ユーザーが is_reference を変更しようとすると on_failure（reference_flag_admin_only）" do
          non_admin = UserStub.new(id: 1, admin?: false)
          input_dto = Domain::Pest::Dtos::PestUpdateInput.new(pest_id: 1, is_reference: true)
          current = mock
          current.stubs(:reference?).returns(false)
          current.stubs(:user_id).returns(1)

          @mock_user_lookup.expects(:find).with(@user_id).returns(non_admin)
          @mock_gateway.expects(:find_by_id).with(1).returns(current)
          @mock_gateway.expects(:update_for_user).never
          @mock_gateway.expects(:pest_master_form_crop_selection_bundle!).never
          @mock_translator.stubs(:t).with("pests.flash.reference_flag_admin_only")
                          .returns("pests.flash.reference_flag_admin_only")

          received = nil
          @mock_output_port.expects(:on_failure).with { |arg| received = arg; true }

          @interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::ReferenceFlagChangeDeniedFailure, received
          assert_equal "pests.flash.reference_flag_admin_only", received.message
          assert_equal 1, received.resource_id
        end
      end
    end
  end
end
