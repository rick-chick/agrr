# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanActiveRecordGateway < Domain::CultivationPlan::Gateways::CultivationPlanGateway
        def create(create_dto)
          # CultivationPlanCreatorを使って計画を作成
          creator = CultivationPlanCreator.new(
            farm: create_dto.farm,
            total_area: create_dto.total_area,
            crops: create_dto.crops,
            user: create_dto.user,
            plan_type: 'private',
            plan_name: create_dto.plan_name,
            planning_start_date: Date.current.beginning_of_year,
            planning_end_date: Date.new(Date.current.year + 1, 12, 31)
          )

          result = creator.call
          unless result.success?
            raise StandardError, result.errors.join(', ')
          end

          result
        end

        def find_existing(farm, user)
          ::CultivationPlan.where(farm: farm, user: user, plan_type: 'private').first
        end

        def find_farm(farm_id, user)
          ::Farm.find_by(id: farm_id, user: user)
        end

        def find_crops(crop_ids, user)
          ::Crop.where(id: crop_ids, user: user, is_reference: false).to_a
        end

        def find_by_id(plan_id, user)
          plan = ::CultivationPlan.find(plan_id)
          plan
        end

        # 栽培計画を削除し、DeletionUndo::Manager を使用して Undo トークンを返す
        #
        # @param plan_id [Integer] 削除する計画のID
        # @param user [User] 削除を実行するユーザー（所有権チェックに使用）
        # @return [DeletionUndoEvent] DeletionUndo::Manager.schedule が返すイベント
        # @raise [StandardError] 削除に失敗した場合（RecordNotFound, InvalidForeignKey, DeleteRestrictionError, DeletionUndo::Error 等）
        def destroy(plan_id, user)
          plan_model = PlanPolicy.find_private_owned!(user, plan_id)

          DeletionUndo::Manager.schedule(
            record: plan_model,
            actor: user,
            toast_message: I18n.t('plans.undo.toast', name: plan_model.display_name)
          )
        rescue PolicyPermissionDenied
          raise StandardError, I18n.t('plans.errors.not_found')
        rescue ActiveRecord::RecordNotFound
          raise StandardError, I18n.t('plans.errors.not_found')
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
          raise StandardError, I18n.t('plans.errors.delete_failed')
        rescue DeletionUndo::Error => e
          raise StandardError, I18n.t('plans.errors.delete_error', message: e.message)
        end
      end
    end
  end
end
