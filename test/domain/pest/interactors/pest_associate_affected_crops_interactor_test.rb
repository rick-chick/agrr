# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pest
    module Interactors
      class PestAssociateAffectedCropsInteractorTest < DomainLibTestCase
        PestStub = Struct.new(:id, :user_id, :region, :is_reference, keyword_init: true) do
          def reference?
            is_reference
          end
        end

        CropStub = Struct.new(:id, :user_id, :region, :is_reference, :name, keyword_init: true) do
          def reference?
            is_reference
          end
        end

        setup do
          @user = domain_user_stub(id: 1, admin: false)
          @user_lookup = mock
          @user_lookup.stubs(:find).with(1).returns(@user)
          @pest_gateway = mock
          @crop_gateway = mock
          @crop_pest_gateway = mock
          @logger = mock
          @logger.stubs(:info)
          @logger.stubs(:warn)
          @interactor = PestAssociateAffectedCropsInteractor.new(
            user_id: 1,
            user_lookup: @user_lookup,
            pest_gateway: @pest_gateway,
            crop_gateway: @crop_gateway,
            crop_pest_gateway: @crop_pest_gateway,
            logger: @logger
          )
          @pest = PestStub.new(id: 10, user_id: 1, region: nil, is_reference: false)
        end

        test "persists only authorized crop ids from payload" do
          own_crop = CropStub.new(id: 2, user_id: 1, region: nil, is_reference: false, name: "Mine")
          other_crop = CropStub.new(id: 3, user_id: 99, region: nil, is_reference: false, name: "Other")

          @pest_gateway.expects(:find_by_id).with(10).returns(@pest)
          @crop_gateway.expects(:find_by_id).with(2).returns(own_crop)
          @crop_gateway.expects(:find_by_id).with(3).returns(other_crop)
          @crop_pest_gateway.expects(:find_by_crop_id_and_pest_id).with(crop_id: 2, pest_id: 10).returns(nil)
          @crop_pest_gateway.expects(:create).with(crop_id: 2, pest_id: 10)

          count = @interactor.call(
            pest_id: 10,
            affected_crops: [ { "crop_id" => 2 }, { "crop_id" => 3 } ]
          )

          assert_equal 1, count
        end

        test "resolves crop id by name when ids absent" do
          ref_crop = CropStub.new(id: 5, user_id: nil, region: nil, is_reference: true, name: "RefTomato")

          @pest_gateway.expects(:find_by_id).with(10).returns(@pest)
          @crop_gateway.expects(:resolve_crop_id_by_name).with(user_id: 1, crop_name: "RefTomato").returns(5)
          @crop_gateway.expects(:find_by_id).with(5).returns(ref_crop)
          @crop_pest_gateway.expects(:find_by_crop_id_and_pest_id).with(crop_id: 5, pest_id: 10).returns(nil)
          @crop_pest_gateway.expects(:create).with(crop_id: 5, pest_id: 10)

          count = @interactor.call(pest_id: 10, affected_crops: [ { "crop_name" => "RefTomato" } ])

          assert_equal 1, count
        end
      end
    end
  end
end
