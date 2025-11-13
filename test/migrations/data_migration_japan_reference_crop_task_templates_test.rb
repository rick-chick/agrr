require 'test_helper'
require Rails.root.join('db/migrate/20251113211624_data_migration_japan_reference_crop_task_templates')

class DataMigrationJapanReferenceCropTaskTemplatesTest < ActiveSupport::TestCase
  EXPECTED_TASKS = DataMigrationJapanReferenceCropTaskTemplates::TASK_DEFINITIONS.transform_values do |definition|
    definition.merge(crops: definition[:crops].sort)
  end.freeze

  def setup
    CropTaskTemplate.delete_all
    AgriculturalTask.delete_all

    # 参照作物を作成
    reference_crop_names.each do |crop_name|
      Crop.where(name: crop_name, region: 'jp', is_reference: true).delete_all
      create(:crop, :reference, name: crop_name, region: 'jp')
    end

    # 参照タスクを作成（DataMigrationJapanReferenceTasksで作成される想定）
    EXPECTED_TASKS.each do |name, attributes|
      AgriculturalTask.where(name: name, region: 'jp', is_reference: true).delete_all
      AgriculturalTask.create!(
        name: name,
        description: attributes[:description],
        time_per_sqm: attributes[:time_per_sqm],
        weather_dependency: attributes[:weather_dependency],
        required_tools: attributes[:required_tools].to_json,
        skill_level: attributes[:skill_level],
        user_id: nil,
        is_reference: true,
        region: 'jp'
      )
    end

    @migration = DataMigrationJapanReferenceCropTaskTemplates.new
  end

  def test_up_creates_crop_task_templates
    @migration.up

    EXPECTED_TASKS.each do |task_name, attributes|
      agricultural_task = AgriculturalTask.find_by(name: task_name, region: 'jp', is_reference: true)
      assert agricultural_task, "Expected AgriculturalTask '#{task_name}' to exist"

      attributes[:crops].each do |crop_name|
        crop = Crop.find_by(name: crop_name, region: 'jp', is_reference: true)
        assert crop, "Expected Crop '#{crop_name}' to exist"

        template = CropTaskTemplate.find_by(
          crop_id: crop.id,
          name: task_name,
          is_reference: true
        )
        assert template, "Expected CropTaskTemplate for '#{task_name}' and '#{crop_name}' to be created"

        assert_equal agricultural_task.id, template.agricultural_task_id
        assert_equal attributes[:description], template.description
        assert_in_delta attributes[:time_per_sqm], template.time_per_sqm.to_f, 0.0001
        assert_equal attributes[:weather_dependency], template.weather_dependency
        # required_toolsはJSONでシリアライズされているが、モデルで自動的に配列にデシリアライズされる
        assert_equal attributes[:required_tools], template.required_tools
        assert_equal attributes[:skill_level], template.skill_level
        assert template.is_reference
      end
    end
  end

  def test_up_skips_missing_agricultural_task
    # 存在しないタスク名を追加
    missing_task = AgriculturalTask.create!(
      name: '存在しないタスク',
      description: 'テスト用',
      region: 'jp',
      is_reference: true,
      user_id: nil
    )
    missing_task.destroy # 削除して存在しない状態にする

    # エラーが発生せず、スキップされることを確認
    assert_nothing_raised do
      @migration.up
    end
  end

  def test_up_skips_missing_crop
    # 存在しない作物名を追加
    Crop.where(name: '存在しない作物', region: 'jp', is_reference: true).delete_all

    # エラーが発生せず、スキップされることを確認
    assert_nothing_raised do
      @migration.up
    end
  end

  def test_up_replaces_existing_templates
    # 既存のCropTaskTemplateを作成
    task = AgriculturalTask.find_by(name: '耕耘', region: 'jp', is_reference: true)
    crop = Crop.find_by(name: 'かぼちゃ', region: 'jp', is_reference: true)
    
    existing_template = CropTaskTemplate.create!(
      crop_id: crop.id,
      agricultural_task_id: task.id,
      name: '耕耘',
      description: '古い説明',
      time_per_sqm: 0.1,
      weather_dependency: 'high',
      required_tools: '["古い工具"]',
      skill_level: 'advanced',
      is_reference: true
    )

    @migration.up

    # 既存のテンプレートが更新されていることを確認
    template = CropTaskTemplate.find_by(
      crop_id: crop.id,
      name: '耕耘',
      is_reference: true
    )
    assert template
    assert_not_equal existing_template.id, template.id, "Template should be replaced"
    assert_equal '土を耕して柔らかくする作業', template.description
    assert_in_delta 0.05, template.time_per_sqm.to_f, 0.0001
    assert_equal 'medium', template.weather_dependency
    assert_equal 'intermediate', template.skill_level
  end

  def test_down_removes_crop_task_templates
    @migration.up
    @migration.down

    # CropTaskTemplateが削除されていることを確認
    task_names = EXPECTED_TASKS.keys
    task_ids = AgriculturalTask.where(name: task_names, region: 'jp', is_reference: true).pluck(:id)
    
    if task_ids.any?
      templates = CropTaskTemplate.where(agricultural_task_id: task_ids, is_reference: true)
      assert_equal 0, templates.count, "All CropTaskTemplates should be deleted"
    end

    # AgriculturalTaskは削除されないことを確認
    task_names.each do |name|
      task = AgriculturalTask.find_by(name: name, region: 'jp', is_reference: true)
      assert task, "AgriculturalTask '#{name}' should not be deleted"
    end
  end

  def test_up_creates_correct_number_of_templates
    @migration.up

    # 期待されるテンプレート数を計算
    expected_count = EXPECTED_TASKS.sum { |_, attributes| attributes[:crops].size }

    actual_count = CropTaskTemplate.where(is_reference: true).count
    assert_equal expected_count, actual_count, "Expected #{expected_count} CropTaskTemplates, got #{actual_count}"
  end

  private

  def reference_crop_names
    EXPECTED_TASKS.values.flat_map { |attrs| attrs[:crops] }.uniq
  end
end

