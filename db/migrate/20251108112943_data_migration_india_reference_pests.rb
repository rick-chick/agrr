# frozen_string_literal: true

class DataMigrationIndiaReferencePests < ActiveRecord::Migration[8.0]
  # 一時モデル定義（マイグレーション内でのみ使用）
  # モデルクラスへの依存を避け、スキーマ変更に強い設計

  class TempPest < ActiveRecord::Base
    self.table_name = 'pests'
    has_one :pest_temperature_profile, class_name: 'DataMigrationIndiaReferencePests::TempPestTemperatureProfile', foreign_key: 'pest_id'
    has_one :pest_thermal_requirement, class_name: 'DataMigrationIndiaReferencePests::TempPestThermalRequirement', foreign_key: 'pest_id'
    has_many :pest_control_methods, class_name: 'DataMigrationIndiaReferencePests::TempPestControlMethod', foreign_key: 'pest_id'
    has_many :crop_pests, class_name: 'DataMigrationIndiaReferencePests::TempCropPest', foreign_key: 'pest_id'
  end

  class TempPestTemperatureProfile < ActiveRecord::Base
    self.table_name = 'pest_temperature_profiles'
    belongs_to :pest, class_name: 'DataMigrationIndiaReferencePests::TempPest', foreign_key: 'pest_id'
  end

  class TempPestThermalRequirement < ActiveRecord::Base
    self.table_name = 'pest_thermal_requirements'
    belongs_to :pest, class_name: 'DataMigrationIndiaReferencePests::TempPest', foreign_key: 'pest_id'
  end

  class TempPestControlMethod < ActiveRecord::Base
    self.table_name = 'pest_control_methods'
    belongs_to :pest, class_name: 'DataMigrationIndiaReferencePests::TempPest', foreign_key: 'pest_id'
  end

  class TempCropPest < ActiveRecord::Base
    self.table_name = 'crop_pests'
    belongs_to :pest, class_name: 'DataMigrationIndiaReferencePests::TempPest', foreign_key: 'pest_id'
    belongs_to :crop, class_name: 'DataMigrationIndiaReferencePests::TempCrop', foreign_key: 'crop_id'
  end

  class TempCrop < ActiveRecord::Base
    self.table_name = 'crops'
  end

  def up
    say "🌱 Seeding India (in) reference pests..."

    seed_reference_pests

    say "✅ India reference pests seeding completed!"
  end

  def down
    say "🗑️  Removing India (in) reference pests..."

    # Find pests by region
    pest_ids = TempPest.where(region: 'in', is_reference: true).pluck(:id)

    # Delete related records
    TempCropPest.where(pest_id: pest_ids).delete_all
    TempPestControlMethod.where(pest_id: pest_ids).delete_all
    TempPestThermalRequirement.where(pest_id: pest_ids).delete_all
    TempPestTemperatureProfile.where(pest_id: pest_ids).delete_all
    TempPest.where(region: 'in', is_reference: true).delete_all

    say "✅ India reference pests removed"
  end

  private

  def seed_reference_pests
      # टिड्डी
      pest = TempPest.find_or_initialize_by(name: "टिड्डी", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Schistocerca gregaria",
        family: "Acrididae",
        order: "Orthoptera",
        description: "टिड्डी फसलों को अत्यधिक नुकसान पहुंचा सकती है, विशेष रूप से गेहूं, चावल (बासमती), मक्का (संकर) और टमाटर (पूसा रूबी) पर। ये कीट बड़े समूहों में आते हैं और तेजी से फसलों को चट कर सकते हैं, जिससे फसल उत्पादन में भारी कमी आती है।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 300,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "पेस्टीसाइड का छिड़काव",
        description: "टिड्डियों के नियंत्रण के लिए प्रभावी कीटनाशकों का उपयोग करें।",
        timing_hint: "जब टिड्डियों की संख्या बढ़ने लगे।"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "प्राकृतिक शत्रुओं का उपयोग",
        description: "टिड्डियों के प्राकृतिक शत्रुओं जैसे कि पक्षियों और कीटों को बढ़ावा दें।",
        timing_hint: "फसल के विकास के दौरान।"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "फसल चक्र",
        description: "फसल चक्र अपनाकर टिड्डियों के प्रकोप को कम करें।",
        timing_hint: "फसल की बुवाई से पहले।"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "गेहूं", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "चावल (बासमती)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "मक्का (संकर)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "टमाटर (पूसा रूबी)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # कपास बोलवर्म
      pest = TempPest.find_or_initialize_by(name: "कपास बोलवर्म", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Helicoverpa armigera",
        family: "Noctuidae",
        order: "Lepidoptera",
        description: "कपास बोलवर्म एक प्रमुख कीट है जो कपास, टमाटर, मक्का और बैंगन पर गंभीर नुकसान पहुंचा सकता है। यह कीट पौधों के पत्तों, कलियों और फलों को खा जाता है, जिससे फसल की उपज में कमी आती है।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 1200,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "पेस्टीसाइड का उपयोग",
        description: "कपास बोलवर्म के नियंत्रण के लिए प्रभावी पेस्टीसाइड का छिड़काव करें।",
        timing_hint: "कीट की पहली पीढ़ी के प्रकट होने पर लागू करें।"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "परजीवी कीटों का उपयोग करके कपास बोलवर्म की जनसंख्या को नियंत्रित करें।",
        timing_hint: "जब कीट की संख्या बढ़ने लगे।"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "फसल चक्रण",
        description: "फसल चक्रण का अभ्यास करें ताकि कीटों के जीवन चक्र को बाधित किया जा सके।",
        timing_hint: "फसल के मौसम के अनुसार।"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "टमाटर (पूसा रूबी)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "मक्का (संकर)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "बैंगन (बैंगन)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "कपास (बीटी कपास)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # धान हिस्पा
      pest = TempPest.find_or_initialize_by(name: "धान हिस्पा", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Scirpophaga incertulas",
        family: "Crambidae",
        order: "Lepidoptera",
        description: "धान हिस्पा की लार्वा चावल के पौधों की पत्तियों को खा जाती है, जिससे पत्तियों पर सफेद धब्बे और छिद्र बन जाते हैं। यह पौधों की वृद्धि को प्रभावित करता है और उपज में कमी का कारण बनता है।",
        occurrence_season: "मानसून के मौसम में"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "पेस्टीसाइड का छिड़काव",
        description: "प्रभावी कीटनाशकों का उपयोग करें जो धान हिस्पा को नियंत्रित कर सकते हैं।",
        timing_hint: "पौधों के विकास के प्रारंभिक चरण में लागू करें।"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "परजीवी कीटों का उपयोग करें जो धान हिस्पा के लार्वा को नियंत्रित कर सकते हैं।",
        timing_hint: "जब लार्वा की संख्या बढ़ने लगे।"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "फसल चक्र",
        description: "धान की फसल के साथ अन्य फसलों का चक्र लगाएं ताकि कीटों की संख्या कम हो सके।",
        timing_hint: "फसल के मौसम के अनुसार।"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "चावल (बासमती)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "चावल (IR64)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # गन्ना पिरिला
      pest = TempPest.find_or_initialize_by(name: "गन्ना पिरिला", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Diatraea saccharalis",
        family: "Crambidae",
        order: "Lepidoptera",
        description: "गन्ना पिरिला, गन्ना और मक्का की फसलों में गंभीर नुकसान पहुंचाता है। यह कीट पौधों के तने में सुरंगें बनाता है, जिससे पौधों की वृद्धि रुक जाती है और फसल की उपज में कमी आती है।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticides",
        description: "कीटनाशकों का उपयोग गन्ना पिरिला के नियंत्रण के लिए किया जाता है।",
        timing_hint: "फसल के शुरुआती विकास चरण में लागू करें।"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Parasitoids",
        description: "प्राकृतिक परजीवी का उपयोग करके गन्ना पिरिला की जनसंख्या को नियंत्रित किया जा सकता है।",
        timing_hint: "जब कीट की जनसंख्या बढ़ने लगे।"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop Rotation",
        description: "फसलों का चक्रण गन्ना पिरिला के जीवन चक्र को बाधित कर सकता है।",
        timing_hint: "फसल के बाद हर साल बदलें।"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "गन्ना (CoC671)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "मक्का (संकर)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # आम मिलीबग
      pest = TempPest.find_or_initialize_by(name: "आम मिलीबग", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Phenacoccus solenopsis",
        family: "Pseudococcidae",
        order: "Hemiptera",
        description: "आम मिलीबग टमाटर के पौधों पर सफेद, पाउडरी धब्बे बनाते हैं, जिससे पौधों की पत्तियों की पीलापन और मुरझाने की समस्या होती है। यह पौधों की वृद्धि को रोकता है और फल की गुणवत्ता को प्रभावित करता है।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 600,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "इमिडाक्लोप्रिड",
        description: "यह एक कीटनाशक है जो मिलीबग के खिलाफ प्रभावी है।",
        timing_hint: "जब पहली बार मिलीबग के लक्षण दिखाई दें।"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीट",
        description: "परजीवी कीट जैसे कि एपीडिस का उपयोग किया जा सकता है।",
        timing_hint: "प्राकृतिक संतुलन बनाए रखने के लिए।"
      )
      pest.pest_control_methods.create!(
        method_type: "physical",
        method_name: "हाथ से हटाना",
        description: "मिलीबग को हाथ से हटाना या पानी से धोना।",
        timing_hint: "जब पौधों पर कम संख्या में हों।"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "सफाई और फसल चक्र",
        description: "पौधों की सफाई और फसल चक्र का पालन करना।",
        timing_hint: "फसल के बाद।"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "टमाटर (पूसा रूबी)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # ब्राउन प्लांट हॉपर
      pest = TempPest.find_or_initialize_by(name: "ब्राउन प्लांट हॉपर", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Nilaparvata lugens",
        family: "Delphacidae",
        order: "Hemiptera",
        description: "ब्राउन प्लांट हॉपर चावल की फसलों पर गंभीर नुकसान पहुंचाता है। यह पौधों के रस को चूसकर उन्हें कमजोर करता है, जिससे पत्तियों का पीला होना और सूखना शुरू होता है। इसके अलावा, यह वायरस के संचरण का भी कारण बन सकता है।",
        occurrence_season: "मानसून के मौसम में"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 600,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "इंसेक्टिसाइड का उपयोग",
        description: "ब्राउन प्लांट हॉपर के नियंत्रण के लिए प्रभावी कीटनाशकों का छिड़काव करें।",
        timing_hint: "फसल के शुरुआती विकास चरण में"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "ब्राउन प्लांट हॉपर के प्राकृतिक शत्रुओं का उपयोग करें।",
        timing_hint: "फसल के विकास के दौरान"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "फसल चक्र",
        description: "फसल चक्र अपनाकर कीटों की आबादी को नियंत्रित करें।",
        timing_hint: "फसल के बाद"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "चावल (बासमती)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "चावल (IR64)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # सफेद पीठ वाला प्लांटहॉपर
      pest = TempPest.find_or_initialize_by(name: "सफेद पीठ वाला प्लांटहॉपर", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Sogatella furcifera",
        family: "Delphacidae",
        order: "Hemiptera",
        description: "सफेद पीठ वाला प्लांटहॉपर चावल, मक्का और अन्य फसलों पर गंभीर नुकसान पहुंचा सकता है। यह पौधों के रस को चूसकर उन्हें कमजोर करता है, जिससे पत्तियों पर पीले धब्बे और अंततः पत्तियों का मुरझाना होता है। यह फसल की वृद्धि को प्रभावित करता है और उपज में कमी का कारण बनता है।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 600,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "इंसेक्टिसाइड का छिड़काव",
        description: "सफेद पीठ वाले प्लांटहॉपर के नियंत्रण के लिए प्रभावी कीटनाशकों का उपयोग करें।",
        timing_hint: "फसल के शुरुआती विकास चरण में लागू करें।"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "परजीवी कीटों का उपयोग करके प्लांटहॉपर की जनसंख्या को नियंत्रित करें।",
        timing_hint: "फसल के विकास के दौरान नियमित रूप से निगरानी करें।"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "फसल चक्र",
        description: "फसल चक्र का पालन करें ताकि प्लांटहॉपर के जीवन चक्र को बाधित किया जा सके।",
        timing_hint: "फसल के बाद फसल बदलें।"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "चावल (बासमती)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "चावल (IR64)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "मक्का (संकर)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # हरा पत्ता हॉपर
      pest = TempPest.find_or_initialize_by(name: "हरा पत्ता हॉपर", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Empoasca vitis",
        family: "Cicadellidae",
        order: "Hemiptera",
        description: "हरा पत्ता हॉपर चावल, मक्का, सोयाबीन और कपास पर गंभीर नुकसान पहुंचा सकता है। यह पत्तियों के ऊपरी हिस्से को चूसकर पौधों की वृद्धि को प्रभावित करता है, जिससे पत्तियों पर पीले धब्बे और अंततः पत्तियों का सूखना होता है।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "इंसेक्टिसाइड का छिड़काव",
        description: "पौधों पर कीटनाशक का छिड़काव करना, जो हरा पत्ता हॉपर को नियंत्रित करने में मदद करता है।",
        timing_hint: "पौधों के विकास के प्रारंभिक चरण में लागू करें।"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "परजीवी कीटों का उपयोग करके हरा पत्ता हॉपर की जनसंख्या को नियंत्रित करना।",
        timing_hint: "जब हॉपर की जनसंख्या बढ़ने लगे।"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "फसल चक्र",
        description: "फसल चक्र का पालन करके कीटों के जीवन चक्र को बाधित करना।",
        timing_hint: "फसल के बाद फसल बदलें।"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "चावल (बासमती)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "मक्का (संकर)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "सोयाबीन (JS335)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "कपास (बीटी कपास)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # धान स्टेम बोरर
      pest = TempPest.find_or_initialize_by(name: "धान स्टेम बोरर", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Scirpophaga incertulas",
        family: "Crambidae",
        order: "Lepidoptera",
        description: "धान स्टेम बोरर कीट चावल के पौधों के तने में सुरंग बनाते हैं, जिससे पौधों की वृद्धि रुक जाती है और फसल की उपज में कमी आती है। यह कीट विशेष रूप से युवा पौधों को प्रभावित करता है, जिससे पत्तियों का पीला होना और अंततः पौधों की मृत्यु हो सकती है।",
        occurrence_season: "मानसून के मौसम में"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: 300
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "पेस्टीसाइड का उपयोग",
        description: "कीटों के नियंत्रण के लिए प्रभावी पेस्टीसाइड का छिड़काव करें।",
        timing_hint: "पौधों के विकास के प्रारंभिक चरण में लागू करें।"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "परजीवी कीटों का उपयोग करके प्राकृतिक संतुलन बनाए रखें।",
        timing_hint: "कीटों की संख्या बढ़ने पर लागू करें।"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "फसल चक्र",
        description: "फसल चक्र का पालन करें ताकि कीटों का जीवन चक्र बाधित हो सके।",
        timing_hint: "फसल के बाद फसल बदलें।"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "चावल (बासमती)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "चावल (IR64)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # पीला स्टेम बोरर
      pest = TempPest.find_or_initialize_by(name: "पीला स्टेम बोरर", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Scirpophaga incertulas",
        family: "Crambidae",
        order: "Lepidoptera",
        description: "पीला स्टेम बोरर चावल और मक्का की फसलों में गंभीर नुकसान पहुंचाता है। यह पौधों के तने में सुरंगें बनाता है, जिससे पौधों की वृद्धि रुक जाती है और फसल की उपज में कमी आती है।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: 300
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "पेस्टीसाइड का उपयोग",
        description: "प्रभावी कीटनाशकों का छिड़काव करें जो पीला स्टेम बोरर को नियंत्रित करते हैं।",
        timing_hint: "फसल के शुरुआती विकास चरण में लागू करें।"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "परजीवी कीटों का उपयोग करें जो पीला स्टेम बोरर के लार्वा को नियंत्रित करते हैं।",
        timing_hint: "फसल के विकास के दौरान लागू करें।"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "फसल चक्र",
        description: "फसल चक्र का पालन करें ताकि पीला स्टेम बोरर के जीवन चक्र को बाधित किया जा सके।",
        timing_hint: "फसल के बाद फसल बदलें।"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "चावल (बासमती)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "चावल (IR64)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "मक्का (संकर)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # धान गाल मिज
      pest = TempPest.find_or_initialize_by(name: "धान गाल मिज", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Scirpophaga incertulas",
        family: "Crambidae",
        order: "Lepidoptera",
        description: "धान गाल मिज, चावल के पौधों के लिए एक प्रमुख कीट है। यह पौधों के तनों में सुरंग बनाता है, जिससे पौधों की वृद्धि रुक जाती है और उपज में कमी आती है। आलू और टमाटर पर भी यह कीट नुकसान पहुंचा सकता है, जिससे फसल की गुणवत्ता प्रभावित होती है।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "इंसेक्टिसाइड का उपयोग",
        description: "कीटों के नियंत्रण के लिए प्रभावी कीटनाशकों का छिड़काव करें।",
        timing_hint: "फसल के शुरुआती विकास चरण में"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "परजीवी कीटों का उपयोग करके प्राकृतिक संतुलन बनाए रखें।",
        timing_hint: "फसल के विकास के दौरान"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "फसल चक्र",
        description: "फसल चक्र अपनाकर कीटों की आबादी को नियंत्रित करें।",
        timing_hint: "फसल के बाद"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "चावल (बासमती)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "चावल (IR64)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "मक्का (संकर)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "आलू (कुफरी)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "टमाटर (पूसा रूबी)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "सोयाबीन (JS335)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # धान पत्ता फोल्डर
      pest = TempPest.find_or_initialize_by(name: "धान पत्ता फोल्डर", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Chilo suppressalis",
        family: "Pyralidae",
        order: "Lepidoptera",
        description: "धान पत्ता फोल्डर कीट चावल की पत्तियों को मोड़कर अंदर छिप जाता है, जिससे पत्तियों में छिद्र और सूखापन होता है। यह कीट चावल की फसल को गंभीर नुकसान पहुंचा सकता है, विशेष रूप से बासमती और IR64 किस्मों में।",
        occurrence_season: "मानसून के मौसम में"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: 300
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "पेस्टीसाइड का उपयोग",
        description: "कीटों के नियंत्रण के लिए प्रभावी पेस्टीसाइड का छिड़काव करें।",
        timing_hint: "फसल के शुरुआती विकास चरण में लागू करें।"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "परजीवी कीटों का उपयोग करके प्राकृतिक संतुलन बनाए रखें।",
        timing_hint: "फसल के विकास के दौरान लागू करें।"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "फसल चक्रण",
        description: "फसल चक्रण का अभ्यास करें ताकि कीटों की आबादी को नियंत्रित किया जा सके।",
        timing_hint: "हर मौसम में फसल बदलें।"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "चावल (बासमती)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "चावल (IR64)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # धान झुंड कैटरपिलर
      pest = TempPest.find_or_initialize_by(name: "धान झुंड कैटरपिलर", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Mythimna separata",
        family: "Noctuidae",
        order: "Lepidoptera",
        description: "धान झुंड कैटरपिलर, चावल, मक्का और सोयाबीन की पत्तियों को खा जाता है, जिससे फसल की वृद्धि में बाधा आती है। यह कीट पत्तियों के किनारों से शुरू करके उन्हें पूरी तरह से खा सकता है, जिससे फसल की उपज में कमी आती है।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticides",
        description: "कीटनाशकों का उपयोग करना, जैसे कि स्पिनोसाड या बायो-कीटनाशक, कीटों की संख्या को नियंत्रित करने के लिए।",
        timing_hint: "जब कीटों की संख्या अधिक हो जाए।"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Nematodes",
        description: "जैविक कीट नियंत्रण के लिए नematodes का उपयोग करना।",
        timing_hint: "जब कीटों की संख्या बढ़ने लगे।"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop Rotation",
        description: "फसलों का चक्रण करना ताकि कीटों का जीवन चक्र बाधित हो सके।",
        timing_hint: "फसल के बाद।"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "चावल (बासमती)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "चावल (IR64)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "मक्का (संकर)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "सोयाबीन (JS335)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # आर्मीवर्म
      pest = TempPest.find_or_initialize_by(name: "आर्मीवर्म", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Spodoptera frugiperda",
        family: "Noctuidae",
        order: "Lepidoptera",
        description: "आर्मीवर्म एक प्रमुख कीट है जो मक्का, कपास और चावल की फसलों को गंभीर रूप से नुकसान पहुंचाता है। यह पौधों की पत्तियों को खा जाता है, जिससे फसल की वृद्धि रुक जाती है और उपज में कमी आती है।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 1200,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "पेस्टीसाइड का उपयोग",
        description: "कीटनाशकों का छिड़काव करना जो आर्मीवर्म को नियंत्रित करने में मदद करता है।",
        timing_hint: "फसल के शुरुआती विकास के दौरान"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "परजीवी कीटों का उपयोग करना जो आर्मीवर्म के लार्वा को नियंत्रित करते हैं।",
        timing_hint: "जब लार्वा की संख्या बढ़ने लगे"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "फसल चक्रण",
        description: "फसलों का चक्रण करना ताकि कीटों की आबादी को नियंत्रित किया जा सके।",
        timing_hint: "फसल के बाद"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "मक्का (संकर)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "कपास (बीटी कपास)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "चावल (बासमती)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "चावल (IR64)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # कपास एफिड
      pest = TempPest.find_or_initialize_by(name: "कपास एफिड", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Aphis gossypii",
        family: "Aphididae",
        order: "Hemiptera",
        description: "कपास एफिड टमाटर की पत्तियों के नीचे और तनों पर समूह में पाए जाते हैं। ये पौधों के रस को चूसकर उन्हें कमजोर करते हैं, जिससे पत्तियाँ पीली पड़ जाती हैं और अंततः सूख जाती हैं। इसके अलावा, ये पौधों पर चिपचिपा पदार्थ छोड़ते हैं, जो फफूंदी के विकास को बढ़ावा देता है।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 30
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 600,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "इंसेक्टिसाइड का उपयोग",
        description: "कपास एफिड के नियंत्रण के लिए प्रभावी कीटनाशकों का छिड़काव करें।",
        timing_hint: "जब एफिड की संख्या बढ़ने लगे।"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "परजीवी कीट जैसे कि लेडीबग्स का उपयोग करें जो एफिड्स को खा जाते हैं।",
        timing_hint: "जब एफिड की संख्या कम होनी शुरू हो।"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "पौधों की सही देखभाल",
        description: "पौधों को स्वस्थ रखने के लिए उचित जल और पोषण प्रदान करें।",
        timing_hint: "साल भर।"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "टमाटर (पूसा रूबी)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # कपास व्हाइटफ्लाई
      pest = TempPest.find_or_initialize_by(name: "कपास व्हाइटफ्लाई", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Bemisia tabaci",
        family: "Aleyrodidae",
        order: "Hemiptera",
        description: "कपास व्हाइटफ्लाई पौधों के रस को चूसकर उन्हें कमजोर करती है, जिससे पत्तियों पर पीले धब्बे और अंततः पत्तियों का गिरना होता है। यह कीट टमाटर, पत्ता गोभी, बैंगन और कपास पर गंभीर नुकसान पहुंचा सकता है।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 600,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "इंसेक्टिसाइड का उपयोग",
        description: "कपास व्हाइटफ्लाई को नियंत्रित करने के लिए प्रभावी कीटनाशकों का छिड़काव करें।",
        timing_hint: "कीटों की पहली उपस्थिति के बाद तुरंत लागू करें।"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "परजीवी कीट जैसे कि एग्ज़ोनोटस का उपयोग करें जो व्हाइटफ्लाई के अंडों को नष्ट करते हैं।",
        timing_hint: "जब व्हाइटफ्लाई की संख्या बढ़ने लगे।"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "फसल चक्रण",
        description: "फसल चक्रण का अभ्यास करें ताकि कीटों के जीवन चक्र को बाधित किया जा सके।",
        timing_hint: "फसल के बाद अगली फसल लगाने से पहले।"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "टमाटर (पूसा रूबी)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "पत्ता गोभी (गोल्डन एकर)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "बैंगन (बैंगन)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "कपास (बीटी कपास)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # लाल कपास बग
      pest = TempPest.find_or_initialize_by(name: "लाल कपास बग", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Dysdercus cingulatus",
        family: "Pyrrhocoridae",
        order: "Hemiptera",
        description: "लाल कपास बग टमाटर, मक्का, बैंगन और सोयाबीन पर गंभीर नुकसान पहुंचा सकता है। यह पौधों के रस को चूसकर उन्हें कमजोर करता है, जिससे पत्तियों का पीला होना, मुरझाना और फल का गिरना शामिल है।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "इंसेक्टिसाइड का उपयोग",
        description: "रासायनिक कीटनाशकों का छिड़काव करना जो लाल कपास बग को नियंत्रित करने में मदद करता है।",
        timing_hint: "पौधों के विकास के प्रारंभिक चरण में लागू करें।"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "लाल कपास बग के प्राकृतिक शत्रुओं का उपयोग करना।",
        timing_hint: "जब बग की जनसंख्या बढ़ने लगे।"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "फसल चक्रण",
        description: "फसलों का चक्रण करना ताकि बग के जीवन चक्र को बाधित किया जा सके।",
        timing_hint: "फसल के बाद फसल बदलें।"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "टमाटर (पूसा रूबी)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "मक्का (संकर)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "बैंगन (बैंगन)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "सोयाबीन (JS335)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # गन्ना टॉप बोरर
      pest = TempPest.find_or_initialize_by(name: "गन्ना टॉप बोरर", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Scirpophaga excerptalis",
        family: "Crambidae",
        order: "Lepidoptera",
        description: "गन्ना टॉप बोरर गन्ने के शीर्ष भाग में सुरंग बनाता है, जिससे पौधे की वृद्धि रुक जाती है और उपज में कमी आती है। यह कीट गन्ने के पत्तों को भी नुकसान पहुंचा सकता है, जिससे पत्तियों की पीलापन और सूखापन होता है।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "इंसेक्टिसाइड का छिड़काव",
        description: "गन्ना टॉप बोरर के नियंत्रण के लिए प्रभावी कीटनाशकों का उपयोग करें।",
        timing_hint: "कीट की पहली पीढ़ी के प्रकट होने के समय पर छिड़काव करें।"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "गन्ना टॉप बोरर के प्राकृतिक शत्रुओं को बढ़ावा दें।",
        timing_hint: "जब कीट की संख्या बढ़ने लगे।"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "फसल चक्र",
        description: "फसल चक्र का पालन करें ताकि कीटों के जीवन चक्र को बाधित किया जा सके।",
        timing_hint: "फसल के बाद फसल बदलें।"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "गन्ना (CoC671)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # गन्ना शूट बोरर
      pest = TempPest.find_or_initialize_by(name: "गन्ना शूट बोरर", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Chilo infuscatellus",
        family: "Pyralidae",
        order: "Lepidoptera",
        description: "गन्ना शूट बोरर पौधों के तनों में सुरंगें बनाता है, जिससे पौधों की वृद्धि रुक जाती है और उत्पादन में कमी आती है। यह कीट गन्ने के नए शूट में अंडे देता है, और लार्वा पौधों के अंदर घुसकर उन्हें नुकसान पहुँचाता है।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "इंसेक्टिसाइड का छिड़काव",
        description: "गन्ना शूट बोरर के नियंत्रण के लिए प्रभावी कीटनाशकों का उपयोग करें।",
        timing_hint: "पौधों के विकास के प्रारंभिक चरण में"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "गन्ना शूट बोरर के प्राकृतिक शत्रुओं को बढ़ावा देना।",
        timing_hint: "सभी विकास चरणों में"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "सफाई और फसल चक्र",
        description: "फसल चक्र का पालन करें और खेतों को साफ रखें।",
        timing_hint: "फसल के बाद"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "गन्ना (CoC671)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # गन्ना पत्ता हॉपर
      pest = TempPest.find_or_initialize_by(name: "गन्ना पत्ता हॉपर", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Pyrilla perpusilla",
        family: "Cicadellidae",
        order: "Hemiptera",
        description: "गन्ना पत्ता हॉपर गन्ना, मक्का और चावल की फसलों पर गंभीर नुकसान पहुंचा सकता है। यह पत्तियों को चूसकर पौधों की वृद्धि को बाधित करता है, जिससे पत्तियों पर पीले धब्बे और अंततः पत्तियों का सूखना होता है।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "इंसेक्टिसाइड का छिड़काव",
        description: "गन्ना पत्ता हॉपर के नियंत्रण के लिए प्रभावी कीटनाशकों का उपयोग करें।",
        timing_hint: "फसल के शुरुआती विकास चरण में लागू करें।"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "परजीवी कीटों का उपयोग करके प्राकृतिक नियंत्रण को बढ़ावा दें।",
        timing_hint: "जब हॉपर की जनसंख्या बढ़ने लगे।"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "फसल चक्र",
        description: "फसल चक्र का पालन करें ताकि कीटों के जीवन चक्र को बाधित किया जा सके।",
        timing_hint: "फसल के बाद फसल बदलें।"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "गन्ना (CoC671)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "मक्का (संकर)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "चावल (बासमती)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # गन्ना मिलीबग
      pest = TempPest.find_or_initialize_by(name: "गन्ना मिलीबग", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Saccharicoccus sacchari",
        family: "Pseudococcidae",
        order: "Hemiptera",
        description: "गन्ना मिलीबग गन्ना और मक्का पर गंभीर नुकसान पहुंचा सकता है। यह पौधों के रस को चूसकर उन्हें कमजोर करता है, जिससे पत्तियों का पीला होना और अंततः पौधों की वृद्धि रुक जाती है।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "इमिडाक्लोप्रिड",
        description: "यह एक प्रभावी कीटनाशक है जो मिलीबग के खिलाफ उपयोग किया जाता है।",
        timing_hint: "पौधों के विकास के प्रारंभिक चरण में लागू करें।"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी wasps",
        description: "यह प्राकृतिक शत्रु हैं जो मिलीबग की जनसंख्या को नियंत्रित करने में मदद करते हैं।",
        timing_hint: "जब मिलीबग की उपस्थिति बढ़ने लगे।"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "सफाई और फसल चक्र",
        description: "सफाई और फसल चक्र का पालन करने से मिलीबग के प्रकोप को कम किया जा सकता है।",
        timing_hint: "फसल के बाद और अगली फसल से पहले।"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "गन्ना (CoC671)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "मक्का (संकर)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # लाल ताड़ वीविल
      pest = TempPest.find_or_initialize_by(name: "लाल ताड़ वीविल", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Rhynchophorus ferrugineus",
        family: "Curculionidae",
        order: "Coleoptera",
        description: "लाल ताड़ वीविल नारियल के पेड़ों में गंभीर नुकसान पहुंचाता है। यह पेड़ के तने में सुरंगें बनाता है, जिससे पेड़ की संरचना कमजोर हो जाती है और अंततः पेड़ की मृत्यु हो सकती है।",
        occurrence_season: "गर्मी और मानसून"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 1200,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "इंसेक्टिसाइड का छिड़काव",
        description: "लाल ताड़ वीविल के नियंत्रण के लिए प्रभावी कीटनाशकों का उपयोग करें।",
        timing_hint: "प्रारंभिक संक्रमण के समय"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "लाल ताड़ वीविल के प्राकृतिक शत्रुओं का उपयोग करें।",
        timing_hint: "सभी मौसमों में"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "सफाई और प्रबंधन",
        description: "नारियल के बागों में नियमित सफाई और प्रबंधन करें।",
        timing_hint: "साल भर"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "नारियल (लंबा)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # नारियल गेंडा बीटल
      pest = TempPest.find_or_initialize_by(name: "नारियल गेंडा बीटल", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Oryctes rhinoceros",
        family: "Scarabaeidae",
        order: "Coleoptera",
        description: "नारियल गेंडा बीटल पौधों की जड़ों को नुकसान पहुँचाता है, जिससे पौधों की वृद्धि रुक जाती है और अंततः पौधे की मृत्यु हो सकती है। यह बीटल नारियल के पेड़ों के तने में भी घुसपैठ कर सकता है, जिससे पेड़ कमजोर हो जाते हैं।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 15,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 1200,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "इंसेक्टिसाइड का उपयोग",
        description: "बीटल के नियंत्रण के लिए प्रभावी कीटनाशकों का छिड़काव करें।",
        timing_hint: "बीटल की गतिविधि के प्रारंभिक चरण में लागू करें।"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "परजीवी कीटों का उपयोग करके नारियल गेंडा बीटल की जनसंख्या को नियंत्रित करें।",
        timing_hint: "जब बीटल की जनसंख्या बढ़ रही हो।"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "सफाई और निवारक उपाय",
        description: "खेतों में सफाई रखें और मृत पौधों को हटाएं।",
        timing_hint: "साल भर में नियमित रूप से।"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "नारियल (लंबा)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # बैंगन फल और शूट बोरर
      pest = TempPest.find_or_initialize_by(name: "बैंगन फल और शूट बोरर", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Leucinodes orbonalis",
        family: "Crambidae",
        order: "Lepidoptera",
        description: "बैंगन फल और शूट बोरर पौधों के तनों और फलों में सुरंगें बनाते हैं, जिससे पौधों की वृद्धि रुक जाती है और फल सड़ने लगते हैं। यह कीट बैंगन की फसल को गंभीर नुकसान पहुंचा सकता है।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "इंसेक्टिसाइड का छिड़काव",
        description: "प्रभावित पौधों पर उचित कीटनाशक का छिड़काव करें।",
        timing_hint: "कीट की पहली उपस्थिति के समय"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "परजीवी कीटों का उपयोग करके बैंगन फल और शूट बोरर की जनसंख्या को नियंत्रित करें।",
        timing_hint: "कीटों की उपस्थिति के प्रारंभिक चरण में"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "फसल चक्र",
        description: "फसल चक्र का पालन करें ताकि कीटों के जीवन चक्र को बाधित किया जा सके।",
        timing_hint: "फसल के मौसम के अनुसार"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "बैंगन", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # टमाटर फल बोरर
      pest = TempPest.find_or_initialize_by(name: "टमाटर फल बोरर", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Helicoverpa armigera",
        family: "Noctuidae",
        order: "Lepidoptera",
        description: "टमाटर फल बोरर पौधों के फल के अंदर घुसकर उन्हें नुकसान पहुँचाता है, जिससे फल सड़ने लगते हैं और उत्पादन में कमी आती है। यह कीट बैंगन के फल को भी प्रभावित करता है, जिससे फल की गुणवत्ता और उपज पर नकारात्मक प्रभाव पड़ता है।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: 300
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "इंसेक्टिसाइड का छिड़काव",
        description: "टमाटर फल बोरर के नियंत्रण के लिए प्रभावी कीटनाशकों का उपयोग करें।",
        timing_hint: "फसल के विकास के प्रारंभिक चरण में और कीट की उपस्थिति के समय"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "टमाटर फल बोरर के प्राकृतिक शत्रुओं का उपयोग करें।",
        timing_hint: "फसल के विकास के दौरान"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "फसल चक्र",
        description: "फसल चक्र अपनाकर कीटों की आबादी को नियंत्रित करें।",
        timing_hint: "फसल के बाद"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "टमाटर (पूसा रूबी)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "बैंगन (बैंगन)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # भिंडी फल बोरर
      pest = TempPest.find_or_initialize_by(name: "भिंडी फल बोरर", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Earias biplaga",
        family: "Noctuidae",
        order: "Lepidoptera",
        description: "यह कीट बैंगन और टमाटर के फलों में सुरंगें बनाता है, जिससे फल सड़ने लगते हैं और उत्पादन में कमी आती है। यह कीट पौधों के विकास को भी प्रभावित करता है।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "पेस्टीसाइड का छिड़काव",
        description: "कीटों को नियंत्रित करने के लिए प्रभावी कीटनाशकों का उपयोग करें।",
        timing_hint: "फसल के विकास के प्रारंभिक चरण में"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "परजीवी कीटों का उपयोग करके प्राकृतिक संतुलन बनाए रखें।",
        timing_hint: "फसल के विकास के दौरान"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "फसल चक्रण",
        description: "फसल चक्रण का अभ्यास करें ताकि कीटों की आबादी को नियंत्रित किया जा सके।",
        timing_hint: "हर मौसम में"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "बैंगन", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "टमाटर (पूसा रूबी)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # मिर्च थ्रिप्स
      pest = TempPest.find_or_initialize_by(name: "मिर्च थ्रिप्स", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Scirtothrips dorsalis",
        family: "Thripidae",
        order: "Thysanoptera",
        description: "मिर्च थ्रिप्स पौधों के पत्तों और फलों पर छोटे धब्बे और रंग परिवर्तन का कारण बनते हैं। यह पौधों की वृद्धि को प्रभावित करते हैं और फल की गुणवत्ता को कम करते हैं।",
        occurrence_season: "गर्मी का मौसम"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "इमिडाक्लोप्रिड",
        description: "यह एक प्रभावी कीटनाशक है जो थ्रिप्स को नियंत्रित करने में मदद करता है।",
        timing_hint: "पौधों के विकास के प्रारंभिक चरण में लागू करें।"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "नैचुरल प्रीडेटर्स",
        description: "थ्रिप्स के प्राकृतिक शिकारियों का उपयोग करना, जैसे कि लेडीबग्स।",
        timing_hint: "जब थ्रिप्स की जनसंख्या बढ़ने लगे।"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "साफ-सफाई",
        description: "फसल के अवशेषों को हटाना और फसल चक्र का पालन करना।",
        timing_hint: "फसल के बाद और बुवाई से पहले।"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "टमाटर (पूसा रूबी)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "बैंगन (बैंगन)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "मिर्च (गुंटूर)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # गोभी डायमंडबैक मोथ
      pest = TempPest.find_or_initialize_by(name: "गोभी डायमंडबैक मोथ", is_reference: true, region: 'in')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Plutella xylostella",
        family: "Plutellidae",
        order: "Lepidoptera",
        description: "गोभी डायमंडबैक मोथ की लार्वा पत्तों के अंदर छिपकर खाती है, जिससे पत्तों में छिद्र और नुकसान होता है। यह विशेष रूप से पत्ता गोभी, फूल गोभी और सरसों पर गंभीर प्रभाव डालती है।",
        occurrence_season: "गर्मी और मानसून के मौसम में"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 30
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "पेस्टीसाइड का उपयोग",
        description: "गोभी डायमंडबैक मोथ के नियंत्रण के लिए प्रभावी पेस्टीसाइड का छिड़काव करें।",
        timing_hint: "लार्वा की उपस्थिति के समय"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "परजीवी कीटों का उपयोग",
        description: "परजीवी कीटों का उपयोग करके प्राकृतिक नियंत्रण करें।",
        timing_hint: "प्रारंभिक विकास चरण में"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "फसल चक्रण",
        description: "फसल चक्रण का अभ्यास करें ताकि कीटों की आबादी को नियंत्रित किया जा सके।",
        timing_hint: "फसल के बाद"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "पत्ता गोभी (गोल्डन एकर)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "फूल गोभी (स्नोबॉल)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "सरसों (पूसा बोल्ड)", is_reference: true, region: 'in')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
  end
end
