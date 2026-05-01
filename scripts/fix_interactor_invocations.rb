# frozen_string_literal: true

require "pathname"

# 一回限り: Interactor.new の引数に CompositionRoot 由来の kwargs を不足分だけ付与する。

INJECT = {
  "Domain::AgriculturalTask::Interactors::AgriculturalTaskCreateInteractor" =>
    "gateway: CompositionRoot.agricultural_task_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::AgriculturalTask::Interactors::AgriculturalTaskDestroyInteractor" =>
    "gateway: CompositionRoot.agricultural_task_gateway, logger: CompositionRoot.logger, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup",
  "Domain::AgriculturalTask::Interactors::AgriculturalTaskDetailInteractor" =>
    "gateway: CompositionRoot.agricultural_task_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::AgriculturalTask::Interactors::AgriculturalTaskListInteractor" =>
    "gateway: CompositionRoot.agricultural_task_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::AgriculturalTask::Interactors::AgriculturalTaskLoadAuthorizedModelForEditInteractor" =>
    "gateway: CompositionRoot.agricultural_task_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::AgriculturalTask::Interactors::AgriculturalTaskLoadAuthorizedModelForViewInteractor" =>
    "gateway: CompositionRoot.agricultural_task_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::AgriculturalTask::Interactors::AgriculturalTaskUpdateInteractor" =>
    "gateway: CompositionRoot.agricultural_task_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::Crop::Interactors::CropCreateInteractor" =>
    "gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::Crop::Interactors::CropDestroyInteractor" =>
    "gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup",
  "Domain::Crop::Interactors::CropDetailInteractor" =>
    "gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::Crop::Interactors::CropFindReferenceForEntryScheduleInteractor" =>
    "gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger",
  "Domain::Crop::Interactors::CropFindUserNonReferenceRecordInteractor" =>
    "gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::Crop::Interactors::CropListInteractor" =>
    "gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::Crop::Interactors::CropListReferenceEntitiesInteractor" =>
    "gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger",
  "Domain::Crop::Interactors::CropListReferenceForEntryScheduleInteractor" =>
    "gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger",
  "Domain::Crop::Interactors::CropListUserOwnedNonReferenceByIdsInteractor" =>
    "gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::Crop::Interactors::CropListUserOwnedNonReferenceOrderedInteractor" =>
    "gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::Crop::Interactors::CropLoadAuthorizedForCropPestsInteractor" =>
    "gateway: CompositionRoot.crop_gateway, user_lookup: CompositionRoot.user_lookup",
  "Domain::Crop::Interactors::CropLoadAuthorizedModelForHtmlInteractor" =>
    "gateway: CompositionRoot.crop_gateway, user_lookup: CompositionRoot.user_lookup",
  "Domain::Crop::Interactors::CropLoadUserNonReferenceForMastersInteractor" =>
    "gateway: CompositionRoot.crop_gateway, user_lookup: CompositionRoot.user_lookup",
  "Domain::Crop::Interactors::CropStageCreateInteractor" =>
    "gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger",
  "Domain::Crop::Interactors::CropStageDeleteInteractor" =>
    "gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger",
  "Domain::Crop::Interactors::CropStageDetailInteractor" =>
    "gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger",
  "Domain::Crop::Interactors::CropStageListInteractor" =>
    "gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger",
  "Domain::Crop::Interactors::CropStageUpdateInteractor" =>
    "gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger",
  "Domain::Crop::Interactors::CropUpdateInteractor" =>
    "gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::Crop::Interactors::NutrientRequirementUpdateInteractor" =>
    "gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger",
  "Domain::Crop::Interactors::SunshineRequirementUpdateInteractor" =>
    "gateway: CompositionRoot.crop_gateway",
  "Domain::Crop::Interactors::TemperatureRequirementUpdateInteractor" =>
    "gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger",
  "Domain::Crop::Interactors::ThermalRequirementUpdateInteractor" =>
    "gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger",
  "Domain::CultivationPlan::Interactors::AgrrAdjustInteractor" =>
    "gateway: CompositionRoot.agrr_adjust_gateway, logger: CompositionRoot.logger",
  "Domain::CultivationPlan::Interactors::AgrrCandidatesInteractor" =>
    "gateway: CompositionRoot.agrr_candidates_gateway, logger: CompositionRoot.logger",
  "Domain::CultivationPlan::Interactors::CultivationPlanDestroyInteractor" =>
    "gateway: CompositionRoot.cultivation_plan_gateway, logger: CompositionRoot.logger, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup",
  "Domain::CultivationPlan::Interactors::CultivationPlanInitializeInteractor" =>
    "gateway: CompositionRoot.cultivation_plan_gateway, logger: CompositionRoot.logger",
  "Domain::CultivationPlan::Interactors::CultivationPlanCreateInteractor" => "", # class method only
  "Domain::DeletionUndo::Interactors::DeletionUndoRestoreInteractor" =>
    "gateway: CompositionRoot.deletion_undo_gateway",
  "Domain::DeletionUndo::Interactors::DeletionUndoScheduleInteractor" =>
    "gateway: CompositionRoot.deletion_undo_gateway",
  "Domain::Farm::Interactors::FarmCreateInteractor" =>
    "gateway: CompositionRoot.farm_gateway, logger: CompositionRoot.logger, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup",
  "Domain::Farm::Interactors::FarmDestroyInteractor" =>
    "gateway: CompositionRoot.farm_gateway, logger: CompositionRoot.logger, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup",
  "Domain::Farm::Interactors::FarmDetailInteractor" =>
    "gateway: CompositionRoot.farm_gateway, logger: CompositionRoot.logger, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup",
  "Domain::Farm::Interactors::FarmListInteractor" =>
    "gateway: CompositionRoot.farm_gateway, logger: CompositionRoot.logger, translator: CompositionRoot.translator",
  "Domain::Farm::Interactors::FarmListHtmlInteractor" =>
    "gateway: CompositionRoot.farm_gateway",
  "Domain::Farm::Interactors::FarmListReferenceForRegionInteractor" =>
    "gateway: CompositionRoot.farm_gateway, logger: CompositionRoot.logger",
  "Domain::Farm::Interactors::FarmLoadAuthorizedModelForEditInteractor" =>
    "gateway: CompositionRoot.farm_gateway, user_lookup: CompositionRoot.user_lookup",
  "Domain::Farm::Interactors::FarmUpdateInteractor" =>
    "gateway: CompositionRoot.farm_gateway, logger: CompositionRoot.logger, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup",
  "Domain::Fertilize::Interactors::FertilizeCreateInteractor" =>
    "gateway: CompositionRoot.fertilize_gateway, logger: CompositionRoot.logger, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup",
  "Domain::Fertilize::Interactors::FertilizeDestroyInteractor" =>
    "gateway: CompositionRoot.fertilize_gateway, logger: CompositionRoot.logger, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup",
  "Domain::Fertilize::Interactors::FertilizeDetailInteractor" =>
    "gateway: CompositionRoot.fertilize_gateway, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup",
  "Domain::Fertilize::Interactors::FertilizeListInteractor" =>
    "gateway: CompositionRoot.fertilize_gateway, user_lookup: CompositionRoot.user_lookup",
  "Domain::Fertilize::Interactors::FertilizeLoadAuthorizedModelForEditInteractor" =>
    "gateway: CompositionRoot.fertilize_gateway, user_lookup: CompositionRoot.user_lookup",
  "Domain::Fertilize::Interactors::FertilizeLoadAuthorizedModelForViewInteractor" =>
    "gateway: CompositionRoot.fertilize_gateway, user_lookup: CompositionRoot.user_lookup",
  "Domain::Fertilize::Interactors::FertilizeUpdateInteractor" =>
    "gateway: CompositionRoot.fertilize_gateway, logger: CompositionRoot.logger, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup",
  "Domain::Field::Interactors::FieldCreateInteractor" =>
    "gateway: CompositionRoot.field_gateway, logger: CompositionRoot.logger",
  "Domain::Field::Interactors::FieldDestroyInteractor" =>
    "gateway: CompositionRoot.field_gateway, logger: CompositionRoot.logger",
  "Domain::Field::Interactors::FieldDetailInteractor" =>
    "gateway: CompositionRoot.field_gateway, logger: CompositionRoot.logger, translator: CompositionRoot.translator",
  "Domain::Field::Interactors::FieldListInteractor" =>
    "gateway: CompositionRoot.field_gateway, logger: CompositionRoot.logger, translator: CompositionRoot.translator",
  "Domain::Field::Interactors::FieldUpdateInteractor" =>
    "gateway: CompositionRoot.field_gateway, logger: CompositionRoot.logger",
  "Domain::FieldCultivation::Interactors::FieldCultivationClimateDataInteractor" =>
    "gateway: CompositionRoot.field_cultivation_climate_gateway_for(CompositionRoot.user_lookup.find(user_id)), logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::InteractionRule::Interactors::InteractionRuleCreateInteractor" =>
    "gateway: CompositionRoot.interaction_rule_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::InteractionRule::Interactors::InteractionRuleDestroyInteractor" =>
    "gateway: CompositionRoot.interaction_rule_gateway, logger: CompositionRoot.logger, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup",
  "Domain::InteractionRule::Interactors::InteractionRuleDetailInteractor" =>
    "gateway: CompositionRoot.interaction_rule_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::InteractionRule::Interactors::InteractionRuleListInteractor" =>
    "gateway: CompositionRoot.interaction_rule_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::InteractionRule::Interactors::InteractionRuleLoadForHtmlInteractor" =>
    "gateway: CompositionRoot.interaction_rule_gateway, user_lookup: CompositionRoot.user_lookup",
  "Domain::InteractionRule::Interactors::InteractionRuleUpdateInteractor" =>
    "gateway: CompositionRoot.interaction_rule_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::Pest::Interactors::CropsNestedPestsCreateInteractor" =>
    "user_lookup: CompositionRoot.user_lookup, pest_gateway: CompositionRoot.pest_gateway",
  "Domain::Pest::Interactors::CropsNestedPestsIndexInteractor" =>
    "user_lookup: CompositionRoot.user_lookup, pest_gateway: CompositionRoot.pest_gateway",
  "Domain::Pest::Interactors::CropsNestedPestsLoadPestInteractor" =>
    "pest_gateway: CompositionRoot.pest_gateway",
  "Domain::Pest::Interactors::CropsNestedPestsNewInteractor" =>
    "user_lookup: CompositionRoot.user_lookup, pest_gateway: CompositionRoot.pest_gateway",
  "Domain::Pest::Interactors::CropsNestedPestsUpdateInteractor" =>
    "pest_gateway: CompositionRoot.pest_gateway",
  "Domain::Pest::Interactors::MastersCropPestsCreateInteractor" =>
    "user_lookup: CompositionRoot.user_lookup, pest_gateway: CompositionRoot.pest_gateway",
  "Domain::Pest::Interactors::MastersCropPestsIndexInteractor" =>
    "user_lookup: CompositionRoot.user_lookup, pest_gateway: CompositionRoot.pest_gateway",
  "Domain::Pest::Interactors::PestCreateInteractor" =>
    "gateway: CompositionRoot.pest_gateway, logger: CompositionRoot.logger, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup",
  "Domain::Pest::Interactors::PestDestroyInteractor" =>
    "gateway: CompositionRoot.pest_gateway, logger: CompositionRoot.logger, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup",
  "Domain::Pest::Interactors::PestDetailInteractor" =>
    "gateway: CompositionRoot.pest_gateway, logger: CompositionRoot.logger, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup",
  "Domain::Pest::Interactors::PestListInteractor" =>
    "gateway: CompositionRoot.pest_gateway, logger: CompositionRoot.logger, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup",
  "Domain::Pest::Interactors::PestLoadAuthorizedModelForEditInteractor" =>
    "gateway: CompositionRoot.pest_gateway, user_lookup: CompositionRoot.user_lookup",
  "Domain::Pest::Interactors::PestUpdateInteractor" =>
    "gateway: CompositionRoot.pest_gateway, logger: CompositionRoot.logger, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup",
  "Domain::Pesticide::Interactors::MastersCropPesticidesIndexInteractor" =>
    "user_lookup: CompositionRoot.user_lookup, pesticide_gateway: CompositionRoot.pesticide_gateway",
  "Domain::Pesticide::Interactors::PesticideCreateInteractor" =>
    "gateway: CompositionRoot.pesticide_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::Pesticide::Interactors::PesticideDestroyInteractor" =>
    "gateway: CompositionRoot.pesticide_gateway, logger: CompositionRoot.logger, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup",
  "Domain::Pesticide::Interactors::PesticideDetailInteractor" =>
    "gateway: CompositionRoot.pesticide_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::Pesticide::Interactors::PesticideListInteractor" =>
    "gateway: CompositionRoot.pesticide_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::Pesticide::Interactors::PesticideLoadAuthorizedModelForViewInteractor" =>
    "gateway: CompositionRoot.pesticide_gateway, user_lookup: CompositionRoot.user_lookup",
  "Domain::Pesticide::Interactors::PesticideUpdateInteractor" =>
    "gateway: CompositionRoot.pesticide_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup",
  "Domain::PublicPlan::Interactors::PublicPlanCreateInteractor" =>
    "gateway: CompositionRoot.public_plan_gateway, logger: CompositionRoot.logger",
  "Domain::WeatherData::Interactors::WeatherPredictionInteractor" =>
    "cultivation_plan_gateway: CompositionRoot.cultivation_plan_gateway, farm_gateway: CompositionRoot.farm_gateway, weather_data_gateway: CompositionRoot.weather_data_gateway, prediction_gateway: CompositionRoot.prediction_gateway, logger: CompositionRoot.logger",
  "ContactMessages::Interactors::CreateContactMessageInteractor" =>
    "gateway: CompositionRoot.contact_message_gateway"
}.freeze

