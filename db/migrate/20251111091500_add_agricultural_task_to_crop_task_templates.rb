class AddAgriculturalTaskToCropTaskTemplates < ActiveRecord::Migration[7.1]
  def up
    add_reference :crop_task_templates, :agricultural_task, foreign_key: true
    add_index :crop_task_templates,
              [:crop_id, :agricultural_task_id],
              unique: true,
              name: "idx_crop_task_templates_on_crop_and_agricultural_task"

    # 注意: このマイグレーションは既に実行済みです
    # CropTaskTemplateBackfillServiceは移行完了後、削除されました
    # マイグレーション再実行時は、この行は実行されません（既に実行済みのため）
    # require Rails.root.join("app/models/crop_task_template")
    # require Rails.root.join("app/services/crop_task_template_backfill_service")
    # CropTaskTemplate.reset_column_information
    # CropTaskTemplateBackfillService.new.call
  end

  def down
    if index_exists?(:crop_task_templates, [:crop_id, :agricultural_task_id], name: "idx_crop_task_templates_on_crop_and_agricultural_task")
      remove_index :crop_task_templates, name: "idx_crop_task_templates_on_crop_and_agricultural_task"
    end

    remove_reference :crop_task_templates, :agricultural_task, foreign_key: true if column_exists?(:crop_task_templates, :agricultural_task_id)
  end
end

