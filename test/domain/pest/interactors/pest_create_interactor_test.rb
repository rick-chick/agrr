# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pest
    module Interactors
      class PestCreateInteractorTest < DomainLibTestCase
        def build_input(is_reference: nil, region: nil)
          Domain::Pest::Dtos::PestCreateInput.new(
            name: "テスト害虫",
            region: region,
            is_reference: is_reference
          )
        end

        def build_interactor(output_port:, gateway:, user:)
          user_lookup = mock
          user_lookup.expects(:find).with(7).returns(user)
          translator = Object.new
          def translator.t(key) = key
          PestCreateInteractor.new(
            output_port: output_port,
            user_id: 7,
            gateway: gateway,
            translator: translator,
            user_lookup: user_lookup
          )
        end

        test "一般ユーザーが参照害虫を作成しようとすると on_failure（reference_only_admin）" do
          gateway = mock
          gateway.expects(:create_for_user).never
          output_port = mock
          received = nil
          output_port.expects(:on_failure).with { |arg| received = arg; true }

          build_interactor(output_port: output_port, gateway: gateway, user: stub(id: 7, admin?: false))
            .call(build_input(is_reference: true))

          assert_equal "pests.flash.reference_only_admin", received.message
        end

        test "admin は参照害虫を作成でき on_success" do
          pest_entity = stub(id: 1)
          gateway = mock
          gateway.expects(:create_for_user).with do |_user, attrs|
            assert attrs[:is_reference]
            assert_nil attrs[:user_id]
            true
          end.returns(pest_entity)
          output_port = mock
          output_port.expects(:on_success).with(pest_entity)

          build_interactor(output_port: output_port, gateway: gateway, user: stub(id: 7, admin?: true))
            .call(build_input(is_reference: true))
        end

        test "一般ユーザーの非参照害虫作成は呼び出しユーザー所有で on_success" do
          pest_entity = stub(id: 1)
          gateway = mock
          gateway.expects(:create_for_user).with do |_user, attrs|
            assert_not attrs[:is_reference]
            assert_equal 7, attrs[:user_id]
            true
          end.returns(pest_entity)
          output_port = mock
          output_port.expects(:on_success).with(pest_entity)

          build_interactor(output_port: output_port, gateway: gateway, user: stub(id: 7, admin?: false))
            .call(build_input(is_reference: false))
        end

        test "create の RecordInvalid 時は PestMasterFormFailure を返す" do
          user = stub(id: 7, admin?: false)
          input = build_input(is_reference: false)
          crop_bundle = Domain::Pest::Dtos::PestMasterFormCropSelectionBundle.new(selected_crop_ids: [], crop_cards: [])
          gateway = mock
          gateway.expects(:create_for_user).raises(Domain::Shared::Exceptions::RecordInvalid.new("invalid"))
          gateway.expects(:pest_master_form_crop_selection_bundle!).returns(crop_bundle)
          output_port = mock
          received = nil
          output_port.expects(:on_failure).with { |arg| received = arg; true }

          build_interactor(output_port: output_port, gateway: gateway, user: user).call(input)

          assert_instance_of Domain::Pest::Dtos::PestMasterFormFailure, received
          assert_equal "invalid", received.message
          assert_equal crop_bundle, received.crop_selection_bundle
          assert_equal "テスト害虫", received.master_edit_payload.name
        end

        test "一般ユーザーの region 指定は Policy により破棄される" do
          gateway = mock
          gateway.expects(:create_for_user).with do |_user, attrs|
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
