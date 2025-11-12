namespace :agrr do
  desc 'Backfill crop task templates for existing crop-task relationships. Use CROP_IDS=1,2 to scope.'
  task backfill_crop_task_templates: :environment do
    crop_ids = ENV['CROP_IDS']&.split(',')&.map(&:strip)&.reject(&:blank?)
    crop_ids = crop_ids&.map(&:to_i)&.uniq

    service = CropTaskTemplateBackfillService.new
    service.call(crop_ids: crop_ids)

    if crop_ids.present?
      puts "✅ Backfilled crop task templates for crop IDs: #{crop_ids.join(', ')}"
    else
      puts "✅ Backfilled crop task templates for all crops"
    end
  end
end


