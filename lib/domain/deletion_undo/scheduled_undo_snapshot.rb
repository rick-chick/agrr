# frozen_string_literal: true

module Domain
  module DeletionUndo
    # スケジュール済み Undo（Entity / ActiveRecord 等）から HTTP 応答組み立てに必要な値だけを取り出すスナップショット
    class ScheduledUndoSnapshot
      attr_reader :undo_token, :metadata, :toast_message, :auto_hide_after, :resource_type, :resource_id

      def self.from(scheduled_undo)
        md = scheduled_undo.respond_to?(:metadata) ? scheduled_undo.metadata : {}
        md =
          case md
          when Hash
            Hash[md.map { |k, v| [k.to_s, v] }]
          else
            md.to_h.map { |k, v| [k.to_s, v] }.to_h
          end

        new(
          undo_token: scheduled_undo.undo_token,
          metadata: md,
          toast_message: scheduled_undo.toast_message,
          auto_hide_after: scheduled_undo.auto_hide_after,
          resource_type: scheduled_undo.respond_to?(:resource_type) ? scheduled_undo.resource_type : nil,
          resource_id: scheduled_undo.respond_to?(:resource_id) ? scheduled_undo.resource_id : nil
        )
      end

      def initialize(undo_token:, metadata:, toast_message:, auto_hide_after:, resource_type:, resource_id:)
        @undo_token = undo_token
        @metadata = metadata || {}
        @toast_message = toast_message
        @auto_hide_after = auto_hide_after
        @resource_type = resource_type
        @resource_id = resource_id
      end
    end
  end
end
