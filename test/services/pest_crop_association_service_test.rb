# frozen_string_literal: true

require 'test_helper'

class PestCropAssociationServiceTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @pest = create(:pest, is_reference: false, user: @user)
    @crop1 = create(:crop, is_reference: false, user: @user)
    @crop2 = create(:crop, is_reference: false, user: @user)
    @other_user_crop = create(:crop, is_reference: false, user: create(:user))
  end

  test "associate_crops associates accessible crops" do
    count = PestCropAssociationService.associate_crops(@pest, [@crop1.id, @crop2.id], user: @user)

    assert_equal 2, count
    assert_includes @pest.crops, @crop1
    assert_includes @pest.crops, @crop2
  end

  test "associate_crops does not associate inaccessible crops" do
    count = PestCropAssociationService.associate_crops(@pest, [@crop1.id, @other_user_crop.id], user: @user)

    assert_equal 1, count
    assert_includes @pest.crops, @crop1
    assert_not_includes @pest.crops, @other_user_crop
  end

  test "associate_crops does not duplicate existing associations" do
    @pest.crops << @crop1

    count = PestCropAssociationService.associate_crops(@pest, [@crop1.id, @crop2.id], user: @user)

    assert_equal 1, count
    assert_equal 2, @pest.crops.count
  end

  test "update_crop_associations adds new associations and removes old ones" do
    @pest.crops << @crop1

    result = PestCropAssociationService.update_crop_associations(@pest, [@crop2.id], user: @user)

    assert_equal 1, result[:added]
    assert_equal 1, result[:removed]
    assert_not_includes @pest.crops, @crop1
    assert_includes @pest.crops, @crop2
  end

  test "normalize_crop_ids filters to accessible crop IDs only" do
    normalized = PestCropAssociationService.normalize_crop_ids(@pest, [@crop1.id, @other_user_crop.id, 99999], user: @user)

    assert_includes normalized, @crop1.id
    assert_not_includes normalized, @other_user_crop.id
    assert_not_includes normalized, 99999
  end

  test "normalize_crop_ids handles string IDs" do
    normalized = PestCropAssociationService.normalize_crop_ids(@pest, [@crop1.id.to_s, @crop2.id.to_s], user: @user)

    assert_includes normalized, @crop1.id
    assert_includes normalized, @crop2.id
  end

  test "accessible_crops_scope delegates to policy" do
    scope = PestCropAssociationService.accessible_crops_scope(@pest, user: @user)

    assert_kind_of ActiveRecord::Relation, scope
    assert_includes scope, @crop1
    assert_includes scope, @crop2
  end
end
