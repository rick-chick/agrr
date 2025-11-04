# frozen_string_literal: true

class DataMigrationJapanReferencePests < ActiveRecord::Migration[8.0]
  # 一時モデル定義（マイグレーション内でのみ使用）
  # モデルクラスへの依存を避け、スキーマ変更に強い設計
  
  class TempPest < ActiveRecord::Base
    self.table_name = 'pests'
    has_one :pest_temperature_profile, class_name: 'DataMigrationJapanReferencePests::TempPestTemperatureProfile', foreign_key: 'pest_id'
    has_one :pest_thermal_requirement, class_name: 'DataMigrationJapanReferencePests::TempPestThermalRequirement', foreign_key: 'pest_id'
    has_many :pest_control_methods, class_name: 'DataMigrationJapanReferencePests::TempPestControlMethod', foreign_key: 'pest_id'
    has_many :crop_pests, class_name: 'DataMigrationJapanReferencePests::TempCropPest', foreign_key: 'pest_id'
  end
  
  class TempPestTemperatureProfile < ActiveRecord::Base
    self.table_name = 'pest_temperature_profiles'
    belongs_to :pest, class_name: 'DataMigrationJapanReferencePests::TempPest', foreign_key: 'pest_id'
  end
  
  class TempPestThermalRequirement < ActiveRecord::Base
    self.table_name = 'pest_thermal_requirements'
    belongs_to :pest, class_name: 'DataMigrationJapanReferencePests::TempPest', foreign_key: 'pest_id'
  end
  
  class TempPestControlMethod < ActiveRecord::Base
    self.table_name = 'pest_control_methods'
    belongs_to :pest, class_name: 'DataMigrationJapanReferencePests::TempPest', foreign_key: 'pest_id'
  end
  
  class TempCropPest < ActiveRecord::Base
    self.table_name = 'crop_pests'
    belongs_to :pest, class_name: 'DataMigrationJapanReferencePests::TempPest', foreign_key: 'pest_id'
    belongs_to :crop, class_name: 'DataMigrationJapanReferencePests::TempCrop', foreign_key: 'crop_id'
  end
  
  class TempCrop < ActiveRecord::Base
    self.table_name = 'crops'
  end
  
  def up
    say "🌱 Seeding Japan (jp) reference pests..."
    
    seed_reference_pests
    
    say "✅ Japan reference pests seeding completed!"
  end
  
  def down
    say "🗑️  Removing Japan (jp) reference pests..."
    
    # Find pests by region
    pest_ids = TempPest.where(region: 'jp', is_reference: true).pluck(:id)
    
    # Delete related records
    TempCropPest.where(pest_id: pest_ids).delete_all
    TempPestControlMethod.where(pest_id: pest_ids).delete_all
    TempPestThermalRequirement.where(pest_id: pest_ids).delete_all
    TempPestTemperatureProfile.where(pest_id: pest_ids).delete_all
    TempPest.where(region: 'jp', is_reference: true).delete_all
    
    say "✅ Japan reference pests removed"
  end
  
  private
  
  def seed_reference_pests
      # アオムシ
      pest = TempPest.find_or_initialize_by(name: "アオムシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Plutella xylostella",
        family: "チョウ科",
        order: "チョウ目",
        description: "アオムシはキャベツやブロッコリーの葉を食害し、葉の表面に穴を開けたり、葉全体を食べ尽くすことがあります。特に幼虫の段階での被害が顕著で、成長を妨げるだけでなく、収穫量にも大きな影響を与えます。",
        occurrence_season: "春〜秋"
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
          required_gdd: 300,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "殺虫剤",
        description: "アオムシに対して効果的な殺虫剤を使用することで、幼虫の発生を抑制します。",
        timing_hint: "幼虫が発生する前に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "アオムシの天敵である寄生蜂や捕食者を放飼することで、自然にアオムシの数を減少させます。",
        timing_hint: "アオムシの発生が確認された時期に放飼します。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ブロッコリー", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # アザミウマ
      pest = TempPest.find_or_initialize_by(name: "アザミウマ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Frankliniella occidentalis",
        family: "アザミウマ科",
        order: "双翅目",
        description: "アザミウマは、トマト、キュウリ、レタス、ピーマン、ナス、ニンジン、ジャガイモ、キャベツに対して、葉の表面に小さな白い斑点を形成し、葉の変色や枯れを引き起こします。また、果実にも影響を及ぼし、品質を低下させることがあります。",
        occurrence_season: "春〜秋"
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
        method_name: "殺虫剤",
        description: "アザミウマに対して効果的な殺虫剤を使用します。特に、成虫と幼虫の両方に効果があります。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "アザミウマの天敵である捕食性の昆虫を放飼することで、自然に抑制します。",
        timing_hint: "発生が確認された時点で放飼を開始します。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "アザミウマの発生を抑えるために、作物の輪作を行います。",
        timing_hint: "毎年異なる作物を栽培することが重要です。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "レタス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ピーマン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ナス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ニンジン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ジャガイモ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # アブラムシ
      pest = TempPest.find_or_initialize_by(name: "アブラムシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Aphidoidea",
        family: "アブラムシ科",
        order: "半翅目",
        description: "アブラムシは、キャベツ、ブロッコリー、レタス、ほうれん草、トマト、ピーマンなどの作物に被害を与えます。これらの作物の葉の裏に集まり、汁を吸うことで成長を妨げ、葉の変色や萎縮を引き起こします。また、ウイルス病の媒介者としても知られています。",
        occurrence_season: "春〜秋"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 5,
          max_temperature: 30
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
        method_name: "殺虫剤",
        description: "アブラムシに対して効果的な殺虫剤を使用します。特に、成虫と幼虫の両方に効果があります。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "アブラムシの天敵であるテントウムシや寄生蜂を放飼することで、自然にアブラムシの数を減少させます。",
        timing_hint: "アブラムシの発生が確認された時期に放飼します。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "アブラムシの発生を抑えるために、同じ作物を連続して栽培しないようにします。",
        timing_hint: "作物の栽培計画に組み込むことが重要です。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ブロッコリー", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "レタス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ほうれん草", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ピーマン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # イラガ
      pest = TempPest.find_or_initialize_by(name: "イラガ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Lymantria dispar",
        family: "タマムシ科",
        order: "チョウ目",
        description: "イラガは、トマト、ナス、ピーマン、ジャガイモ、キュウリ、レタスに対して著しい被害を与えます。幼虫は葉を食害し、特に若い植物に対して深刻な影響を及ぼします。葉の食害により光合成が妨げられ、最終的には植物の成長が阻害されます。",
        occurrence_season: "春〜秋"
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
        method_name: "殺虫剤",
        description: "イラガに対して効果的な殺虫剤を使用します。特に幼虫の発生時期に散布することが重要です。",
        timing_hint: "幼虫の初期発生時"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "イラガの天敵である寄生蜂を放飼することで、自然に抑制します。",
        timing_hint: "春〜初夏"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "イラガの発生を抑えるために、作物の輪作を行います。",
        timing_hint: "毎年"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ナス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ピーマン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ジャガイモ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "レタス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # ウリハムシ
      pest = TempPest.find_or_initialize_by(name: "ウリハムシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Aulacophora foveicollis",
        family: "ハムシ科",
        order: "コウチュウ目",
        description: "ウリハムシは、キュウリ、ナス、トマト、ピーマン、キャベツ、レタス、ニンジンなどの作物に対して被害を与えます。葉を食害し、特に若い葉や果実に穴をあけることで、成長を妨げ、収量を減少させます。また、植物の汁を吸うことで、全体的な健康状態を悪化させることがあります。",
        occurrence_season: "春〜秋"
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
          first_generation_gdd: 200
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "殺虫剤",
        description: "ウリハムシに対して効果的な殺虫剤を使用します。特に幼虫や成虫に対して効果があります。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "ウリハムシの天敵である捕食者を放飼することで、自然に抑制します。",
        timing_hint: "ウリハムシの発生が確認された時期に行います。"
      )
      pest.pest_control_methods.create!(
        method_type: "physical",
        method_name: "トラップ",
        description: "粘着トラップを使用して成虫を捕獲します。",
        timing_hint: "発生初期から設置します。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "ウリハムシの発生を抑えるために、作物の輪作を行います。",
        timing_hint: "毎年異なる作物を栽培することが重要です。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ナス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ピーマン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "レタス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ニンジン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # ウンカ
      pest = TempPest.find_or_initialize_by(name: "ウンカ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Nilaparvata lugens",
        family: "デルフィニウム科",
        order: "半翅目",
        description: "ウンカは、稲作において特に被害をもたらす害虫で、葉の裏に寄生し、植物の汁を吸うことで成長を妨げます。これにより、葉が黄変し、最終的には枯死することがあります。また、ウンカはウイルス病の媒介者でもあり、感染した植物は生育不良を引き起こします。",
        occurrence_season: "春〜秋"
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
        method_name: "殺虫剤",
        description: "化学的手段でウンカを駆除するための薬剤を使用します。",
        timing_hint: "発生初期に散布することが効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "ウンカの天敵である捕食者を放飼し、自然のバランスを保ちます。",
        timing_hint: "ウンカの発生が確認された時期に行います。"
      )

      # カイガラムシ
      pest = TempPest.find_or_initialize_by(name: "カイガラムシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Coccoidea",
        family: "カイガラムシ科",
        order: "半翅目",
        description: "カイガラムシは、トマトやピーマンに被害を与える害虫で、植物の汁を吸うことで成長を妨げ、葉の変色や枯れを引き起こします。また、分泌する蜜露により、すす病を引き起こすこともあります。",
        occurrence_season: "春〜秋"
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
        method_name: "殺虫剤",
        description: "カイガラムシに対して効果的な殺虫剤を使用します。特に、成虫と幼虫の両方に効果があります。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "カイガラムシの天敵である捕食者を放飼することで、自然に抑制します。",
        timing_hint: "春から夏にかけての発生時期に行います。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ピーマン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # カミキリムシ
      pest = TempPest.find_or_initialize_by(name: "カミキリムシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Cerambycidae",
        family: "カミキリムシ科",
        order: "コウチュウ目",
        description: "カミキリムシは、木材を食害し、特に樹木の内部を食べることで構造的な損傷を引き起こします。これにより、樹木が弱体化し、最終的には枯死することがあります。",
        occurrence_season: "春〜秋"
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
        method_name: "殺虫剤散布",
        description: "カミキリムシに対して効果的な殺虫剤を散布します。",
        timing_hint: "成虫の活動が始まる春に散布します。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "カミキリムシの天敵を放飼して、自然のバランスを保ちます。",
        timing_hint: "春から夏にかけて行います。"
      )

      # カメムシ
      pest = TempPest.find_or_initialize_by(name: "カメムシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Pentatomidae",
        family: "カメムシ科",
        order: "半翅目",
        description: "カメムシは、トマト、ピーマン、キュウリ、ナス、ジャガイモ、ニンジン、キャベツ、レタスに対して、吸汁による被害を引き起こします。これにより、植物の成長が阻害され、果実や葉に斑点や変色が見られることがあります。",
        occurrence_season: "春〜秋"
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
        method_name: "殺虫剤",
        description: "カメムシに対して効果的な殺虫剤を使用します。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "カメムシの天敵を放飼することで、自然に抑制します。",
        timing_hint: "春に放飼することが効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "physical",
        method_name: "トラップ",
        description: "粘着トラップを使用してカメムシを捕獲します。",
        timing_hint: "発生が確認された時期に設置します。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "カメムシの発生を抑えるために、作物の輪作を行います。",
        timing_hint: "毎年異なる作物を栽培することが推奨されます。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ピーマン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ナス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ジャガイモ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ニンジン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "レタス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # キアゲハの幼虫
      pest = TempPest.find_or_initialize_by(name: "キアゲハの幼虫", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Papilio machaon",
        family: "タテハチョウ科",
        order: "チョウ目",
        description: "キアゲハの幼虫は、キャベツ、ブロッコリー、大根、ほうれん草、ピーマン、トマト、ナス、ジャガイモなどの葉を食害します。特に若い葉を好み、食害が進むと植物の成長が阻害され、収穫量が減少します。",
        occurrence_season: "春〜秋"
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
          first_generation_gdd: 300
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "殺虫剤",
        description: "キアゲハの幼虫に対して効果的な殺虫剤を使用します。",
        timing_hint: "幼虫が発生した初期段階で散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "キアゲハの幼虫を捕食する天敵を放飼することで、自然に抑制します。",
        timing_hint: "幼虫が発生する前に天敵を放飼することが効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "physical",
        method_name: "手作業での捕獲",
        description: "幼虫を手作業で捕獲し、除去します。",
        timing_hint: "定期的に作物を点検し、幼虫を見つけ次第捕獲します。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "キアゲハの好む作物を輪作することで、発生を抑制します。",
        timing_hint: "毎年作物を変えることが推奨されます。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ブロッコリー", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "大根", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ほうれん草", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ピーマン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ナス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ジャガイモ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # コガネムシ
      pest = TempPest.find_or_initialize_by(name: "コガネムシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Phyllophaga spp.",
        family: "コガネムシ科",
        order: "甲虫目",
        description: "コガネムシは、ジャガイモ、ニンジン、キャベツ、レタス、トマト、ピーマン、キュウリに対して根を食害し、植物の成長を妨げる。特に幼虫が根を食べることで、植物が水分や栄養を吸収できなくなり、枯死することもある。",
        occurrence_season: "春〜秋"
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
        method_name: "殺虫剤",
        description: "コガネムシの幼虫や成虫に対して効果的な殺虫剤を使用する。",
        timing_hint: "発生初期に散布することが推奨される。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の利用",
        description: "コガネムシの天敵である寄生蜂を利用して、自然に抑制する。",
        timing_hint: "発生が確認された時期に放飼する。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "輪作",
        description: "コガネムシの発生を抑えるために、同じ作物を連作しない。",
        timing_hint: "毎年作物を変えることが重要。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "ジャガイモ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ニンジン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "レタス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ピーマン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # コナジラミ
      pest = TempPest.find_or_initialize_by(name: "コナジラミ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Trialeurodes vaporariorum",
        family: "白蝉科",
        order: "半翅目",
        description: "コナジラミは、トマト、キュウリ、レタス、ジャガイモ、ピーマン、ナス、ニンジン、キャベツ、ブロッコリーに被害を与えます。主に葉の裏に生息し、植物の汁を吸うことで成長を妨げ、葉の黄変や落葉を引き起こします。また、ウイルス病の媒介者としても知られています。",
        occurrence_season: "春〜秋"
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
        method_name: "殺虫剤",
        description: "コナジラミに対して効果的な殺虫剤を使用します。特に、成虫と幼虫の両方に効果があります。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "コナジラミの天敵である捕食性昆虫を放飼することで、自然にコナジラミの数を減少させます。",
        timing_hint: "コナジラミの発生が確認された時期に放飼します。"
      )
      pest.pest_control_methods.create!(
        method_type: "physical",
        method_name: "粘着トラップ",
        description: "粘着トラップを使用して成虫を捕獲し、個体数を減少させます。",
        timing_hint: "発生初期から設置することが効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "コナジラミの発生を抑えるために、異なる作物を輪作することが推奨されます。",
        timing_hint: "作物の栽培計画に組み込むことが重要です。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "レタス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ジャガイモ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ピーマン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ナス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ニンジン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ブロッコリー", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # コオロギ
      pest = TempPest.find_or_initialize_by(name: "コオロギ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Gryllus campestris",
        family: "バッタ科",
        order: "直翅目",
        description: "コオロギは、葉や果実を食害し、特に若い植物に対して深刻な損傷を引き起こすことがあります。食害の結果、植物の成長が阻害され、収穫量が減少する可能性があります。",
        occurrence_season: "春〜秋"
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
          required_gdd: 300,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "殺虫剤",
        description: "コオロギに対して効果的な殺虫剤を使用します。特に幼虫期に適用することが推奨されます。",
        timing_hint: "幼虫期に適用"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "コオロギの天敵である捕食者を放飼することで、自然にコオロギの数を減少させます。",
        timing_hint: "発生初期に放飼"
      )

      # ジャンボタニシ
      pest = TempPest.find_or_initialize_by(name: "ジャンボタニシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Pomacea canaliculata",
        family: "タニシ科",
        order: "腹足目",
        description: "ジャンボタニシは、ジャガイモ、キュウリ、トマト、ナス、キャベツ、レタスなどの作物に対して深刻な被害を与えます。特に葉や茎を食害し、成長を妨げることがあります。食害の結果、作物の生産性が低下し、品質が損なわれることがあります。",
        occurrence_season: "春〜秋"
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
        method_name: "農薬散布",
        description: "ジャンボタニシに対して効果的な農薬を散布します。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の導入",
        description: "ジャンボタニシの天敵を導入して、自然に抑制します。",
        timing_hint: "春に導入することが効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "physical",
        method_name: "手作業での除去",
        description: "手作業でジャンボタニシを取り除きます。",
        timing_hint: "早期発見が重要です。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "水管理",
        description: "水位を管理して、ジャンボタニシの繁殖を抑制します。",
        timing_hint: "生育期に注意が必要です。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "ジャガイモ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ナス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "レタス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # シロイチモジヨトウ
      pest = TempPest.find_or_initialize_by(name: "シロイチモジヨトウ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Agrotis segetum",
        family: "ノコギリバエ科",
        order: "チョウ目",
        description: "シロイチモジヨトウは、トマト、ナス、ピーマン、ジャガイモ、キャベツ、ブロッコリー、ニンジン、レタス、キュウリに対して被害を与えます。幼虫は葉を食害し、特に若い植物に対して深刻な損傷を引き起こすことがあります。葉の食害により光合成が妨げられ、最終的には作物の成長が阻害されることがあります。",
        occurrence_season: "春〜秋"
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
        method_name: "殺虫剤",
        description: "シロイチモジヨトウに対して効果的な殺虫剤を使用します。特に幼虫の発生時期に散布することが推奨されます。",
        timing_hint: "幼虫の発生時期"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "シロイチモジヨトウの天敵である寄生蜂を放飼することで、自然に抑制します。",
        timing_hint: "発生初期"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ナス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ピーマン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ジャガイモ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ブロッコリー", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ニンジン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "レタス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # センチュウ
      pest = TempPest.find_or_initialize_by(name: "センチュウ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Meloidogyne spp.",
        family: "ハリセンボン科",
        order: "線虫目",
        description: "センチュウは、トマト、キュウリ、レタス、ジャガイモ、ニンジン、キャベツ、ブロッコリーに対して根に寄生し、根の成長を阻害します。これにより、植物は栄養を吸収できず、成長が遅れ、最終的には枯死することがあります。特に根の腫れや変形が見られ、これが作物の収量に大きな影響を与えます。",
        occurrence_season: "春〜秋"
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
        method_name: "土壌消毒",
        description: "化学薬品を使用して土壌中のセンチュウを殺す方法です。",
        timing_hint: "植え付け前に実施"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "センチュウを捕食する天敵を放つことで、自然に抑制する方法です。",
        timing_hint: "センチュウの発生が確認された時期に実施"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "輪作",
        description: "センチュウの好まない作物を栽培することで、発生を抑える方法です。",
        timing_hint: "毎年作物を変える"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "レタス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ジャガイモ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ニンジン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ブロッコリー", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # タバコガ・オオタバコガ
      pest = TempPest.find_or_initialize_by(name: "タバコガ・オオタバコガ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Heliothis virescens",
        family: "夜蛾科",
        order: "チョウ目",
        description: "タバコガは、トマト、ジャガイモ、ナス、ピーマン、キャベツに対して深刻な被害をもたらします。幼虫は葉を食害し、特に新芽や花に対して大きな損傷を引き起こします。これにより、作物の成長が阻害され、収量が減少します。",
        occurrence_season: "春〜秋"
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
        method_name: "殺虫剤",
        description: "タバコガに対して効果的な殺虫剤を使用します。特に幼虫の発生時期に散布することが推奨されます。",
        timing_hint: "幼虫の発生時期"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "タバコガの天敵である寄生蜂を放飼することで、自然に抑制します。",
        timing_hint: "春〜夏"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "タバコガの発生を抑えるために、作物の輪作を行います。",
        timing_hint: "年次計画"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ジャガイモ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ナス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ピーマン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # ツマジロクサヨトウ
      pest = TempPest.find_or_initialize_by(name: "ツマジロクサヨトウ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Spodoptera litura",
        family: "ノミバエ科",
        order: "チョウ目",
        description: "ツマジロクサヨトウは、ジャガイモ、トマト、ナス、ピーマン、キュウリに対して著しい食害を引き起こします。幼虫は葉を食べ尽くし、特に若い植物に対して深刻な被害をもたらします。葉の表面に穴を開け、植物の成長を妨げることがあります。",
        occurrence_season: "春〜秋"
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
        method_name: "殺虫剤",
        description: "ツマジロクサヨトウに対して効果的な殺虫剤を使用します。特に幼虫の発生時期に散布することが推奨されます。",
        timing_hint: "幼虫の初期発生時"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "ツマジロクサヨトウの天敵である寄生蜂を放飼することで、自然に抑制します。",
        timing_hint: "発生初期"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "ツマジロクサヨトウの発生を抑えるために、作物の輪作を行います。",
        timing_hint: "毎年"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "ジャガイモ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ナス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ピーマン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # テントウムシ
      pest = TempPest.find_or_initialize_by(name: "テントウムシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Coccinella septempunctata",
        family: "テントウムシ科",
        order: "コウチュウ目",
        description: "テントウムシは、キャベツ、ブロッコリー、レタス、ほうれん草、トマト、ピーマン、ナス、キュウリ、ジャガイモ、ニンジンに対して被害を与えます。特に幼虫は葉を食害し、植物の成長を妨げることがあります。成虫も葉の表面を食べることがあり、特に若い植物に対して深刻な影響を及ぼすことがあります。",
        occurrence_season: "春〜秋"
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
          required_gdd: 300,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "殺虫剤",
        description: "テントウムシに対して効果的な殺虫剤を使用します。特に幼虫の発生時期に散布することが推奨されます。",
        timing_hint: "幼虫の発生時期"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "テントウムシの天敵である寄生蜂や捕食者を放飼することで、自然に抑制します。",
        timing_hint: "発生初期"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "テントウムシの発生を抑えるために、作物の輪作を行います。",
        timing_hint: "毎年"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ブロッコリー", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "レタス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ほうれん草", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ピーマン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ナス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ジャガイモ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ニンジン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # テントウムシダマシ
      pest = TempPest.find_or_initialize_by(name: "テントウムシダマシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Harmonia axyridis",
        family: "テントウムシ科",
        order: "コウチュウ目",
        description: "テントウムシダマシは、キャベツ、ブロッコリー、大根、ほうれん草、ピーマン、トマト、ナス、キュウリに対して被害を与えます。これらの作物の葉に穴をあけ、成長を妨げることがあります。また、果実にも影響を及ぼし、品質を低下させることがあります。",
        occurrence_season: "春〜秋"
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
        method_name: "殺虫剤",
        description: "テントウムシダマシに対して効果的な殺虫剤を使用します。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "テントウムシダマシの天敵を放飼することで、自然に抑制します。",
        timing_hint: "春に放飼することが効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "physical",
        method_name: "手作業での除去",
        description: "目視で確認し、手作業で除去します。",
        timing_hint: "定期的に行うことが重要です。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "作物の輪作を行うことで、テントウムシダマシの発生を抑制します。",
        timing_hint: "毎年異なる作物を栽培することが推奨されます。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ブロッコリー", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "大根", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ほうれん草", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ピーマン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ナス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # ナミアゲハの幼虫
      pest = TempPest.find_or_initialize_by(name: "ナミアゲハの幼虫", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Papilio machaon",
        family: "アゲハチョウ科",
        order: "チョウ目",
        description: "ナミアゲハの幼虫は、キャベツ、ブロッコリー、大根の葉を食害します。特に若い葉を好み、葉の表面を食べることで、植物の成長を妨げ、収穫量を減少させることがあります。",
        occurrence_season: "春〜秋"
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
        method_name: "殺虫剤",
        description: "ナミアゲハの幼虫に対して効果的な殺虫剤を使用します。",
        timing_hint: "幼虫が発生した初期段階で散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "ナミアゲハの幼虫を捕食する天敵を放飼することで、自然に抑制します。",
        timing_hint: "幼虫の発生が確認された時期に放飼します。"
      )
      pest.pest_control_methods.create!(
        method_type: "physical",
        method_name: "手作業での捕獲",
        description: "幼虫を手作業で捕獲し、除去します。",
        timing_hint: "定期的に作物を点検し、幼虫を見つけ次第捕獲します。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ブロッコリー", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "大根", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # ナメクジ
      pest = TempPest.find_or_initialize_by(name: "ナメクジ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Limax maximus",
        family: "ナメクジ科",
        order: "腹足目",
        description: "ナメクジは、レタス、キャベツ、ほうれん草、ブロッコリー、ニンジン、ジャガイモ、トマト、ピーマン、キュウリに対して、葉を食害し、特に若い植物に深刻な損傷を与えることがあります。食害の結果、植物は成長が遅れ、収穫量が減少する可能性があります。",
        occurrence_season: "春〜秋"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 5,
          max_temperature: 30
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
        method_name: "殺虫剤",
        description: "ナメクジに対して効果的な殺虫剤を使用することで、個体数を減少させることができます。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の利用",
        description: "ナメクジの天敵である捕食者を利用することで、自然に個体数を抑制します。",
        timing_hint: "春から夏にかけての発生時期に導入します。"
      )
      pest.pest_control_methods.create!(
        method_type: "physical",
        method_name: "障壁の設置",
        description: "ナメクジの侵入を防ぐために、物理的な障壁を設置します。",
        timing_hint: "植え付け前に設置することが効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "農業慣行の改善",
        description: "土壌の水はけを良くし、雑草を管理することで、ナメクジの生息環境を減少させます。",
        timing_hint: "年間を通じて実施することが重要です。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "レタス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ほうれん草", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ブロッコリー", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ニンジン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ジャガイモ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ピーマン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # ネキリムシ
      pest = TempPest.find_or_initialize_by(name: "ネキリムシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Agrotis ipsilon",
        family: "ノシメマダラガ科",
        order: "チョウ目",
        description: "ネキリムシは、ジャガイモ、トマト、キャベツ、ニンジン、レタス、キュウリ、ピーマン、ナスに対して深刻な被害を与えます。幼虫は根元や茎を食害し、植物を倒すことがあります。特に若い苗に対して致命的な影響を及ぼすことが多いです。",
        occurrence_season: "春〜秋"
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
        method_name: "殺虫剤",
        description: "ネキリムシに対して効果的な殺虫剤を使用します。特に幼虫の発生時期に散布することが重要です。",
        timing_hint: "幼虫の発生時期"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "ネキリムシの天敵である寄生蜂を放飼することで、自然に抑制します。",
        timing_hint: "発生初期"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "ネキリムシの発生を抑えるために、作物を輪作することが推奨されます。",
        timing_hint: "毎年"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "ジャガイモ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ニンジン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "レタス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ピーマン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ナス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # ハダニ
      pest = TempPest.find_or_initialize_by(name: "ハダニ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Tetranychus urticae",
        family: "クモ科",
        order: "クモ目",
        description: "ハダニは、トマト、キュウリ、レタス、ジャガイモ、ピーマン、ニンジンに被害を与えます。葉の裏に生息し、植物の汁を吸うことで、葉が黄変し、枯れることがあります。特に乾燥した環境で繁殖しやすく、被害が広がると生育が著しく阻害されます。",
        occurrence_season: "春〜秋"
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
        method_name: "アブラムシ用農薬",
        description: "ハダニに対して効果的な農薬を使用します。特に発生初期に散布することが重要です。",
        timing_hint: "発生初期"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "ハダニの天敵である捕食性ダニを放飼することで、自然に抑制します。",
        timing_hint: "発生時期"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "水分管理",
        description: "適切な水分管理を行い、乾燥を防ぐことでハダニの発生を抑えます。",
        timing_hint: "生育期間中"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "レタス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ジャガイモ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ピーマン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ニンジン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # ハムシ
      pest = TempPest.find_or_initialize_by(name: "ハムシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Phyllotreta spp.",
        family: "コウチュウ科",
        order: "コウチュウ目",
        description: "ハムシは、キャベツ、ブロッコリー、大根、ジャガイモ、トマト、ピーマン、ナスに被害を与えます。葉の表面に小さな穴を開け、葉を食害することで、植物の成長を妨げます。特に若い葉や新芽に対して被害が大きく、重度の感染では植物全体の生育が阻害されることがあります。",
        occurrence_season: "春〜秋"
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
          required_gdd: 300,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "殺虫剤",
        description: "ハムシに対して効果的な殺虫剤を使用します。特に幼虫や成虫に対して効果があります。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "ハムシの天敵である捕食者を放飼することで、自然に抑制します。",
        timing_hint: "ハムシの発生が確認された時期に放飼します。"
      )
      pest.pest_control_methods.create!(
        method_type: "physical",
        method_name: "トラップ",
        description: "粘着トラップを使用して成虫を捕獲します。",
        timing_hint: "発生初期に設置します。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "輪作",
        description: "ハムシの発生を抑えるために、同じ作物を連続して栽培しないようにします。",
        timing_hint: "作付け前に計画します。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ブロッコリー", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "大根", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ジャガイモ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ピーマン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ナス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # ハモグリバエ
      pest = TempPest.find_or_initialize_by(name: "ハモグリバエ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Liriomyza sativae",
        family: "ハモグリバエ科",
        order: "双翅目",
        description: "ハモグリバエは、トマト、ピーマン、ナス、キュウリ、ジャガイモ、キャベツ、レタス、ニンジンに被害を与えます。幼虫は葉の内部を食害し、トンネル状の傷を作ります。これにより、植物の光合成能力が低下し、最終的には生育不良や枯死を引き起こすことがあります。",
        occurrence_season: "春〜秋"
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
          required_gdd: 300,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "殺虫剤",
        description: "ハモグリバエに対して効果的な殺虫剤を使用します。特に幼虫の発生時期に散布することが推奨されます。",
        timing_hint: "幼虫の発生時期"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "ハモグリバエの天敵である寄生蜂を放飼することで、自然に個体数を抑制します。",
        timing_hint: "発生初期"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ピーマン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ナス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ジャガイモ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "レタス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ニンジン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # マダニ
      pest = TempPest.find_or_initialize_by(name: "マダニ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Ixodes ricinus",
        family: "ダニ科",
        order: "ダニ目",
        description: "マダニは、ジャガイモ、トマト、キュウリ、ニンジン、レタスに対して被害を与えます。これらの作物において、マダニは葉や茎に寄生し、植物の栄養を吸収することで成長を妨げ、最終的には作物の枯死を引き起こすことがあります。特に、葉の変色や萎縮が見られることが多いです。",
        occurrence_season: "春〜秋"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 5,
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
        method_name: "殺虫剤散布",
        description: "マダニに対して効果的な殺虫剤を散布します。特に、成虫や幼虫に対して効果があります。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "マダニの天敵となる生物を放飼することで、自然に抑制します。",
        timing_hint: "春から夏にかけての発生時期に行います。"
      )
      pest.pest_control_methods.create!(
        method_type: "physical",
        method_name: "手作業での除去",
        description: "目視で確認できるマダニを手作業で取り除きます。",
        timing_hint: "定期的に作物を点検し、見つけ次第除去します。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "ジャガイモ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ニンジン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "レタス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # メイガ
      pest = TempPest.find_or_initialize_by(name: "メイガ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Plutella xylostella",
        family: "チョウ科",
        order: "チョウ目",
        description: "メイガは、葉の内部にトンネルを掘ることで作物に損害を与えます。特にキャベツやブロッコリーなどの葉物野菜において、幼虫が葉を食害し、品質を低下させることがあります。",
        occurrence_season: "春〜秋"
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
          required_gdd: 300,
          first_generation_gdd: 150
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "殺虫剤",
        description: "メイガに対して効果的な殺虫剤を使用します。特に幼虫の発生時期に散布することが重要です。",
        timing_hint: "幼虫が発生した時期"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "メイガの天敵である寄生蜂を放飼することで、自然に抑制します。",
        timing_hint: "発生初期"
      )

      # ヨトウムシ
      pest = TempPest.find_or_initialize_by(name: "ヨトウムシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Spodoptera litura",
        family: "ノミバエ科",
        order: "チョウ目",
        description: "ヨトウムシは、キャベツ、レタス、ジャガイモ、トマト、ピーマン、ニンジン、キュウリなどの作物に対して深刻な被害を与えます。幼虫は葉を食害し、特に若い葉や新芽を好んで食べるため、作物の成長を妨げ、収量を大幅に減少させることがあります。",
        occurrence_season: "春〜秋"
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
        method_name: "殺虫剤",
        description: "ヨトウムシに対して効果的な殺虫剤を使用することで、幼虫の発生を抑制します。",
        timing_hint: "幼虫が発生する前に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "ヨトウムシの天敵である寄生蜂や捕食者を放飼することで、自然に抑制します。",
        timing_hint: "幼虫の発生が確認された時期に放飼します。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "ヨトウムシの発生を抑えるために、作物を輪作することが効果的です。",
        timing_hint: "毎年異なる作物を栽培することが推奨されます。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "レタス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ジャガイモ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ピーマン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ニンジン", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

  end
end
