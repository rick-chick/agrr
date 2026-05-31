# frozen_string_literal: true

# Historical marker for agrr-migrate data kind=repair (region=us).
# Implementation: crates/agrr-migrate/src/data/repairs.rs + base::repair_us_reference_crops
#
#   agrr-migrate data apply --region us --kind repair
class RepairUsReferenceCrops < ActiveRecord::Migration[8.0]
  def up
    say "Apply via agrr-migrate: data apply --region us --kind repair", true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
