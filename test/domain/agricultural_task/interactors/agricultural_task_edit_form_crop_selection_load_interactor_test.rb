# frozen_string_literal: true

require "test_helper"

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskEditFormCropSelectionLoadInteractorTest < ActiveSupport::TestCase
        test "update action uses preview task for reference crop list and filters selected ids" do
          user_id = 10
          task_id = 5
          user = Object.new

          base_task = Object.new
          base_task.define_singleton_method(:is_reference?) { false }
          base_task.define_singleton_method(:region) { nil }
          base_task.define_singleton_method(:user_id) { user_id }

          preview_task = Object.new
          preview_task.define_singleton_method(:is_reference?) { true }
          preview_task.define_singleton_method(:region) { "r1" }
          preview_task.define_singleton_method(:user_id) { user_id }

          crop_entity = Domain::Crop::Entities::CropEntity.from_hash(
            id: 1,
            name: "参照作物",
            is_reference: true,
            user_id: nil,
            region: "r1"
          )
          crops = [ crop_entity ]

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          ag_gateway = Object.new
          ag_gateway.define_singleton_method(:find_authorized_model_for_edit) do |u, tid, access_filter:|
            raise unless u == user && tid == task_id
            raise unless access_filter.is_a?(Domain::Shared::ReferenceRecordAccessFilter)

            base_task
          end
          ag_gateway.define_singleton_method(:preview_agricultural_task_for_edit_crop_selection) do |base_task:, user:, agricultural_task_params:|
            preview_task
          end
          ag_gateway.define_singleton_method(:linked_crop_ids_for_task_templates) do |tid|
            raise unless tid == task_id

            [ 2 ]
          end

          crop_gateway = Minitest::Mock.new
          crop_gateway.expect(:list_reference_crop_entities, crops, [], region: "r1")

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskEditFormCropSelectionInputDto.new(
            user_id: user_id,
            agricultural_task_id: task_id,
            controller_action: "update",
            agricultural_task_attributes_for_preview: { "name" => "edited" },
            raw_selected_crop_ids: [ "1", "99" ],
            include_crop_cards: false
          )

          interactor = AgriculturalTaskEditFormCropSelectionLoadInteractor.new(
            output_port: output_port,
            user_id: user_id,
            agricultural_task_gateway: ag_gateway,
            crop_gateway: crop_gateway,
            user_lookup: user_lookup,
            logger: Object.new
          )

          assert_equal true, interactor.call(input_dto)

          assert_equal crops, received.accessible_crops
          assert_equal [ 1 ], received.accessible_crop_ids
          assert_equal [ 1 ], received.filtered_selected_crop_ids
          assert_equal [ 1 ], received.selected_crop_ids_for_form_hidden
          assert_nil received.crop_cards

          user_lookup.verify
          crop_gateway.verify
          output_port.verify
        end

        test "edit action uses base task and builds crop cards from linked template ids" do
          user_id = 10
          task_id = 5
          user = Object.new

          base_task = Object.new
          base_task.define_singleton_method(:is_reference?) { false }
          base_task.define_singleton_method(:region) { nil }
          base_task.define_singleton_method(:user_id) { user_id }

          crop_one = Domain::Crop::Entities::CropEntity.from_hash(
            id: 1,
            name: "A",
            is_reference: false,
            user_id: user_id
          )
          crop_two = Domain::Crop::Entities::CropEntity.from_hash(
            id: 2,
            name: "B",
            is_reference: false,
            user_id: user_id
          )
          crops = [ crop_one, crop_two ]

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          ag_gateway = Object.new
          ag_gateway.define_singleton_method(:find_authorized_model_for_edit) do |u, tid, access_filter:|
            raise unless u == user && tid == task_id
            raise unless access_filter.is_a?(Domain::Shared::ReferenceRecordAccessFilter)

            base_task
          end
          ag_gateway.define_singleton_method(:linked_crop_ids_for_task_templates) do |tid|
            raise unless tid == task_id

            [ 1 ]
          end

          crop_gateway = Minitest::Mock.new
          crop_gateway.expect(:list_non_reference_crops_for_user_id_ordered, crops, [ user_id, nil ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskEditFormCropSelectionInputDto.new(
            user_id: user_id,
            agricultural_task_id: task_id,
            controller_action: "edit",
            agricultural_task_attributes_for_preview: {},
            raw_selected_crop_ids: nil,
            include_crop_cards: true
          )

          interactor = AgriculturalTaskEditFormCropSelectionLoadInteractor.new(
            output_port: output_port,
            user_id: user_id,
            agricultural_task_gateway: ag_gateway,
            crop_gateway: crop_gateway,
            user_lookup: user_lookup,
            logger: Object.new
          )

          assert_equal true, interactor.call(input_dto)

          assert_equal crops, received.accessible_crops
          assert_equal [ 1, 2 ], received.accessible_crop_ids
          assert_equal [], received.filtered_selected_crop_ids
          assert_equal [ 1 ], received.selected_crop_ids_for_form_hidden
          assert_equal 2, received.crop_cards.size
          assert_equal crop_one, received.crop_cards[0][:crop]
          assert_equal true, received.crop_cards[0][:selected]
          assert_equal crop_two, received.crop_cards[1][:crop]
          assert_equal false, received.crop_cards[1][:selected]

          user_lookup.verify
          crop_gateway.verify
          output_port.verify
        end
      end
    end
  end
end
