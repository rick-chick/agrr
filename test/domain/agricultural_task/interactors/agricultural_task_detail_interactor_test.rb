# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskDetailInteractorTest < DomainLibTestCase
        TaskWire = Data.define(
          :id,
          :user_id,
          :name,
          :description,
          :time_per_sqm,
          :weather_dependency,
          :required_tools,
          :skill_level,
          :region,
          :task_type,
          :is_reference,
          :created_at,
          :updated_at
        )

        AgriculturalTaskShowDetailWire = Data.define(:task, :crops)

        test "calls on_success with detail dto when read gateway returns wire" do
          user_id = 10
          task_id = 22
          user = stub(id: user_id, admin?: false)
          now = Time.utc(2026, 1, 1)
          task_wire = TaskWire.new(
            id: task_id,
            user_id: user_id,
            name: "作業",
            description: nil,
            time_per_sqm: nil,
            weather_dependency: nil,
            required_tools: [],
            skill_level: nil,
            region: nil,
            task_type: nil,
            is_reference: false,
            created_at: now,
            updated_at: now
          )
          wire = AgriculturalTaskShowDetailWire.new(task: task_wire, crops: [])

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          show_detail_read_gateway = mock
          show_detail_read_gateway.expects(:find_show_detail_snapshot).with(task_id: task_id).returns(wire)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = AgriculturalTaskDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            show_detail_read_gateway: show_detail_read_gateway,
            user_lookup: user_lookup
          )

          interactor.call(task_id)

          assert_instance_of Domain::AgriculturalTask::Dtos::AgriculturalTaskDetailOutput, received
          assert_equal task_id, received.task.id
          assert_equal [], received.associated_crops
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure with policy exception when permission is denied" do
          user_id = 10
          task_id = 22
          user = stub(id: user_id, admin?: false)
          now = Time.utc(2026, 1, 1)
          task_wire = TaskWire.new(
            id: task_id,
            user_id: 99,
            name: "作業",
            description: nil,
            time_per_sqm: nil,
            weather_dependency: nil,
            required_tools: [],
            skill_level: nil,
            region: nil,
            task_type: nil,
            is_reference: false,
            created_at: now,
            updated_at: now
          )
          wire = AgriculturalTaskShowDetailWire.new(task: task_wire, crops: [])

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          show_detail_read_gateway = mock
          show_detail_read_gateway.expects(:find_show_detail_snapshot).with(task_id: task_id).returns(wire)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = AgriculturalTaskDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            show_detail_read_gateway: show_detail_read_gateway,
            user_lookup: user_lookup
          )

          interactor.call(task_id)

          assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, received
          user_lookup.verify
          output_port.verify
        end
      end
    end
  end
end
