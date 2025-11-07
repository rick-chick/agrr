require 'test_helper'
require Rails.root.join('db/migrate/20251107193000_data_migration_united_states_reference_tasks')

class DataMigrationUnitedStatesReferenceTasksTest < ActiveSupport::TestCase
  EXPECTED_TASKS = DataMigrationUnitedStatesReferenceTasks::TASK_DEFINITIONS.transform_values do |definition|
    definition.merge(crops: definition[:crops].sort)
  end.freeze

  def setup
    AgriculturalTaskCrop.delete_all
    AgriculturalTask.delete_all

    reference_crop_names.each do |crop_name|
      Crop.where(name: crop_name, region: 'us').delete_all
      create(:crop, :reference, name: crop_name, region: 'us')
    end

    @migration = DataMigrationUnitedStatesReferenceTasks.new
  end

  def test_up_creates_reference_tasks_and_assigns_crops
    @migration.up

    EXPECTED_TASKS.each do |name, attributes|
      task = AgriculturalTask.find_by(name: name, region: 'us', is_reference: true)
      assert task, "Expected task '#{name}' to be created"

      assert_equal attributes[:description], task.description
      assert_in_delta attributes[:time_per_sqm], task.time_per_sqm.to_f, 0.0001
      assert_equal attributes[:weather_dependency], task.weather_dependency
      assert_equal attributes[:required_tools], task.required_tools
      assert_equal attributes[:skill_level], task.skill_level
      assert_nil task.user_id
      assert task.is_reference

      assert_equal attributes[:crops], task.crops.pluck(:name).sort
    end
  end

  def test_down_removes_reference_tasks_and_associations
    @migration.up
    @migration.down

    EXPECTED_TASKS.keys.each do |name|
      assert_nil AgriculturalTask.find_by(name: name, region: 'us', is_reference: true)
    end

    assert_equal 0, AgriculturalTaskCrop.count
  end

  private

  def reference_crop_names
    EXPECTED_TASKS.values.flat_map { |attrs| attrs[:crops] }.uniq
  end
end


