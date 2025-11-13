require 'test_helper'
require Rails.root.join('db/migrate/20251107194500_data_migration_india_reference_tasks')

class DataMigrationIndiaReferenceTasksTest < ActiveSupport::TestCase
  EXPECTED_TASKS = DataMigrationIndiaReferenceTasks::TASK_DEFINITIONS.transform_values do |definition|
    definition.merge(crops: definition[:crops].sort)
  end.freeze

  def setup
    CropTaskTemplate.delete_all
    AgriculturalTask.delete_all

    reference_crop_names.each do |crop_name|
      Crop.where(name: crop_name, region: 'in').delete_all
      create(:crop, :reference, name: crop_name, region: 'in')
    end

    @migration = DataMigrationIndiaReferenceTasks.new
  end

  def test_up_creates_reference_tasks_and_assigns_crops
    # agricultural_task_cropsテーブルが削除されているため、マイグレーションは実行できない
    # このマイグレーションは既に実行済みなので、テストをスキップ
    skip "agricultural_task_cropsテーブルが削除されているため、マイグレーションは実行できません"
    
    @migration.up

    EXPECTED_TASKS.each do |name, attributes|
      task = AgriculturalTask.find_by(name: name, region: 'in', is_reference: true)
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
    # agricultural_task_cropsテーブルが削除されているため、マイグレーションは実行できない
    # このマイグレーションは既に実行済みなので、テストをスキップ
    skip "agricultural_task_cropsテーブルが削除されているため、マイグレーションは実行できません"
    
    @migration.up
    @migration.down

    EXPECTED_TASKS.keys.each do |name|
      assert_nil AgriculturalTask.find_by(name: name, region: 'in', is_reference: true)
    end

    assert_equal 0, CropTaskTemplate.count
  end

  private

  def reference_crop_names
    EXPECTED_TASKS.values.flat_map { |attrs| attrs[:crops] }.uniq
  end
end

