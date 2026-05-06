# frozen_string_literal: true

module Adapters
  module Backdoor
    module Gateways
      # Backdoor API のユーザー一覧・作成・更新・DB 統計（ActiveRecord はこのゲートウェイ内のみ）。
      class BackdoorDiagnosticsActiveRecordGateway
        def users_list_payload
          users = ::User.where(is_anonymous: false).order(created_at: :desc)
          {
            total_users: users.count,
            users: users.map { |user| user_summary_hash(user) }
          }
        end

        def create_user(attrs)
          user = ::User.new(attrs.merge(is_anonymous: false))
          if user.save
            { ok: true, user: user_detail_hash(user) }
          else
            { ok: false, errors: user.errors.full_messages }
          end
        end

        def update_user(id, attrs)
          user = ::User.find_by(id: id)
          return { ok: false, error: :not_found } unless user

          if user.update(attrs)
            { ok: true, user: user_detail_hash(user) }
          else
            { ok: false, errors: user.errors.full_messages }
          end
        end

        def db_stats_counts
          {
            users: ::User.where(is_anonymous: false).count,
            anonymous_users: ::User.where(is_anonymous: true).count,
            farms: ::Farm.count,
            fields: ::Field.count,
            crops: ::Crop.count,
            cultivation_plans: ::CultivationPlan.count,
            interaction_rules: ::InteractionRule.count,
            pesticides: ::Pesticide.count,
            pests: ::Pest.count,
            fertilizes: ::Fertilize.count,
            agricultural_tasks: ::AgriculturalTask.count,
            sessions: ::Session.count
          }
        end

        private

        def user_summary_hash(user)
          {
            id: user.id,
            email: user.email,
            name: user.name,
            google_id: user.google_id,
            admin: user.admin?,
            avatar_url: user.avatar_url,
            created_at: user.created_at.iso8601,
            updated_at: user.updated_at.iso8601,
            farms_count: user.farms.count,
            plans_count: user.cultivation_plans.count
          }
        end

        def user_detail_hash(user)
          {
            id: user.id,
            email: user.email,
            name: user.name,
            google_id: user.google_id,
            admin: user.admin?,
            avatar_url: user.avatar_url,
            created_at: user.created_at.iso8601,
            updated_at: user.updated_at.iso8601
          }
        end
      end
    end
  end
end
