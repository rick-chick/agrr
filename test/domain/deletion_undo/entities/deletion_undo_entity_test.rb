# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module DeletionUndo
    module Entities
      class DeletionUndoEntityTest < DomainLibTestCase
        setup do
          @expires_at = Time.utc(2026, 5, 1, 12, 0, 0)
        end

        test "expired? is true when now is after expires_at" do
          entity = DeletionUndoEntity.new(
            id: "tok",
            expires_at: @expires_at,
            status: "scheduled",
            metadata: {}
          )

          assert entity.expired?(now: @expires_at + 1)
        end

        test "expired? is false when now equals expires_at" do
          entity = DeletionUndoEntity.new(
            id: "tok",
            expires_at: @expires_at,
            status: "scheduled",
            metadata: {}
          )

          refute entity.expired?(now: @expires_at)
        end

        test "expired? is false when now is before expires_at" do
          entity = DeletionUndoEntity.new(
            id: "tok",
            expires_at: @expires_at,
            status: "scheduled",
            metadata: {}
          )

          refute entity.expired?(now: @expires_at - 1)
        end
      end
    end
  end
end
