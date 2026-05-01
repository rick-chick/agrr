# frozen_string_literal: true

require "test_helper"

module Domain
  module DeletionUndo
    module Entities
      class DeletionUndoEntityTest < ActiveSupport::TestCase
        setup do
          @expires_at = Time.zone.parse("2026-05-01 12:00:00")
        end

        test "expired? is true when now is after expires_at" do
          entity = DeletionUndoEntity.new(
            id: "tok",
            expires_at: @expires_at,
            status: "scheduled",
            metadata: {}
          )

          assert entity.expired?(now: @expires_at + 1.second)
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

          refute entity.expired?(now: @expires_at - 1.second)
        end
      end
    end
  end
end
