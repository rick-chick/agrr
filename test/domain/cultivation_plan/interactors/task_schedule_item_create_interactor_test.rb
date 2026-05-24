# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class TaskScheduleItemCreateInteractorTest < DomainLibTestCase
        setup do
          @gateway = mock
          @output_port = mock
          @interactor = TaskScheduleItemCreateInteractor.new(
            output_port: @output_port,
            gateway: @gateway
          )
        end

        test "creates item after policy validation" do
          field = Dtos::TaskScheduleFieldCultivationSnapshot.new(
            id: 10,
            cultivation_plan_crop_id: 5,
            crop_id: 3
          )
          attrs = {
            field_cultivation_id: 10,
            cultivation_plan_crop_id: 5,
            name: "作業A",
            crop_task_template_id: nil
          }
          payload = { id: 1, name: "作業A" }

          @gateway.expects(:find_field_cultivation_for_create!).with(1, 2, 10).returns(field)
          @gateway.expects(:find_crop_task_template_for_mutation).with(nil).returns(nil)
          @gateway.expects(:create).with(user_id: 1, plan_id: 2, attributes: kind_of(Hash)).returns(payload)
          @output_port.expects(:on_created).with(payload)

          @interactor.call(user_id: 1, plan_id: 2, attributes: attrs)
        end

        test "reports record invalid from policy" do
          field = Dtos::TaskScheduleFieldCultivationSnapshot.new(
            id: 10,
            cultivation_plan_crop_id: 5,
            crop_id: 3
          )

          @gateway.expects(:find_field_cultivation_for_create!).returns(field)
          @gateway.expects(:find_crop_task_template_for_mutation).returns(nil)
          @gateway.expects(:create).never
          @output_port.expects(:on_record_invalid).with do |errors:, fallback_message:|
            errors["base"].present? && fallback_message.present?
          end

          @interactor.call(
            user_id: 1,
            plan_id: 2,
            attributes: { field_cultivation_id: 10, cultivation_plan_crop_id: 99, name: "X" }
          )
        end
      end
    end
  end
end
