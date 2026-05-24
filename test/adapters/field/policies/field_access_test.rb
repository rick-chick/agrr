# frozen_string_literal: true

require "test_helper"

class Domain::Field::Policies::FieldAccessTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @other = create(:user)
    @farm = create(:farm, user: @user)
    @field = create(:field, farm: @farm, user: @user)
    @admin = create(:user, :admin)
  end

  test "find_owned! returns field for farm owner" do
    field = Domain::Field::Policies::FieldAccess.find_owned!(@user, @field.id)

    assert_equal @field.id, field.id
  end

  test "find_owned! allows admin" do
    other_farm = create(:farm, user: @other)
    other_field = create(:field, farm: other_farm, user: @other)

    field = Domain::Field::Policies::FieldAccess.find_owned!(@admin, other_field.id)

    assert_equal other_field.id, field.id
  end

  test "find_owned! raises PolicyPermissionDenied for non-owner non-admin" do
    other_farm = create(:farm, user: @other)
    other_field = create(:field, farm: other_farm, user: @other)

    assert_raises(Domain::Shared::Policies::PolicyPermissionDenied) do
      Domain::Field::Policies::FieldAccess.find_owned!(@user, other_field.id)
    end
  end

  test "assert_farm_fields_list_allowed! passes for farm owner" do
    farm_entity = stub(user_id: @user.id, is_reference: false)

    assert_nothing_raised do
      Domain::Field::Policies::FieldAccess.assert_farm_fields_list_allowed!(@user, farm_entity)
    end
  end

  test "assert_farm_fields_list_allowed! raises for other users farm" do
    farm_entity = stub(user_id: @other.id, is_reference: false)

    assert_raises(Domain::Shared::Policies::PolicyPermissionDenied) do
      Domain::Field::Policies::FieldAccess.assert_farm_fields_list_allowed!(@user, farm_entity)
    end
  end
end