def kw_present?(inner, key)
  inner.match?(/\b#{Regexp.escape(key)}:/)
end

def merge_inner(inner, inject_str)
  return inner if inject_str.nil? || inject_str.strip.empty?

  fragments = inject_str.split(", ").map(&:strip)
  to_add = fragments.reject do |frag|
    key = frag.split(":", 2)[0].strip
    kw_present?(inner, key)
  end
  return inner if to_add.empty?

  i = inner.strip
  i.empty? ? to_add.join(", ") : "#{i}, #{to_add.join(", ")}"
end

# balanced extract: starting at index of opening paren after ".new"
def extract_new_args(text, start_idx)
  i = start_idx
  depth = 0
  begin_idx = i
  loop do
    c = text[i]
    break if c.nil?

    if c == "("
      depth += 1
      begin_idx = i + 1 if depth == 1
    elsif c == ")"
      depth -= 1
      if depth.zero?
        return [ text[begin_idx...i], i + 1 ]
      end
    end
    i += 1
  end
  nil
end

def fix_content(text)
  changed = false
  INJECT.each do |klass, inject_str|
    next if inject_str.empty?

    search = "#{klass}.new"
    offset = 0
    loop do
      idx = text.index(search, offset)
      break unless idx

      paren_idx = idx + search.length
      next (offset = paren_idx + 1) unless text[paren_idx] == "("

      inner, end_idx = extract_new_args(text, paren_idx)
      unless inner
        offset = paren_idx + 1
        next
      end

      merged = merge_inner(inner, inject_str)
      if merged != inner
        text = text[0...paren_idx+1] + merged + text[end_idx-1..]
        offset = idx + 1
        changed = true
      else
        offset = end_idx
      end
    end
  end
  [ text, changed ]
end

root = Pathname(__dir__).join("..")
paths =
  Dir[root.join("{app,test,lib}/**/*.rb")] -
  [ root.join("lib/composition_root.rb").to_s, root.join("scripts/fix_interactor_invocations.rb").to_s ]

fixed = 0
paths.each do |p|
  next if p.include?("/vendor/")

  content = File.read(p)
  newc, ch = fix_content(content)
  next unless ch

  File.write(p, newc)
  fixed += 1
end

puts "Updated #{fixed} files"
