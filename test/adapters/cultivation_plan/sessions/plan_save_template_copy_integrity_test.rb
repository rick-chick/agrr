# frozen_string_literal: true

require "test_helper"

module Adapters
  module CultivationPlan
    module Sessions
      class PlanSaveTemplateCopyIntegrityTest < ActiveSupport::TestCase
        test "fertilize_records_for_template_copy returns persisted records in id order" do
          user = User.create!(
            email: "integrity-fert-#{SecureRandom.hex(4)}@example.com",
            name: "Integrity User",
            google_id: "integrity-fert-#{SecureRandom.hex(8)}"
          )
          second = user.fertilizes.create!(
            name: "肥料B#{SecureRandom.hex(4)}",
            n: 1,
            p: 1,
            k: 1,
            is_reference: false,
            region: "jp"
          )
          first = user.fertilizes.create!(
            name: "肥料A#{SecureRandom.hex(4)}",
            n: 2,
            p: 2,
            k: 2,
            is_reference: false,
            region: "jp"
          )

          records = PlanSaveTemplateCopyIntegrity.fertilize_records_for_template_copy(
            ids: [ first.id, second.id ]
          )

          assert_equal [ first.id, second.id ], records.map(&:id)
          assert records.all?(&:persisted?)
        end

        test "fertilize_records_for_template_copy raises when id is missing" do
          error = assert_raises(RuntimeError) do
            PlanSaveTemplateCopyIntegrity.fertilize_records_for_template_copy(ids: [ 9_999_999_999 ])
          end
          assert_match(/not found or not persisted/, error.message)
        end

        test "field_records_for_template_copy scopes to user and preserves order" do
          owner = User.create!(
            email: "integrity-field-#{SecureRandom.hex(4)}@example.com",
            name: "Field Owner",
            google_id: "integrity-field-#{SecureRandom.hex(8)}"
          )
          other = User.create!(
            email: "integrity-field-other-#{SecureRandom.hex(4)}@example.com",
            name: "Other",
            google_id: "integrity-field-other-#{SecureRandom.hex(8)}"
          )
          farm = ::Farm.create!(
            user: owner,
            name: "F",
            latitude: 35.0,
            longitude: 135.0,
            region: "jp",
            is_reference: false
          )
          second = farm.fields.create!(user: owner, name: "B", area: 2.0)
          first = farm.fields.create!(user: owner, name: "A", area: 1.0)
          other_field = ::Farm.create!(
            user: other,
            name: "OF",
            latitude: 35.0,
            longitude: 135.0,
            region: "jp",
            is_reference: false
          ).fields.create!(user: other, name: "X", area: 1.0)

          records = PlanSaveTemplateCopyIntegrity.field_records_for_template_copy(
            ids: [ first.id, second.id ],
            user_id: owner.id
          )

          assert_equal [ first.id, second.id ], records.map(&:id)

          error = assert_raises(RuntimeError) do
            PlanSaveTemplateCopyIntegrity.field_records_for_template_copy(
              ids: [ other_field.id ],
              user_id: owner.id
            )
          end
          assert_match(/Field record not found/, error.message)
        end

        test "crop_records_for_template_copy preserves id order" do
          user = User.create!(
            email: "integrity-crop-#{SecureRandom.hex(4)}@example.com",
            name: "Crop Integrity",
            google_id: "integrity-crop-#{SecureRandom.hex(8)}"
          )
          second = user.crops.create!(
            name: "作物B#{SecureRandom.hex(4)}",
            variety: "v",
            is_reference: false,
            area_per_unit: 0.2,
            revenue_per_area: 100.0,
            region: "jp"
          )
          first = user.crops.create!(
            name: "作物A#{SecureRandom.hex(4)}",
            variety: "v",
            is_reference: false,
            area_per_unit: 0.2,
            revenue_per_area: 100.0,
            region: "jp"
          )

          records = PlanSaveTemplateCopyIntegrity.crop_records_for_template_copy(
            ids: [ first.id, second.id ]
          )

          assert_equal [ first.id, second.id ], records.map(&:id)
        end

        test "pest_records_for_template_copy preserves id order" do
          user = User.create!(
            email: "integrity-pest-#{SecureRandom.hex(4)}@example.com",
            name: "Pest Integrity",
            google_id: "integrity-pest-#{SecureRandom.hex(8)}"
          )
          second = user.pests.create!(
            name: "害虫B#{SecureRandom.hex(4)}",
            is_reference: false,
            region: "jp"
          )
          first = user.pests.create!(
            name: "害虫A#{SecureRandom.hex(4)}",
            is_reference: false,
            region: "jp"
          )

          records = PlanSaveTemplateCopyIntegrity.pest_records_for_template_copy(
            ids: [ first.id, second.id ]
          )

          assert_equal [ first.id, second.id ], records.map(&:id)
        end
      end
    end
  end
end
