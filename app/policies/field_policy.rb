# frozen_string_literal: true

# レガシー名のまま Domain::Field::Policies::FieldAccess へ委譲
class FieldPolicy
  def self.scope_for_farm(user, farm)
    Domain::Field::Policies::FieldAccess.scope_for_farm(user, farm)
  end

  def self.find_owned!(user, id)
    Domain::Field::Policies::FieldAccess.find_owned!(user, id)
  end

  def self.build_for_create(user, farm, attrs)
    Domain::Field::Policies::FieldAccess.build_for_create(user, farm, attrs)
  end
end
