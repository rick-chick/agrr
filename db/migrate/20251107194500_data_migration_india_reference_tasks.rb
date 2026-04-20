# frozen_string_literal: true

class DataMigrationIndiaReferenceTasks < ActiveRecord::Migration[8.0]
  class TempAgriculturalTask < ActiveRecord::Base
    self.table_name = 'agricultural_tasks'
    has_many :agricultural_task_crops, class_name: 'DataMigrationIndiaReferenceTasks::TempAgriculturalTaskCrop', foreign_key: 'agricultural_task_id'
  end

  class TempAgriculturalTaskCrop < ActiveRecord::Base
    self.table_name = 'agricultural_task_crops'
    belongs_to :agricultural_task, class_name: 'DataMigrationIndiaReferenceTasks::TempAgriculturalTask', foreign_key: 'agricultural_task_id'
    belongs_to :crop, class_name: 'DataMigrationIndiaReferenceTasks::TempCrop', foreign_key: 'crop_id'
  end

  class TempCrop < ActiveRecord::Base
    self.table_name = 'crops'
  end

  ALL_CROPS = [
    'अदरक (रियो)',
    'अरहर (तूर दाल)',
    'आम (अल्फांसो)',
    'आलू (कुफरी)',
    'इलायची (मालाबार)',
    'कपास (बीटी कपास)',
    'कॉफी (अरेबिका)',
    'गन्ना (CoC671)',
    'गेहूं (HD2967)',
    'चना (देसी)',
    'चाय (असम)',
    'चावल (IR64)',
    'चावल (बासमती)',
    'जूट (JRO524)',
    'ज्वार (ज्वार अनाज)',
    'टमाटर (पूसा रूबी)',
    'नारियल (लंबा)',
    'पत्ता गोभी (गोल्डन एकर)',
    'प्याज (नासिक लाल)',
    'फूल गोभी (स्नोबॉल)',
    'बाजरा (मोती बाजरा)',
    'बैंगन (बैंगन)',
    'मक्का (संकर)',
    'मसूर (मसूर दाल)',
    'मिर्च (गुंटूर)',
    'मूंगफली (TMV2)',
    'सरसों (पूसा बोल्ड)',
    'सूरजमुखी (KBSH44)',
    'सोयाबीन (JS335)',
    'हल्दी (अल्लेप्पी)'
  ].freeze

  PLOWING_CROPS = [
    'अदरक (रियो)',
    'अरहर (तूर दाल)',
    'आलू (कुफरी)',
    'कपास (बीटी कपास)',
    'गन्ना (CoC671)',
    'गेहूं (HD2967)',
    'चना (देसी)',
    'चावल (IR64)',
    'चावल (बासमती)',
    'जूट (JRO524)',
    'ज्वार (ज्वार अनाज)',
    'टमाटर (पूसा रूबी)',
    'पत्ता गोभी (गोल्डन एकर)',
    'प्याज (नासिक लाल)',
    'फूल गोभी (स्नोबॉल)',
    'बाजरा (मोती बाजरा)',
    'बैंगन (बैंगन)',
    'मक्का (संकर)',
    'मसूर (मसूर दाल)',
    'मिर्च (गुंटूर)',
    'मूंगफली (TMV2)',
    'सरसों (पूसा बोल्ड)',
    'सूरजमुखी (KBSH44)',
    'सोयाबीन (JS335)',
    'हल्दी (अल्लेप्पी)'
  ].freeze

  DIRECT_SEEDING_CROPS = [
    'अरहर (तूर दाल)',
    'कपास (बीटी कपास)',
    'गेहूं (HD2967)',
    'चना (देसी)',
    'चावल (IR64)',
    'चावल (बासमती)',
    'जूट (JRO524)',
    'ज्वार (ज्वार अनाज)',
    'बाजरा (मोती बाजरा)',
    'मक्का (संकर)',
    'मसूर (मसूर दाल)',
    'मूंगफली (TMV2)',
    'सरसों (पूसा बोल्ड)',
    'सूरजमुखी (KBSH44)',
    'सोयाबीन (JS335)'
  ].freeze

  TRANSPLANT_CROPS = [
    'आम (अल्फांसो)',
    'इलायची (मालाबार)',
    'कॉफी (अरेबिका)',
    'चाय (असम)',
    'चावल (IR64)',
    'चावल (बासमती)',
    'टमाटर (पूसा रूबी)',
    'नारियल (लंबा)',
    'पत्ता गोभी (गोल्डन एकर)',
    'प्याज (नासिक लाल)',
    'फूल गोभी (स्नोबॉल)',
    'बैंगन (बैंगन)',
    'मिर्च (गुंटूर)'
  ].freeze

  IRRIGATION_CROPS = [
    'अदरक (रियो)',
    'आम (अल्फांसो)',
    'आलू (कुफरी)',
    'इलायची (मालाबार)',
    'कपास (बीटी कपास)',
    'कॉफी (अरेबिका)',
    'गन्ना (CoC671)',
    'गेहूं (HD2967)',
    'चाय (असम)',
    'चावल (IR64)',
    'चावल (बासमती)',
    'टमाटर (पूसा रूबी)',
    'नारियल (लंबा)',
    'पत्ता गोभी (गोल्डन एकर)',
    'प्याज (नासिक लाल)',
    'फूल गोभी (स्नोबॉल)',
    'बैंगन (बैंगन)',
    'मिर्च (गुंटूर)',
    'हल्दी (अल्लेप्पी)'
  ].freeze

  SHIPPING_PREPARATION_CROPS = [
    'अदरक (रियो)',
    'आम (अल्फांसो)',
    'आलू (कुफरी)',
    'इलायची (मालाबार)',
    'कपास (बीटी कपास)',
    'कॉफी (अरेबिका)',
    'गन्ना (CoC671)',
    'चाय (असम)',
    'जूट (JRO524)',
    'टमाटर (पूसा रूबी)',
    'नारियल (लंबा)',
    'पत्ता गोभी (गोल्डन एकर)',
    'प्याज (नासिक लाल)',
    'फूल गोभी (स्नोबॉल)',
    'बैंगन (बैंगन)',
    'मिर्च (गुंटूर)',
    'हल्दी (अल्लेप्पी)'
  ].freeze

  MULCHING_CROPS = [
    'अदरक (रियो)',
    'आम (अल्फांसो)',
    'आलू (कुफरी)',
    'इलायची (मालाबार)',
    'कॉफी (अरेबिका)',
    'गन्ना (CoC671)',
    'चाय (असम)',
    'टमाटर (पूसा रूबी)',
    'नारियल (लंबा)',
    'पत्ता गोभी (गोल्डन एकर)',
    'फूल गोभी (स्नोबॉल)',
    'बैंगन (बैंगन)',
    'मिर्च (गुंटूर)',
    'हल्दी (अल्लेप्पी)'
  ].freeze

  TUNNEL_CROPS = [
    'टमाटर (पूसा रूबी)',
    'पत्ता गोभी (गोल्डन एकर)',
    'फूल गोभी (स्नोबॉल)',
    'बैंगन (बैंगन)',
    'मिर्च (गुंटूर)'
  ].freeze

  SUPPORT_STRUCTURE_CROPS = [
    'टमाटर (पूसा रूबी)',
    'बैंगन (बैंगन)',
    'मिर्च (गुंटूर)'
  ].freeze

  NET_CROPS = [
    'टमाटर (पूसा रूबी)',
    'पत्ता गोभी (गोल्डन एकर)',
    'फूल गोभी (स्नोबॉल)',
    'बैंगन (बैंगन)',
    'मिर्च (गुंटूर)'
  ].freeze

  THINNING_CROPS = [
    'अरहर (तूर दाल)',
    'कपास (बीटी कपास)',
    'जूट (JRO524)',
    'ज्वार (ज्वार अनाज)',
    'बाजरा (मोती बाजरा)',
    'मक्का (संकर)',
    'सरसों (पूसा बोल्ड)',
    'सूरजमुखी (KBSH44)'
  ].freeze

  PRUNING_CROPS = [
    'आम (अल्फांसो)',
    'इलायची (मालाबार)',
    'कपास (बीटी कपास)',
    'कॉफी (अरेबिका)',
    'चाय (असम)',
    'टमाटर (पूसा रूबी)',
    'बैंगन (बैंगन)',
    'मिर्च (गुंटूर)'
  ].freeze

  TRAINING_CROPS = [
    'टमाटर (पूसा रूबी)',
    'बैंगन (बैंगन)',
    'मिर्च (गुंटूर)'
  ].freeze

  GRADING_CROPS = [
    'अदरक (रियो)',
    'आम (अल्फांसो)',
    'आलू (कुफरी)',
    'इलायची (मालाबार)',
    'कपास (बीटी कपास)',
    'कॉफी (अरेबिका)',
    'गन्ना (CoC671)',
    'चाय (असम)',
    'जूट (JRO524)',
    'टमाटर (पूसा रूबी)',
    'नारियल (लंबा)',
    'पत्ता गोभी (गोल्डन एकर)',
    'प्याज (नासिक लाल)',
    'फूल गोभी (स्नोबॉल)',
    'बैंगन (बैंगन)',
    'मिर्च (गुंटूर)',
    'हल्दी (अल्लेप्पी)'
  ].freeze

  PACKAGING_CROPS = [
    'अदरक (रियो)',
    'आम (अल्फांसो)',
    'आलू (कुफरी)',
    'इलायची (मालाबार)',
    'कपास (बीटी कपास)',
    'कॉफी (अरेबिका)',
    'चाय (असम)',
    'जूट (JRO524)',
    'टमाटर (पूसा रूबी)',
    'नारियल (लंबा)',
    'पत्ता गोभी (गोल्डन एकर)',
    'प्याज (नासिक लाल)',
    'फूल गोभी (स्नोबॉल)',
    'बैंगन (बैंगन)',
    'मिर्च (गुंटूर)',
    'हल्दी (अल्लेप्पी)'
  ].freeze

  LEGACY_ENGLISH_NAMES = %w[
    plowing
    base_fertilization
    seeding
    transplanting
    watering
    weeding
    harvesting
    shipping_preparation
    mulching
    tunnel_setup
    support_structure_setup
    net_installation
    thinning
    pruning
    training
    grading
    packaging
  ].freeze

  TASK_DEFINITIONS = {
    'जुताई' => {
      description: 'मिट्टी को नरम करने के लिए जुताई करना',
      time_per_sqm: 0.05,
      weather_dependency: 'medium',
      required_tools: [ 'कुदाल', 'फावड़ा', 'हल' ],
      skill_level: 'intermediate',
      crops: PLOWING_CROPS
    },
    'आधार उर्वरक' => {
      description: 'रोपण से पहले मिट्टी में मिलाया जाने वाला उर्वरक',
      time_per_sqm: 0.01,
      weather_dependency: 'low',
      required_tools: [ 'कुदाल', 'उर्वरक' ],
      skill_level: 'beginner',
      crops: ALL_CROPS
    },
    'बुआई' => {
      description: 'बीजを圃場に直接播種する',
      time_per_sqm: 0.005,
      weather_dependency: 'medium',
      required_tools: [ 'बीज', 'बीज बोने का यंत्र' ],
      skill_level: 'beginner',
      crops: DIRECT_SEEDING_CROPS
    },
    'रोपाई' => {
      description: 'पौधे लगाना',
      time_per_sqm: 0.02,
      weather_dependency: 'medium',
      required_tools: [ 'पौध', 'रोपण करने का औजार' ],
      skill_level: 'beginner',
      crops: TRANSPLANT_CROPS
    },
    'सिंचाई' => {
      description: 'फसलों को नियमित रूप से पानी देना',
      time_per_sqm: 0.01,
      weather_dependency: 'high',
      required_tools: [ 'पानी की पाइप', 'सिंचाई का कनस्तर' ],
      skill_level: 'beginner',
      crops: IRRIGATION_CROPS
    },
    'निराई' => {
      description: 'खरपतवार को हटाकर खेत साफ़ करना',
      time_per_sqm: 0.03,
      weather_dependency: 'medium',
      required_tools: [ 'दरांती', 'निराई उपकरण' ],
      skill_level: 'beginner',
      crops: ALL_CROPS
    },
    'कटाई' => {
      description: 'परिपक्व फसलों की कटाई करना',
      time_per_sqm: 0.05,
      weather_dependency: 'medium',
      required_tools: [ 'कैंची', 'कटाई टोकरी' ],
      skill_level: 'beginner',
      crops: ALL_CROPS
    },
    'शिपिंग तैयारी' => {
      description: 'शिपिंग से पहले साफ़ करना, छँटाई करना और पैकिंग तैयार करना',
      time_per_sqm: 0.05,
      weather_dependency: 'low',
      required_tools: [ 'बाल्टी', 'छँटाई टोकरी', 'ब्रश' ],
      skill_level: 'intermediate',
      crops: SHIPPING_PREPARATION_CROPS
    },
    'मल्चिंग' => {
      description: 'मल्च शीट बिछाकर मिट्टी को ढकना',
      time_per_sqm: 0.01,
      weather_dependency: 'medium',
      required_tools: [ 'मल्च शीट', 'दांव' ],
      skill_level: 'intermediate',
      crops: MULCHING_CROPS
    },
    'सुरंग सेटअप' => {
      description: 'टनल (सुरंग) संरचना को स्थापित करना',
      time_per_sqm: 0.02,
      weather_dependency: 'medium',
      required_tools: [ 'सुरंग फ्रेम', 'प्लास्टिक शीट' ],
      skill_level: 'intermediate',
      crops: TUNNEL_CROPS
    },
    'समर्थन संरचना सेटअप' => {
      description: 'फसल को सहारा देने हेतु संरचना स्थापित करना',
      time_per_sqm: 0.015,
      weather_dependency: 'low',
      required_tools: [ 'सहारा डंडे', 'बांधने का टेप' ],
      skill_level: 'intermediate',
      crops: SUPPORT_STRUCTURE_CROPS
    },
    'कीट नियंत्रण नेट स्थापना' => {
      description: 'कीट नियंत्रण के लिए नेट लगाना',
      time_per_sqm: 0.015,
      weather_dependency: 'medium',
      required_tools: [ 'कीट नियंत्रण नेट', 'क्लिप' ],
      skill_level: 'intermediate',
      crops: NET_CROPS
    },
    'पतला करना' => {
      description: 'घने पौधों को हटाकर उचित दूरी बनाए रखना',
      time_per_sqm: 0.01,
      weather_dependency: 'low',
      required_tools: [ 'कैंची' ],
      skill_level: 'beginner',
      crops: THINNING_CROPS
    },
    'छँटाई' => {
      description: 'अनावश्यक शाखाओं को काटना',
      time_per_sqm: 0.02,
      weather_dependency: 'low',
      required_tools: [ 'छँटाई कैंची' ],
      skill_level: 'intermediate',
      crops: PRUNING_CROPS
    },
    'प्रशिक्षण' => {
      description: 'फसल को सहारों पर बांधकर दिशा देना',
      time_per_sqm: 0.015,
      weather_dependency: 'low',
      required_tools: [ 'क्लिप', 'सहारा डंडे' ],
      skill_level: 'intermediate',
      crops: TRAINING_CROPS
    },
    'ग्रेडिंग' => {
      description: 'उपज को निर्धारित मानकों के अनुसार श्रेणियों में बांटना',
      time_per_sqm: 0.05,
      weather_dependency: 'low',
      required_tools: [ 'छँटाई टोकरी', 'ग्रेड शीट', 'तुला' ],
      skill_level: 'intermediate',
      crops: GRADING_CROPS
    },
    'पैकेजिंग' => {
      description: 'उपज को डिब्बों या बैग में भरना',
      time_per_sqm: 0.03,
      weather_dependency: 'low',
      required_tools: [ 'डिब्बा', 'बैग', 'लेबल' ],
      skill_level: 'beginner',
      crops: PACKAGING_CROPS
    }
  }.freeze

  def up
    say '🌱 インド（in）の参照タスクを投入しています...'

    legacy_ids = TempAgriculturalTask.where(name: LEGACY_ENGLISH_NAMES, region: 'in', is_reference: true).pluck(:id)
    if legacy_ids.any?
      TempAgriculturalTaskCrop.where(agricultural_task_id: legacy_ids).delete_all
      TempAgriculturalTask.where(id: legacy_ids).delete_all
    end

    TASK_DEFINITIONS.each do |name, attributes|
      task = TempAgriculturalTask.find_or_initialize_by(name: name, region: 'in', is_reference: true)
      task.description = attributes[:description]
      task.time_per_sqm = attributes[:time_per_sqm]
      task.weather_dependency = attributes[:weather_dependency]
      task.required_tools = attributes[:required_tools].to_json
      task.skill_level = attributes[:skill_level]
      task.user_id = nil
      task.is_reference = true
      task.region = 'in'
      task.save!

      TempAgriculturalTaskCrop.where(agricultural_task_id: task.id).delete_all

      attributes[:crops].each do |crop_name|
        crop = TempCrop.find_or_create_by!(name: crop_name, region: 'in', is_reference: true) do |new_crop|
          new_crop.user_id = nil
          new_crop.variety ||= 'सामान्य'
        end

        TempAgriculturalTaskCrop.create!(agricultural_task_id: task.id, crop_id: crop.id)
      end
    end

    say '✅ インドの参照タスク投入が完了しました'
  end

  def down
    say '🗑️ インド（in）の参照タスクを削除しています...'

    task_ids = TempAgriculturalTask.where(name: TASK_DEFINITIONS.keys, region: 'in', is_reference: true).pluck(:id)
    TempAgriculturalTaskCrop.where(agricultural_task_id: task_ids).delete_all if task_ids.any?
    TempAgriculturalTask.where(id: task_ids).delete_all if task_ids.any?

    legacy_ids = TempAgriculturalTask.where(name: LEGACY_ENGLISH_NAMES, region: 'in', is_reference: true).pluck(:id)
    if legacy_ids.any?
      TempAgriculturalTaskCrop.where(agricultural_task_id: legacy_ids).delete_all
      TempAgriculturalTask.where(id: legacy_ids).delete_all
    end

    say '✅ インドの参照タスクを削除しました'
  end
end
