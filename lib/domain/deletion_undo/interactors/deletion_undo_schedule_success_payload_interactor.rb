# frozen_string_literal: true

module Domain
  module DeletionUndo
    module Interactors
      class DeletionUndoScheduleSuccessPayloadInteractor
        def initialize(output_port:, logger:)
          @output_port = output_port
          @logger = logger
        end

        def call(snapshot)
          if snapshot.undo_token.blank?
            @logger&.error(
              "[DeletionUndo] Missing undo_token for #{snapshot.resource_type || 'unknown'}#" \
              "#{snapshot.resource_id || 'unknown'}"
            )
            @output_port.on_failure(
              Domain::DeletionUndo::Dtos::DeletionUndoSchedulePayloadFailureDto.new(reason: :missing_undo_token)
            )
            return
          end

          resource_dom_id = compute_resource_dom_id(snapshot)
          resource_label = snapshot.metadata["resource_label"]

          @output_port.on_success(
            Domain::DeletionUndo::Dtos::DeletionUndoScheduleSuccessPayloadDto.new(
              undo_token: snapshot.undo_token,
              undo_deadline: snapshot.metadata["undo_deadline"],
              toast_message: snapshot.toast_message,
              auto_hide_after: snapshot.auto_hide_after,
              resource_label: resource_label,
              resource_dom_id: resource_dom_id
            )
          )
        end

        private

        def compute_resource_dom_id(snapshot)
          stored = snapshot.metadata["resource_dom_id"]
          return stored if stored.present?
          return nil unless snapshot.resource_type.present? && snapshot.resource_id.present?

          [
            snapshot.resource_type.to_s.demodulize.underscore,
            snapshot.resource_id.to_s
          ].join("_")
        end
      end
    end
  end
end
