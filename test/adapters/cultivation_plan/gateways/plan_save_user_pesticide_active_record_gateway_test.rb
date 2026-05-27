# frozen_string_literal: true

require "test_helper"

module Adapters
  module CultivationPlan
    module Gateways
      class PlanSaveUserPesticideActiveRecordGatewayTest < ActiveSupport::TestCase
        setup do
          @gateway = PlanSaveUserPesticideActiveRecordGateway.new
          @user = User.create!(
            email: "plan-save-pz-#{SecureRandom.hex(4)}@example.com",
            name: "Pesticide GW User",
            google_id: "plan-save-pz-#{SecureRandom.hex(8)}"
          )
          @crop = create(:crop, :reference)
          @pest = create(:pest, :reference, region: "jp")
          @reference = ::Pesticide.create!(
            user: nil,
            crop: @crop,
            pest: @pest,
            name: "参照農薬#{SecureRandom.hex(4)}",
            is_reference: true,
            region: "jp"
          )
        end

        test "find_by_user_id_and_source_pesticide_id returns nil when missing" do
          assert_nil @gateway.find_by_user_id_and_source_pesticide_id(
            user_id: @user.id,
            source_pesticide_id: @reference.id
          )
        end

        test "create without children returns PlanSaveUserPesticideSnapshot" do
          user_crop = create(:crop, :user_owned, user: @user, source_crop_id: @crop.id)
          user_pest = create(:pest, :user_owned, user: @user, source_pest_id: @pest.id)
          copy_name = "ユーザー農薬#{SecureRandom.hex(4)}"

          created = @gateway.create(
            user_id: @user.id,
            attributes: {
              crop_id: user_crop.id,
              pest_id: user_pest.id,
              name: copy_name,
              is_reference: false,
              region: "jp",
              source_pesticide_id: @reference.id
            }
          )

          assert_instance_of Domain::CultivationPlan::Dtos::PlanSaveUserPesticideSnapshot, created
          assert_equal copy_name, created.name

          found = @gateway.find_by_user_id_and_source_pesticide_id(
            user_id: @user.id,
            source_pesticide_id: @reference.id
          )
          assert_equal created.id, found.id
        end

        test "create with children persists in one transaction" do
          ref = create(:pesticide, :reference, :complete, crop: @crop, pest: @pest, region: "jp")
          user_crop = create(:crop, :user_owned, user: @user, source_crop_id: @crop.id)
          user_pest = create(:pest, :user_owned, user: @user, source_pest_id: @pest.id)
          constraint = ref.pesticide_usage_constraint
          detail = ref.pesticide_application_detail

          created = @gateway.create(
            user_id: @user.id,
            attributes: {
              crop_id: user_crop.id,
              pest_id: user_pest.id,
              name: "子付き農薬#{SecureRandom.hex(4)}",
              is_reference: false,
              region: "jp",
              source_pesticide_id: ref.id
            },
            usage_constraint_attributes: {
              min_temperature: constraint.min_temperature,
              max_temperature: constraint.max_temperature
            },
            application_detail_attributes: {
              dilution_ratio: detail.dilution_ratio,
              amount_per_m2: detail.amount_per_m2,
              amount_unit: detail.amount_unit
            }
          )

          record = ::Pesticide.find(created.id)
          assert_not_nil record.pesticide_usage_constraint
          assert_not_nil record.pesticide_application_detail
          assert_equal constraint.min_temperature, record.pesticide_usage_constraint.min_temperature
          assert_equal detail.dilution_ratio, record.pesticide_application_detail.dilution_ratio
        end
      end
    end
  end
end
