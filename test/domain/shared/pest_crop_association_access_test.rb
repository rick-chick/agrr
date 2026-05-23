# frozen_string_literal: true

require "domain_lib_test_helper"

class DomainSharedPestCropAssociationAccessTest < DomainLibTestCase
  CropStub = Struct.new(:is_reference, :user_id, :region, keyword_init: true) do
    def is_reference?
      is_reference
    end
  end

  PestStub = Struct.new(:is_reference, :user_id, :region, keyword_init: true) do
    def is_reference?
      is_reference
    end
  end

  test "reference pest may link only to reference crop" do
    crop = CropStub.new(is_reference: false, user_id: 1, region: nil)
    pest = PestStub.new(is_reference: true, user_id: nil, region: nil)

    assert_not Domain::Shared::PestCropAssociationAccess.crop_accessible_for_pest?(crop, pest, user: domain_user_stub(id: 1))
  end

  test "user pest may link to reference crop" do
    crop = CropStub.new(is_reference: true, user_id: nil, region: nil)
    pest = PestStub.new(is_reference: false, user_id: 1, region: nil)

    assert Domain::Shared::PestCropAssociationAccess.crop_accessible_for_pest?(crop, pest, user: domain_user_stub(id: 1))
  end

  test "user pest may link to owned non-reference crop" do
    crop = CropStub.new(is_reference: false, user_id: 1, region: nil)
    pest = PestStub.new(is_reference: false, user_id: 1, region: nil)

    assert Domain::Shared::PestCropAssociationAccess.crop_accessible_for_pest?(crop, pest, user: domain_user_stub(id: 1))
  end

  test "user pest may not link to another users crop" do
    crop = CropStub.new(is_reference: false, user_id: 2, region: nil)
    pest = PestStub.new(is_reference: false, user_id: 1, region: nil)

    assert_not Domain::Shared::PestCropAssociationAccess.crop_accessible_for_pest?(crop, pest, user: domain_user_stub(id: 1))
  end
end
