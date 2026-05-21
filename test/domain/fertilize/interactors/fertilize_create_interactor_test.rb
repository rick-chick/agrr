# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Fertilize
    module Interactors
      # FertilizeCreateInteractor の純粋ユニットテスト（memory gateway 注入・Rails 非依存）。
      # 旧 test/integration/domain/... を ARCHITECTURE.md Testing 規約に沿って書き直したもの。
      # 旧テストの test 2 / 6 は interactor 改修前の失敗 DTO（FertilizeCreateFailure）を
      # 期待しており stale だった。現行 interactor は Domain::Shared::Dtos::Error を返す。
      class FertilizeCreateInteractorTest < DomainLibTestCase
        FakeUser = Struct.new(:id, :is_admin, keyword_init: true) do
          def admin?
            is_admin
          end
        end

        class FakeUserLookup
          def initialize(user: nil, error: nil)
            @user = user
            @error = error
          end

          def find(_user_id)
            raise @error if @error

            @user
          end
        end

        class FakeGateway
          attr_reader :received

          def initialize(entity: nil, error: nil)
            @entity = entity
            @error = error
            @received = nil
          end

          def create_for_user(user, attrs)
            @received = { user: user, attrs: attrs }
            raise @error if @error

            @entity
          end
        end

        class RecordingOutputPort
          attr_reader :success, :failure

          def on_success(entity)
            @success = entity
          end

          def on_failure(error)
            @failure = error
          end
        end

        class StubTranslator
          def t(key, **_options)
            "t:#{key}"
          end
        end

        setup do
          @output_port = RecordingOutputPort.new
          @translator = StubTranslator.new
        end

        test "creates fertilize for a regular user and passes the entity to on_success" do
          user = FakeUser.new(id: 1, is_admin: false)
          entity = Object.new
          gateway = FakeGateway.new(entity: entity)
          input = Domain::Fertilize::Dtos::FertilizeCreateInput.new(name: "Test", n: 10.0, p: 5.0, k: 3.0, region: "Kyoto")

          build_interactor(gateway: gateway, user_lookup: FakeUserLookup.new(user: user)).call(input)

          assert_same entity, @output_port.success
          assert_nil @output_port.failure
          assert_same user, gateway.received[:user]
          assert_instance_of Hash, gateway.received[:attrs]
        end

        test "creates a reference fertilize for an admin user" do
          admin = FakeUser.new(id: 2, is_admin: true)
          entity = Object.new
          gateway = FakeGateway.new(entity: entity)
          input = Domain::Fertilize::Dtos::FertilizeCreateInput.new(name: "Reference", is_reference: true)

          build_interactor(gateway: gateway, user_lookup: FakeUserLookup.new(user: admin)).call(input)

          assert_same entity, @output_port.success
          assert_nil @output_port.failure
        end

        test "rejects a reference fertilize requested by a non-admin user" do
          user = FakeUser.new(id: 1, is_admin: false)
          gateway = FakeGateway.new(entity: Object.new)
          input = Domain::Fertilize::Dtos::FertilizeCreateInput.new(name: "Reference", is_reference: true)

          build_interactor(gateway: gateway, user_lookup: FakeUserLookup.new(user: user)).call(input)

          assert_nil @output_port.success
          assert_instance_of Domain::Shared::Dtos::Error, @output_port.failure
          assert_equal "t:fertilizes.flash.reference_only_admin", @output_port.failure.message
          assert_nil gateway.received, "gateway must not be reached when the request is rejected"
        end

        test "calls on_failure with the policy exception when the gateway denies permission" do
          user = FakeUser.new(id: 1, is_admin: false)
          gateway = FakeGateway.new(error: Domain::Shared::Policies::PolicyPermissionDenied.new)
          input = Domain::Fertilize::Dtos::FertilizeCreateInput.new(name: "X")

          build_interactor(gateway: gateway, user_lookup: FakeUserLookup.new(user: user)).call(input)

          assert_nil @output_port.success
          assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, @output_port.failure
        end

        test "re-raises unexpected gateway errors" do
          user = FakeUser.new(id: 1, is_admin: false)
          gateway = FakeGateway.new(error: StandardError.new("Name can't be blank"))
          input = Domain::Fertilize::Dtos::FertilizeCreateInput.new(name: "Test")

          assert_raises StandardError do
            build_interactor(gateway: gateway, user_lookup: FakeUserLookup.new(user: user)).call(input)
          end
        end

        test "calls on_failure when the user cannot be resolved" do
          gateway = FakeGateway.new(entity: Object.new)
          input = Domain::Fertilize::Dtos::FertilizeCreateInput.new(name: "X")
          user_lookup = FakeUserLookup.new(error: Domain::Shared::Exceptions::RecordNotFound.new("User not found"))

          build_interactor(gateway: gateway, user_lookup: user_lookup).call(input)

          assert_nil @output_port.success
          assert_instance_of Domain::Shared::Dtos::Error, @output_port.failure
          assert_nil gateway.received, "gateway must not be reached when the user is missing"
        end

        private

        def build_interactor(gateway:, user_lookup:)
          FertilizeCreateInteractor.new(
            output_port: @output_port,
            user_id: 1,
            gateway: gateway,
            translator: @translator,
            user_lookup: user_lookup
          )
        end
      end
    end
  end
end
