# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pesticide
    module Interactors
      class MastersCropPesticidesIndexInteractorTest < DomainLibTestCase
        setup do
          @user = domain_user_stub(id: 1, admin: false)
          @user_lookup = mock
          @user_lookup.stubs(:find).with(1).returns(@user)
          @crop_entity = Domain::Crop::Entities::CropEntity.new(
            id: 5,
            user_id: 1,
            name: "C",
            variety: nil,
            is_reference: false,
            area_per_unit: 1.0,
            revenue_per_area: 1.0,
            region: "jp",
            groups: [],
            crop_stages: [],
            created_at: Time.utc(2026, 1, 1),
            updated_at: Time.utc(2026, 1, 1)
          )
          @pesticide_gateway = mock
          @crop_gateway = mock
          @output_port = mock
        end

        def interactor
          MastersCropPesticidesIndexInteractor.new(
            output_port: @output_port,
            user_id: 1,
            user_lookup: @user_lookup,
            pesticide_gateway: @pesticide_gateway,
            crop_gateway: @crop_gateway
          )
        end

        test "on_success lists pesticides for authorized crop" do
          pesticides = [ stub(id: 1) ]
          @crop_gateway.expects(:find_by_id).with(5).returns(@crop_entity)
          @pesticide_gateway.expects(:list_by_crop_id_for_filter).with do |crop_id:, filter:|
            crop_id == 5 && filter.mode == :reference_or_owned && filter.user_id == 1
          end.returns(pesticides)
          @output_port.expects(:on_success).with(pesticides)

          interactor.call(crop_id: 5)
        end

        test "on_not_found when crop is reference only" do
          ref_crop = Domain::Crop::Entities::CropEntity.new(
            id: 5,
            user_id: nil,
            name: "R",
            variety: nil,
            is_reference: true,
            area_per_unit: 1.0,
            revenue_per_area: 1.0,
            region: "jp",
            groups: [],
            crop_stages: [],
            created_at: Time.utc(2026, 1, 1),
            updated_at: Time.utc(2026, 1, 1)
          )
          @crop_gateway.expects(:find_by_id).with(5).returns(ref_crop)
          @pesticide_gateway.expects(:list_by_crop_id_for_filter).never
          @output_port.expects(:on_not_found)

          interactor.call(crop_id: 5)
        end

        test "on_not_found when crop missing" do
          @crop_gateway.expects(:find_by_id).with(99).raises(Domain::Shared::Exceptions::RecordNotFound)
          @output_port.expects(:on_not_found)

          interactor.call(crop_id: 99)
        end
      end
    end
  end
end
