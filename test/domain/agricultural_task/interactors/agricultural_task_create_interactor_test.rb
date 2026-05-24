# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskCreateInteractorTest < DomainLibTestCase
        def build_input(is_reference: nil, region: nil)
          Domain::AgriculturalTask::Dtos::AgriculturalTaskCreateInput.new(
            name: "テスト作業",
            region: region,
            is_reference: is_reference
          )
        end

        def build_interactor(output_port:, gateway:, user:)
          user_lookup = mock
          user_lookup.expects(:find).with(7).returns(user)
          translator = Object.new
          def translator.t(key) = key
          gateway.stubs(:find_by_reference_and_name).returns(nil)
          gateway.stubs(:find_by_user_id_and_name).returns(nil)
          AgriculturalTaskCreateInteractor.new(
            output_port: output_port,
            user_id: 7,
            gateway: gateway,
            translator: translator,
            user_lookup: user_lookup
          )
        end

        test "一般ユーザーが参照作業を作成しようとすると on_failure（reference_only_admin）" do
          gateway = mock
          gateway.expects(:create).never
          output_port = mock
          received = nil
          output_port.expects(:on_failure).with { |arg| received = arg; true }

          build_interactor(output_port: output_port, gateway: gateway, user: stub(id: 7, admin?: false))
            .call(build_input(is_reference: true))

          assert_equal "agricultural_tasks.flash.reference_only_admin", received.message
        end

        test "admin は参照作業を作成でき on_success" do
          task_entity = stub(id: 1)
          gateway = mock
          gateway.expects(:create).with do |attrs|
            assert attrs[:is_reference]
            assert_nil attrs[:user_id]
            true
          end.returns(task_entity)
          output_port = mock
          output_port.expects(:on_success).with(task_entity)

          build_interactor(output_port: output_port, gateway: gateway, user: stub(id: 7, admin?: true))
            .call(build_input(is_reference: true))
        end

        test "一般ユーザーの非参照作業作成は呼び出しユーザー所有で on_success" do
          task_entity = stub(id: 1)
          gateway = mock
          gateway.expects(:create).with do |attrs|
            assert_not attrs[:is_reference]
            assert_equal 7, attrs[:user_id]
            true
          end.returns(task_entity)
          output_port = mock
          output_port.expects(:on_success).with(task_entity)

          build_interactor(output_port: output_port, gateway: gateway, user: stub(id: 7, admin?: false))
            .call(build_input(is_reference: false))
        end

        test "同名がスコープ内に存在すると on_failure（name taken）" do
          gateway = mock
          gateway.expects(:find_by_user_id_and_name).with(user_id: 7, name: "テスト作業").returns(stub(id: 99))
          gateway.expects(:create).never
          user_lookup = mock
          user_lookup.expects(:find).with(7).returns(stub(id: 7, admin?: false))
          translator = Object.new
          def translator.t(key) = key
          output_port = mock
          received = nil
          output_port.expects(:on_failure).with { |arg| received = arg; true }

          AgriculturalTaskCreateInteractor.new(
            output_port: output_port,
            user_id: 7,
            gateway: gateway,
            translator: translator,
            user_lookup: user_lookup
          ).call(build_input(is_reference: false))

          assert_equal "activerecord.errors.models.agricultural_task.attributes.name.taken", received.message
        end

        test "一般ユーザーの region 指定は Policy により破棄される" do
          gateway = mock
          gateway.expects(:create).with do |attrs|
            assert_not attrs.key?(:region)
            true
          end.returns(stub(id: 1))
          output_port = mock
          output_port.expects(:on_success)

          build_interactor(output_port: output_port, gateway: gateway, user: stub(id: 7, admin?: false))
            .call(build_input(is_reference: false, region: "us"))
        end
      end
    end
  end
end
