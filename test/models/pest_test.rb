# frozen_string_literal: true

require "test_helper"

class PestTest < ActiveSupport::TestCase
  # バリデーションテスト

  test "should validate name presence" do
    pest = Pest.new
    assert_not pest.valid?
    assert_includes pest.errors[:name], "を入力してください"
  end

  test "should validate is_reference inclusion" do
    pest = Pest.new(name: "テスト害虫", is_reference: nil)
    assert_not pest.valid?
    assert_includes pest.errors[:is_reference], "は一覧にありません"
  end

  test "should validate user presence when is_reference is false" do
    pest = Pest.new(name: "テスト害虫", is_reference: false, user_id: nil)
    assert_not pest.valid?
    assert_includes pest.errors[:user], "を入力してください"
  end

  test "should allow nil user_id when is_reference is true" do
    pest = Pest.new(name: "テスト害虫", is_reference: true, user_id: nil)
    assert pest.valid?
  end

  test "should not allow user for reference pests" do
    user = create(:user)
    pest = Pest.new(name: "参照害虫", is_reference: true, user: user)
    pest.valid?

    assert_includes pest.errors[:user], "は参照データには設定できません"
  end

  test "should allow user_id when is_reference is false" do
    user = create(:user)
    pest = Pest.new(name: "テスト害虫", is_reference: false, user_id: user.id)
    assert pest.valid?
  end

  test "should require user_id when is_reference changes from true to false" do
    user = create(:user)
    pest = create(:pest, is_reference: true, user_id: nil)

    pest.is_reference = false
    assert_not pest.valid?
    assert_includes pest.errors[:user], "を入力してください"

    pest.user_id = user.id
    assert pest.valid?
  end

  test "should enforce uniqueness of source_pest_id per user" do
    user = create(:user)
    reference = create(:pest, is_reference: true)

    create(:pest, :user_owned, user: user, source_pest_id: reference.id)

    duplicated = build(:pest, :user_owned, user: user, source_pest_id: reference.id)
    assert_not duplicated.valid?
    assert_includes duplicated.errors[:source_pest_id], "はすでに存在します"

    another_user = create(:user)
    other = build(:pest, :user_owned, user: another_user, source_pest_id: reference.id)
    assert other.valid?
  end


  # スコープテスト
  test "reference scope should return reference pests" do
    reference_pest = create(:pest, is_reference: true, user_id: nil)
    user = create(:user)
    user_pest = create(:pest, :user_owned, user: user)

    reference_pests = Pest.reference

    assert_includes reference_pests, reference_pest
    assert_not_includes reference_pests, user_pest
  end

  test "user_owned scope should return only user-owned pests" do
    user = create(:user)
    reference_pest = create(:pest, is_reference: true, user_id: nil)
    user_pest = create(:pest, :user_owned, user: user)

    user_owned_pests = Pest.user_owned

    assert_includes user_owned_pests, user_pest
    assert_not_includes user_owned_pests, reference_pest
  end

  test "recent scope should order by created_at desc" do
    pest1 = create(:pest, created_at: 2.days.ago)
    pest2 = create(:pest, created_at: 1.day.ago)
    pest3 = create(:pest, created_at: Time.current)

    recent = Pest.recent.limit(3)

    assert_equal pest3.id, recent.first.id
    assert_equal pest2.id, recent.second.id
    assert_equal pest1.id, recent.third.id
  end
end
