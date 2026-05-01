# frozen_string_literal: true

require "test_helper"

module Domain
  module Pest
    module Interactors
      class PestUpdateInteractorTest < ActiveSupport::TestCase
        setup do
          @user = create(:user)
          @user_id = @user.id
          @mock_gateway = mock
          @mock_output_port = mock
          @mock_translator = mock
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

        test "on_failure includes reload_bundle when update raises and reload succeeds" do
          input_dto = Domain::Pest::Dtos::PestUpdateInputDto.new(pest_id: 1, name: "x")
          pest_entity = mock
          persisted = mock
          bundle = Domain::Pest::Dtos::AuthorizedPestLoadedDto.new(pest_entity: pest_entity, persisted_pest: persisted)

          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:update_for_user).with(@user, 1, instance_of(Hash)).raises(StandardError, "update failed")
          @mock_gateway.expects(:find_authorized_pest_loaded_bundle!).with(@user, 1, for_edit: true).returns(bundle)
          received = nil
          @mock_output_port.expects(:on_failure).with { |dto| received = dto }

          @interactor.call(input_dto)

          assert_instance_of Domain::Pest::Dtos::PestUpdateFailureDto, received
          assert_equal "update failed", received.message
          assert_equal bundle, received.reload_bundle
        end

        test "on_failure has nil reload_bundle when user lookup raises" do
          input_dto = Domain::Pest::Dtos::PestUpdateInputDto.new(pest_id: 1, name: "x")

          @mock_user_lookup.expects(:find).with(@user_id).raises(StandardError, "no user")
          @mock_gateway.expects(:update_for_user).never
          @mock_gateway.expects(:find_authorized_pest_loaded_bundle!).never
          received = nil
          @mock_output_port.expects(:on_failure).with { |dto| received = dto }

          @interactor.call(input_dto)

          assert_instance_of Domain::Pest::Dtos::PestUpdateFailureDto, received
          assert_equal "no user", received.message
          assert_nil received.reload_bundle
        end

        test "on_failure has nil reload_bundle when reload bundle raises" do
          input_dto = Domain::Pest::Dtos::PestUpdateInputDto.new(pest_id: 1, name: "x")

          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:update_for_user).with(@user, 1, instance_of(Hash)).raises(StandardError, "update failed")
          @mock_gateway.expects(:find_authorized_pest_loaded_bundle!).with(@user, 1, for_edit: true).raises(StandardError, "reload failed")
          received = nil
          @mock_output_port.expects(:on_failure).with { |dto| received = dto }

          @interactor.call(input_dto)

          assert_instance_of Domain::Pest::Dtos::PestUpdateFailureDto, received
          assert_equal "update failed", received.message
          assert_nil received.reload_bundle
        end
      end
    end
  end
end
