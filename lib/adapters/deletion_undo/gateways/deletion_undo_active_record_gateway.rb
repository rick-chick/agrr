# frozen_string_literal: true

module Adapters
  module DeletionUndo
    module Gateways
      class DeletionUndoActiveRecordGateway < Domain::DeletionUndo::Gateways::DeletionUndoGateway
        # Interactor 経由で Undo スケジュールされうるモデル（任意 constantize 禁止のため明示列挙）
        SCHEDULABLE_CLASS_BY_TYPE = {
          "AgriculturalTask" => ::AgriculturalTask,
          "Crop" => ::Crop,
          "CultivationPlan" => ::CultivationPlan,
          "Farm" => ::Farm,
          "Fertilize" => ::Fertilize,
          "Field" => ::Field,
          "InteractionRule" => ::InteractionRule,
          "Pest" => ::Pest,
          "Pesticide" => ::Pesticide,
          "TaskScheduleItem" => ::TaskScheduleItem
        }.freeze

        def find_by_token(undo_token)
          model = ::DeletionUndoEvent.find_by(id: undo_token)
          raise Domain::DeletionUndo::Exceptions::DeletionUndoNotFoundError unless model

          build_entity(model)
        end

        def expire_if_needed(event_id)
          model = ::DeletionUndoEvent.find_by(id: event_id)
          raise Domain::DeletionUndo::Exceptions::DeletionUndoNotFoundError unless model

          model.expire_if_needed!
          build_entity(model)
        end

        def perform_restore(event_id)
          ActiveRecord::Base.transaction do
            model = ::DeletionUndoEvent.lock.find_by(id: event_id)
            raise Domain::DeletionUndo::Exceptions::DeletionUndoNotFoundError unless model

            ::DeletionUndo::SnapshotRestorer.new(model.snapshot).restore!
            model.mark_restored!
          end
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique => e
          raise Domain::DeletionUndo::Exceptions::DeletionUndoRestoreConflictError, e.message
        end

        def mark_failed(event_id, error_message)
          model = ::DeletionUndoEvent.find_by(id: event_id)
          return unless model # 見つからない場合は何もしない

          model.mark_failed!(error_message: error_message)
          build_entity(model)
        end

        def schedule(resource_type:, resource_id:, actor_id: nil, toast_message: nil, auto_hide_after: nil,
                     metadata: {}, validate_before_schedule: false)
          record = resolve_schedulable_record!(resource_type, resource_id)
          ensure_schedule_authorized!(record, actor_id)
          ar_actor = Adapters::Shared::UserActorResolver.user_for_deleted_by(
            actor_id.present? ? ::User.find_by(id: actor_id) : nil
          )
          ActiveRecord::Base.transaction do
            record.validate! if validate_before_schedule
            snapshot = ::DeletionUndo::SnapshotBuilder.new(record).build

            event = ::DeletionUndoEvent.create!(
              resource_type: record.class.name,
              resource_id: record.id.to_s,
              snapshot: snapshot,
              metadata: build_metadata(record, toast_message, auto_hide_after, metadata),
              deleted_by: ar_actor,
              expires_at: Time.current + default_ttl
            )

            record.destroy!

            build_entity(event)
          end
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed, ActiveRecord::RecordNotSaved => e
          errors_like = e.respond_to?(:record) && e.record.respond_to?(:errors) ? e.record.errors : nil
          raise Domain::Shared::Exceptions::RecordInvalid.new(
            e.message,
            errors: Domain::Shared::ValidationErrors.from_errors_like(errors_like)
          )
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError => e
          raise Domain::Shared::Exceptions::AssociationInUse, e.message
        end

        private

        def ensure_schedule_authorized!(record, actor_id)
          user = ::User.find_by(id: actor_id)
          raise Domain::Shared::Policies::PolicyPermissionDenied unless user

          allowed = Domain::DeletionUndo::ScheduleAuthorization.schedule_allowed?(user, record)

          raise Domain::Shared::Policies::PolicyPermissionDenied unless allowed
        end

        def resolve_schedulable_record!(resource_type, resource_id)
          klass = SCHEDULABLE_CLASS_BY_TYPE[resource_type]
          unless klass
            raise Domain::Shared::Exceptions::RecordInvalid.new("Invalid schedulable type")
          end

          record = klass.find_by(id: resource_id)
          unless record&.persisted?
            raise Domain::Shared::Exceptions::RecordInvalid.new("Schedulable record not found")
          end

          record
        end

        def build_entity(model)
          Domain::DeletionUndo::Entities::DeletionUndoEntity.new(
            id: model.id,
            expires_at: model.expires_at,
            status: model.state,
            metadata: model.metadata || {}
          )
        end

        def default_ttl
          seconds = ENV.fetch("DELETION_UNDO_TTL_SECONDS", nil)&.to_i
          seconds && seconds.positive? ? seconds.seconds : 5.minutes
        end

        # resource_dom_id は削除直前の AR から生成（Interactor / Domain に ActionView を置かない）。
        def build_metadata(record, toast_message, auto_hide_after, metadata)
          metadata = metadata.to_h.with_indifferent_access
          metadata[:toast_message] ||= toast_message || default_toast_message(record)
          metadata[:resource_label] ||= default_resource_label(record)
          metadata[:auto_hide_after] ||= auto_hide_after if auto_hide_after
          metadata[:undo_deadline] = (Time.current + default_ttl).iso8601
          metadata[:resource_dom_id] ||= ActionView::RecordIdentifier.dom_id(record)
          metadata
        end

        def default_toast_message(record)
          I18n.t(
            "deletion_undo.toast_message",
            resource: default_resource_label(record)
          )
        end

        def default_resource_label(record)
          if record.respond_to?(:display_name)
            record.display_name
          elsif record.respond_to?(:name)
            record.name
          else
            "#{record.class.model_name.human} ##{record.id}"
          end
        end
      end
    end
  end
end
