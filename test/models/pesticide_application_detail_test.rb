# frozen_string_literal: true

require "test_helper"

class PesticideApplicationDetailTest < ActiveSupport::TestCase
  setup do
    @pesticide = create(:pesticide)
  end

  test "should belong to pesticide" do
    detail = create(:pesticide_application_detail, pesticide: @pesticide)
    assert_equal @pesticide, detail.pesticide
  end

  test "should validate pesticide presence" do
    detail = PesticideApplicationDetail.new
    assert_not detail.valid?
    assert_includes detail.errors[:pesticide], "を入力してください"
  end

  test "should validate amount_per_m2 is greater than or equal to 0" do
    detail = build(:pesticide_application_detail, pesticide: @pesticide, amount_per_m2: -1.0)
    assert_not detail.valid?
    assert_includes detail.errors[:amount_per_m2], "は0以上の値にしてください"
  end

  test "should validate amount_unit requires amount_per_m2" do
    detail = build(:pesticide_application_detail, 
                   pesticide: @pesticide, 
                   amount_unit: "ml", 
                   amount_per_m2: nil)
    assert_not detail.valid?
    assert_includes detail.errors[:amount_unit], "requires amount_per_m2"
  end

  test "should validate amount_per_m2 requires amount_unit" do
    detail = build(:pesticide_application_detail, 
                   pesticide: @pesticide, 
                   amount_per_m2: 0.1, 
                   amount_unit: nil)
    assert_not detail.valid?
    assert_includes detail.errors[:amount_per_m2], "requires amount_unit"
  end

  test "should allow both amount_per_m2 and amount_unit present" do
    detail = build(:pesticide_application_detail, 
                   pesticide: @pesticide, 
                   amount_per_m2: 0.1, 
                   amount_unit: "ml")
    assert detail.valid?
  end

  test "should allow both amount_per_m2 and amount_unit nil" do
    detail = build(:pesticide_application_detail, 
                   pesticide: @pesticide, 
                   amount_per_m2: nil, 
                   amount_unit: nil)
    assert detail.valid?
  end

  test "should allow nil for optional fields" do
    detail = build(:pesticide_application_detail, 
                   pesticide: @pesticide,
                   dilution_ratio: nil,
                   amount_per_m2: nil,
                   amount_unit: nil,
                   application_method: nil)
    assert detail.valid?
  end

  test "should destroy when pesticide is destroyed" do
    detail = create(:pesticide_application_detail, pesticide: @pesticide)
    detail_id = detail.id

    @pesticide.destroy

    assert_not PesticideApplicationDetail.exists?(detail_id)
  end
end

