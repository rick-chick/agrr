# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module DeletionUndo
    module Interactors
      class DeletionUndoRestoreInteractorTest < DomainLibTestCase
        setup do
          @undo_token = "undo-token-1"
          @expires_at = Time.utc(2026, 5, 1, 12, 0, 0)
          @input_dto = Domain::DeletionUndo::Dtos::DeletionUndoRestoreInput.new(
            undo_token: @undo_token
          )
        end

        test "calls on_success when event is scheduled and not expired for clock.now" do
          frozen_now = @expires_at - 60
          clock = Object.new
          clock.define_singleton_method(:now) { frozen_now }

          entity = Domain::DeletionUndo::Entities::DeletionUndoEntity.new(
            id: @undo_token,
            expires_at: @expires_at,
            status: "scheduled",
            metadata: {}
          )

          gateway = Minitest::Mock.new
          gateway.expect(:find_by_token, entity, [ @undo_token ])
          gateway.expect(:perform_restore, nil, [ entity.id ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) do |dto|
            received = dto
          end

          interactor = DeletionUndoRestoreInteractor.new(
            output_port: output_port,
            gateway: gateway,
            clock: clock
          )
          interactor.call(@input_dto)

          assert_instance_of Domain::DeletionUndo::Dtos::DeletionUndoRestoreOutput, received
          assert_equal "restored", received.status
          assert_equal @undo_token, received.undo_token

          gateway.verify
          output_port.verify
        end

        test "calls expire_if_needed and on_failure when event is expired for clock.now" do
          frozen_now = @expires_at + 60
          clock = Object.new
          clock.define_singleton_method(:now) { frozen_now }

          entity = Domain::DeletionUndo::Entities::DeletionUndoEntity.new(
            id: @undo_token,
            expires_at: @expires_at,
            status: "scheduled",
            metadata: {}
          )

          gateway = Minitest::Mock.new
          gateway.expect(:find_by_token, entity, [ @undo_token ])
          gateway.expect(:expire_if_needed, nil, [ entity.id ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) do |dto|
            received = dto
          end

          interactor = DeletionUndoRestoreInteractor.new(
            output_port: output_port,
            gateway: gateway,
            clock: clock
          )
          interactor.call(@input_dto)

          assert_instance_of Domain::Shared::Dtos::Error, received
          assert_includes received.message, "expired"

          gateway.verify
          output_port.verify
        end

        test "calls mark_failed and on_failure when event is not scheduled but not expired for clock.now" do
          frozen_now = @expires_at - 60
          clock = Object.new
          clock.define_singleton_method(:now) { frozen_now }

          entity = Domain::DeletionUndo::Entities::DeletionUndoEntity.new(
            id: @undo_token,
            expires_at: @expires_at,
            status: "restored",
            metadata: {}
          )

          gateway = Minitest::Mock.new
          gateway.expect(:find_by_token, entity, [ @undo_token ])
          gateway.expect(:mark_failed, nil, [ entity.id, "Token expired" ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) do |dto|
            received = dto
          end

          interactor = DeletionUndoRestoreInteractor.new(
            output_port: output_port,
            gateway: gateway,
            clock: clock
          )
          interactor.call(@input_dto)

          assert_instance_of Domain::Shared::Dtos::Error, received

          gateway.verify
          output_port.verify
        end
      end
    end
  end
end
