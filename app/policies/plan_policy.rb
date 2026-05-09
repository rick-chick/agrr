# frozen_string_literal: true

# レガシー名のまま Domain::CultivationPlan::Policies::PlanAccess へ委譲
class PlanPolicy
  def self.private_scope(user)
    Domain::CultivationPlan::Policies::PlanAccess.private_scope(user)
  end

  def self.find_private_owned!(user, id)
    Domain::CultivationPlan::Policies::PlanAccess.find_private_owned!(user, id)
  end

  def self.public_scope
    Domain::CultivationPlan::Policies::PlanAccess.public_scope
  end

  def self.find_public!(id)
    Domain::CultivationPlan::Policies::PlanAccess.find_public!(id)
  end
end
