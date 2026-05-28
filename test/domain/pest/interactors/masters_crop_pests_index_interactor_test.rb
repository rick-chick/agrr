# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pest
    module Interactors
      class MastersCropPestsIndexInteractorTest < DomainLibTestCase
        setup do
          @user = Object.new
          def @user.id
            42
          end

          def @user.admin?
            false
          end

          @user_id = 42
          @crop_id = 100
          @user_lookup = mock("user_lookup")
          @pest_gateway = mock("pest_gateway")
          @output_port = mock("output_port")
          @interactor = MastersCropPestsIndexInteractor.new(
            output_port: @output_port,
            user_id: @user_id,
            user_lookup: @user_lookup,
            pest_gateway: @pest_gateway
          )
        end

        test "on_success filters crop pests by selectable list policy" do
          filter = Domain::Shared::Policies::PestPolicy.selectable_list_filter(@user)
          accessible = [
            Entities::PestEntity.new(
              id: 1, user_id: @user_id, name: "A", name_scientific: nil, family: nil, order: nil,
              description: nil, occurrence_season: nil, region: nil, is_reference: false,
              created_at: nil, updated_at: nil
            ),
            Entities::PestEntity.new(
              id: 2, user_id: @user_id, name: "B", name_scientific: nil, family: nil, order: nil,
              description: nil, occurrence_season: nil, region: nil, is_reference: false,
              created_at: nil, updated_at: nil
            )
          ]
          crop_pests = [ accessible.first ]

          @user_lookup.expects(:find).with(@user_id).returns(@user)
          @pest_gateway.expects(:list_index_for_filter).with(filter).returns(accessible)
          @pest_gateway.expects(:list_pests_for_crop_filtered).with(
            crop_id: @crop_id,
            pest_ids: [ 1, 2 ],
            order: :id_asc
          ).returns(crop_pests)
          @output_port.expects(:on_success).with(crop_pests)

          @interactor.call(crop_id: @crop_id)
        end
      end
    end
  end
end
