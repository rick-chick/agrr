# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Policies
      class CropMastersCropEditAccessTest < DomainLibTestCase
        setup do
          @user = stub(id: 1, admin?: false)
          @access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(@user)
          @gateway = mock
          @output_port = mock
          @failure = Domain::Crop::Dtos::MastersCropTaskTemplateMastersFailure.new(reason: :crop_not_found)
        end

        test "assert_edit_or_on_failure returns true when edit is allowed" do
          crop_record = stub(is_reference: false, user_id: 1)

          @gateway.expects(:find_by_id).with(2).returns(crop_record)

          assert Domain::Crop::Policies::CropMastersCropEditAccess.assert_edit_or_on_failure(
            access_filter: @access_filter,
            crop_id: 2,
            gateway: @gateway,
            output_port: @output_port,
            failure: @failure,
          )
        end

        test "assert_edit_or_on_failure calls on_failure when edit is denied" do
          crop_record = stub(is_reference: false, user_id: 99)

          @gateway.expects(:find_by_id).with(2).returns(crop_record)
          @output_port.expects(:on_failure).with(@failure)

          assert_not Domain::Crop::Policies::CropMastersCropEditAccess.assert_edit_or_on_failure(
            access_filter: @access_filter,
            crop_id: 2,
            gateway: @gateway,
            output_port: @output_port,
            failure: @failure,
          )
        end

        test "assert_edit_or_on_failure calls on_failure when crop is missing" do
          @gateway.expects(:find_by_id).with(2).raises(Domain::Shared::Exceptions::RecordNotFound)
          @output_port.expects(:on_failure).with(@failure)

          assert_not Domain::Crop::Policies::CropMastersCropEditAccess.assert_edit_or_on_failure(
            access_filter: @access_filter,
            crop_id: 2,
            gateway: @gateway,
            output_port: @output_port,
            failure: @failure,
          )
        end
      end
    end
  end
end
