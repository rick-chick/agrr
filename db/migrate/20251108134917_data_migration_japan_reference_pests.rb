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
        name_scientific: "Pieris rapae",
        family: "シロチョウ科",
        order: "チョウ目",
        description: "アオムシはキャベツ、ブロッコリー、白菜などの葉を食害し、特に若い葉を好んで食べます。食害により作物の成長が阻害され、収穫量が減少します。",
        occurrence_season: "春から秋にかけて発生します。"
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
        method_name: "殺虫剤散布",
        description: "アオムシに効果的な殺虫剤を散布します。",
        timing_hint: "幼虫が発生した初期段階で散布することが効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の利用",
        description: "寄生蜂や捕食者を利用してアオムシを抑制します。",
        timing_hint: "発生初期から天敵を放飼することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "アオムシの発生を抑えるために、作物を輪作します。",
        timing_hint: "毎年異なる作物を栽培することが効果的です。"
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
      crop = TempCrop.find_by(name: "白菜", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # アザミウマ
      pest = TempPest.find_or_initialize_by(name: "アザミウマ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Thrips tabaci",
        family: "ツヅリガ科",
        order: "チョウ目",
        description: "アザミウマは、葉の表面に小さな白い斑点を形成し、葉の変色や枯れを引き起こします。特にトマト、ピーマン、キュウリにおいて、果実の品質低下や生育不良を引き起こすことがあります。",
        occurrence_season: "春から秋にかけて発生します。"
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
        method_name: "殺虫剤散布",
        description: "アザミウマに対して効果的な殺虫剤を使用します。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "アザミウマの天敵である捕食性の昆虫を放飼します。",
        timing_hint: "発生が確認された時期に放飼します。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "アザミウマの発生を抑えるために、作物を輪作します。",
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

      # アブラムシ
      pest = TempPest.find_or_initialize_by(name: "アブラムシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Aphidoidea",
        family: "アブラムシ科",
        order: "半翅目",
        description: "アブラムシは、トマトやキュウリなどの作物に対して、葉の裏側に群生し、汁を吸うことで成長を妨げる害虫です。特に若い葉や新芽に被害を与え、葉の変色や萎縮を引き起こします。また、ウイルス病の媒介者としても知られています。",
        occurrence_season: "春から秋にかけて発生します。"
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
        method_name: "殺虫剤散布",
        description: "アブラムシに対して効果的な殺虫剤を散布します。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "アブラムシを捕食する天敵（例：テントウムシ）を放飼します。",
        timing_hint: "アブラムシの発生が確認された時期に行います。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "アブラムシの発生を抑えるために、作物を輪作します。",
        timing_hint: "毎年作物を変えることが重要です。"
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

      # イラガ
      pest = TempPest.find_or_initialize_by(name: "イラガ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Lonomia obliqua",
        family: "タテハチョウ科",
        order: "チョウ目",
        description: "イラガは、トマトやナスの葉を食害し、葉の表面に穴を開けることがあります。特に若い葉に被害が集中し、成長を妨げることがあります。また、イラガの幼虫は刺毛を持ち、接触すると皮膚に刺激を与えることがあります。",
        occurrence_season: "春から秋にかけて発生します。"
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
        description: "イラガに対して効果的な殺虫剤を散布します。",
        timing_hint: "幼虫が発生した初期段階で散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の利用",
        description: "イラガの天敵である寄生蜂を利用して、自然に抑制します。",
        timing_hint: "発生初期に天敵を放すことが効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "イラガの発生を抑えるために、作物を輪作します。",
        timing_hint: "毎年異なる作物を栽培することが望ましいです。"
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

      # ウリハムシ
      pest = TempPest.find_or_initialize_by(name: "ウリハムシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Acalymma vittatum",
        family: "コウチュウ科",
        order: "コウチュウ目",
        description: "ウリハムシは、葉を食害し、特にキュウリの葉に穴をあけることで知られています。幼虫は葉の裏側に生息し、葉を食べることで植物の成長を妨げます。",
        occurrence_season: "春から夏にかけて発生します。"
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
        method_name: "殺虫剤散布",
        description: "ウリハムシに対して効果的な殺虫剤を散布します。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の利用",
        description: "ウリハムシの天敵である捕食者を導入します。",
        timing_hint: "ウリハムシの発生が確認された時期に導入します。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "ウリ科以外の作物を栽培することで、ウリハムシの発生を抑制します。",
        timing_hint: "毎年作物を変更することが望ましいです。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
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
        description: "ウンカは、とうもろこしの葉に吸汁し、葉の黄変や枯れを引き起こします。また、ウンカが分泌する蜜露により、すす病が発生し、光合成能力が低下します。",
        occurrence_season: "春から秋にかけて発生します。"
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
        method_name: "殺虫剤散布",
        description: "効果的な殺虫剤を使用して、ウンカを駆除します。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "ウンカの天敵である捕食者を放飼し、自然に駆除します。",
        timing_hint: "ウンカの発生が確認された時期に放飼します。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "ウンカの発生を抑えるために、作物を輪作します。",
        timing_hint: "毎年作物を変更することが重要です。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "とうもろこし", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # カイガラムシ
      pest = TempPest.find_or_initialize_by(name: "カイガラムシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Coccoidea",
        family: "カイガラムシ科",
        order: "半翅目",
        description: "カイガラムシは、トマトやキュウリに対して被害を与える害虫で、植物の汁を吸うことによって成長を妨げ、葉の変色や枯れを引き起こします。また、分泌物によってすす病を引き起こすこともあります。",
        occurrence_season: "春から秋にかけて発生します。"
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
        method_name: "殺虫剤散布",
        description: "カイガラムシに対して効果的な殺虫剤を散布します。",
        timing_hint: "発生初期に行うと効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "カイガラムシの天敵である捕食者を放飼します。",
        timing_hint: "発生が確認された時期に行います。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の健康管理",
        description: "健康な作物を育てることで、カイガラムシの発生を抑制します。",
        timing_hint: "年間を通じて行います。"
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

      # カミキリムシ
      pest = TempPest.find_or_initialize_by(name: "カミキリムシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Cerambycidae",
        family: "カミキリムシ科",
        order: "コウチュウ目",
        description: "カミキリムシは、木材を食害する害虫で、特に樹木の内部を食害し、木材の強度を低下させる。被害を受けた樹木は、枯死することもある。",
        occurrence_season: "春から夏にかけて発生する。"
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
        method_name: "殺虫剤散布",
        description: "カミキリムシに対して効果的な殺虫剤を散布する。",
        timing_hint: "成虫の発生時期に合わせて散布する。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の利用",
        description: "カミキリムシの天敵を利用して、自然に抑制する。",
        timing_hint: "発生初期に天敵を放す。"
      )
      pest.pest_control_methods.create!(
        method_type: "physical",
        method_name: "トラップ設置",
        description: "フェロモントラップを設置して成虫を捕獲する。",
        timing_hint: "成虫の飛翔時期に設置する。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "適切な剪定",
        description: "樹木の健康を保つために適切に剪定する。",
        timing_hint: "冬季に剪定を行う。"
      )

      # カメムシ
      pest = TempPest.find_or_initialize_by(name: "カメムシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Pentatomidae",
        family: "カメムシ科",
        order: "半翅目",
        description: "カメムシは、トマトやナスの葉や果実に吸汁し、変色や萎縮を引き起こします。特に果実に被害を与えると、品質が低下し、収穫量が減少します。",
        occurrence_season: "春から秋にかけて発生します。"
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
        method_name: "殺虫剤散布",
        description: "カメムシに対して効果的な殺虫剤を散布します。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の利用",
        description: "カメムシの天敵である捕食者を導入します。",
        timing_hint: "発生が確認された時期に導入します。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "カメムシの発生を抑えるために、作物を輪作します。",
        timing_hint: "毎年作物を変えることが重要です。"
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

      # キアゲハの幼虫
      pest = TempPest.find_or_initialize_by(name: "キアゲハの幼虫", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Papilio machaon",
        family: "タテハチョウ科",
        order: "チョウ目",
        description: "キアゲハの幼虫は、ニンジンの葉を食害し、葉の食い痕や枯れた部分を残します。特に若い幼虫は葉の裏側に隠れて食害を行うため、発見が遅れることがあります。",
        occurrence_season: "春から夏にかけて発生します。"
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
        method_name: "殺虫剤散布",
        description: "適切な殺虫剤を使用して幼虫を駆除します。",
        timing_hint: "幼虫が小さいうちに散布することが効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の利用",
        description: "寄生蜂や捕食者を利用して幼虫を抑制します。",
        timing_hint: "発生初期に天敵を放すと効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "ニンジン以外の作物を栽培することで、幼虫の発生を抑えます。",
        timing_hint: "毎年作物を変えることが推奨されます。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "ニンジン", is_reference: true, region: 'jp')
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
        description: "コガネムシは、幼虫が根を食害し、成虫が葉を食害することがあります。特にトマト、とうもろこし、キュウリ、玉ねぎ、キャベツに対して被害を与え、成長を阻害します。",
        occurrence_season: "春から夏にかけて発生します。"
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
        method_name: "殺虫剤散布",
        description: "成虫や幼虫に対して効果的な殺虫剤を散布します。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の利用",
        description: "コガネムシの天敵である捕食者を導入します。",
        timing_hint: "発生が確認された時期に導入します。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "コガネムシの発生を抑えるために、作物を輪作します。",
        timing_hint: "毎年異なる作物を栽培することが重要です。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "とうもろこし", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "玉ねぎ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # コナジラミ
      pest = TempPest.find_or_initialize_by(name: "コナジラミ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Trialeurodes vaporariorum",
        family: "アザミウマ科",
        order: "半翅目",
        description: "コナジラミは、葉の裏に群生し、植物の汁を吸うことで被害を与えます。特にトマトやナスにおいては、葉の黄変や萎縮、果実の成長不良を引き起こすことがあります。また、コナジラミはウイルス病の媒介者でもあり、これによりさらなる被害が発生する可能性があります。",
        occurrence_season: "春から秋にかけて発生します。"
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
        method_name: "殺虫剤散布",
        description: "コナジラミに対して効果的な殺虫剤を使用し、葉の裏側にしっかりと散布します。",
        timing_hint: "発生初期に行うと効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "コナジラミの天敵である捕食性昆虫を放飼することで、自然にコントロールします。",
        timing_hint: "コナジラミの発生が確認された時期に行います。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "コナジラミの発生を抑えるために、同じ作物を連作しないようにします。",
        timing_hint: "作物の栽培計画に基づいて実施します。"
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

      # コオロギ
      pest = TempPest.find_or_initialize_by(name: "コオロギ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Gryllus campestris",
        family: "バッタ科",
        order: "直翅目",
        description: "コオロギは、レタスやとうもろこしの葉を食害し、特に若い苗に対して深刻な被害を与えることがあります。食害によって葉が食べられ、成長が阻害されることがあります。",
        occurrence_season: "春から秋にかけて発生します。"
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
        method_name: "殺虫剤散布",
        description: "コオロギに対して効果的な殺虫剤を散布します。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の利用",
        description: "コオロギの天敵である捕食者を導入します。",
        timing_hint: "発生が確認された時期に導入します。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物のローテーション",
        description: "コオロギの発生を抑えるために作物をローテーションします。",
        timing_hint: "毎年異なる作物を栽培することが推奨されます。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "レタス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "とうもろこし", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # ジャンボタニシ
      pest = TempPest.find_or_initialize_by(name: "ジャンボタニシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Pomacea canaliculata",
        family: "タニシ科",
        order: "腹足目",
        description: "ジャンボタニシは水田や湿地に生息し、稲の葉を食害します。特に若い苗に対して大きな被害を与え、葉を食い尽くすことがあります。",
        occurrence_season: "春から秋にかけて発生します。"
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
        description: "特定の農薬を使用してジャンボタニシを駆除します。",
        timing_hint: "発生初期に散布することが効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の導入",
        description: "ジャンボタニシの天敵となる生物を導入して抑制します。",
        timing_hint: "発生が確認された時期に導入します。"
      )
      pest.pest_control_methods.create!(
        method_type: "physical",
        method_name: "手作業での除去",
        description: "水田内のジャンボタニシを手作業で取り除きます。",
        timing_hint: "定期的に行うことが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "水管理の改善",
        description: "水位を調整し、ジャンボタニシの生息環境を悪化させます。",
        timing_hint: "栽培初期から水管理を行うことが重要です。"
      )

      # シロイチモジヨトウ
      pest = TempPest.find_or_initialize_by(name: "シロイチモジヨトウ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Spodoptera litura",
        family: "ノメイガ科",
        order: "チョウ目",
        description: "シロイチモジヨトウは、幼虫が葉を食害し、特にトマト、とうもろこし、キュウリ、キャベツに対して深刻な被害を引き起こします。葉の食害により光合成が妨げられ、作物の成長が阻害されます。",
        occurrence_season: "春から秋にかけて発生します。"
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
        method_name: "殺虫剤散布",
        description: "化学的な殺虫剤を使用して幼虫を駆除します。",
        timing_hint: "幼虫が発生した初期段階で散布することが効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "寄生蜂などの天敵を利用して、シロイチモジヨトウの個体数を抑制します。",
        timing_hint: "発生初期に天敵を放飼することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "異なる作物を交互に栽培することで、害虫の発生を抑制します。",
        timing_hint: "毎年作物を変えることが効果的です。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "とうもろこし", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # センチュウ
      pest = TempPest.find_or_initialize_by(name: "センチュウ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Meloidogyne spp.",
        family: "線虫科",
        order: "自由生活線虫目",
        description: "センチュウは根に寄生し、植物の成長を妨げる。トマト、とうもろこし、キュウリ、玉ねぎにおいては、根の形成を阻害し、植物全体の健康を損なう。特に、根の腫れや変形が見られ、これにより水分や栄養の吸収が困難になる。",
        occurrence_season: "春から秋にかけて発生する"
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
        method_name: "土壌消毒",
        description: "化学薬品を用いて土壌中のセンチュウを殺す方法。",
        timing_hint: "作物を植える前に実施する。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の利用",
        description: "センチュウを捕食する微生物や天敵を利用する方法。",
        timing_hint: "センチュウの発生が確認された時期に適用する。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "輪作",
        description: "センチュウの好まない作物を交互に栽培する方法。",
        timing_hint: "作物の栽培計画に組み込む。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "とうもろこし", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "玉ねぎ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # タバコガ・オオタバコガ
      pest = TempPest.find_or_initialize_by(name: "タバコガ・オオタバコガ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Helicoverpa armigera",
        family: "ナス科",
        order: "チョウ目",
        description: "タバコガ・オオタバコガは、トマト、ナス、ピーマン、ジャガイモに対して食害を引き起こします。幼虫は葉を食べ、果実や茎にも被害を与えることがあります。特に果実の内部に侵入することが多く、収穫量の減少や品質の低下を引き起こします。",
        occurrence_season: "春から秋にかけて発生します。"
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
        method_name: "殺虫剤散布",
        description: "効果的な殺虫剤を使用して幼虫を駆除します。",
        timing_hint: "幼虫が発生した初期段階で散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の利用",
        description: "寄生蜂や捕食者を利用してタバコガの個体数を抑制します。",
        timing_hint: "発生初期に天敵を放すことが効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "タバコガの発生を抑えるために、作物を定期的に変更します。",
        timing_hint: "毎年異なる作物を栽培することが望ましいです。"
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

      # ツマジロクサヨトウ
      pest = TempPest.find_or_initialize_by(name: "ツマジロクサヨトウ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Spodoptera litura",
        family: "ノミバエ科",
        order: "チョウ目",
        description: "ツマジロクサヨトウは、トマト、とうもろこし、ナスなどの作物に対して葉を食害し、特に幼虫が葉を食べることで著しい被害を引き起こします。被害が進行すると、作物の成長が阻害され、収量が減少します。",
        occurrence_season: "春から秋にかけて発生します。"
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
        method_name: "殺虫剤散布",
        description: "適切な殺虫剤を使用して、幼虫を効果的に駆除します。",
        timing_hint: "幼虫が発生した初期段階で散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の利用",
        description: "寄生蜂や捕食者を利用して、ツマジロクサヨトウの個体数を抑制します。",
        timing_hint: "発生初期に天敵を放すことが効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "異なる作物を栽培することで、害虫の発生を抑制します。",
        timing_hint: "毎年作物を変えることが推奨されます。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "とうもろこし", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ナス", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # テントウムシ
      pest = TempPest.find_or_initialize_by(name: "テントウムシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Coccinellidae",
        family: "テントウムシ科",
        order: "コウチュウ目",
        description: "テントウムシは、トマト、キャベツ、キュウリなどの作物に対して食害を引き起こします。特に幼虫が葉を食べることで、作物の成長を妨げ、収穫量を減少させることがあります。",
        occurrence_season: "春から夏にかけて発生します。"
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
        method_name: "殺虫剤の散布",
        description: "テントウムシに対して効果的な殺虫剤を使用します。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の利用",
        description: "テントウムシの天敵である寄生蜂や捕食者を利用します。",
        timing_hint: "テントウムシの発生が確認された時期に導入します。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "テントウムシの発生を抑えるために、作物を定期的に変更します。",
        timing_hint: "毎年作物を変更することが望ましいです。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # テントウムシダマシ
      pest = TempPest.find_or_initialize_by(name: "テントウムシダマシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Epilachna varivestis",
        family: "テントウムシ科",
        order: "コウチュウ目",
        description: "テントウムシダマシは、トマト、キュウリ、とうもろこしの葉を食害し、特に葉の表面を食べることで光合成を妨げ、作物の成長を阻害します。被害が進行すると、葉が枯れたり、作物全体の生育が悪化することがあります。",
        occurrence_season: "春から夏にかけて発生します。"
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
        method_name: "殺虫剤散布",
        description: "効果的な殺虫剤を使用して、テントウムシダマシを駆除します。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "テントウムシダマシの天敵である捕食者を放飼することで、自然に抑制します。",
        timing_hint: "発生が確認された時期に放飼します。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "テントウムシダマシの発生を抑えるために、作物を輪作します。",
        timing_hint: "毎年作物を変えることが重要です。"
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
      crop = TempCrop.find_by(name: "とうもろこし", is_reference: true, region: 'jp')
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
        description: "ナミアゲハの幼虫は、トマト、ナス、キャベツ、ブロッコリーの葉を食害します。特に若い葉や新芽を好み、食害が進むと植物の成長が阻害され、収穫量が減少します。",
        occurrence_season: "春から夏にかけて発生します。"
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
        method_name: "殺虫剤散布",
        description: "ナミアゲハの幼虫に効果的な殺虫剤を散布します。",
        timing_hint: "幼虫が発生した初期段階で散布することが効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "ナミアゲハの幼虫を捕食する天敵を放飼します。",
        timing_hint: "幼虫が発生する前に放飼することが望ましいです。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "ナミアゲハの好む作物を避けて輪作を行います。",
        timing_hint: "毎年作物を変えることで、発生を抑制します。"
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
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "ブロッコリー", is_reference: true, region: 'jp')
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
        description: "ナメクジは、キャベツやレタスの葉を食害し、特に若い植物に対して深刻な被害を与えることがあります。葉の表面に穴を開けたり、食べ残しの粘液を残したりすることが特徴です。",
        occurrence_season: "春から秋にかけて発生します。"
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
        method_name: "殺虫剤の散布",
        description: "ナメクジに効果的な殺虫剤を散布することで、被害を軽減します。",
        timing_hint: "発生初期に散布することが効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の利用",
        description: "ナメクジを捕食する生物を導入することで、自然に抑制します。",
        timing_hint: "ナメクジの発生が確認された時期に導入します。"
      )
      pest.pest_control_methods.create!(
        method_type: "physical",
        method_name: "障壁の設置",
        description: "ナメクジが作物に近づかないように、物理的な障壁を設置します。",
        timing_hint: "植え付け前に設置することが望ましいです。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "土壌管理",
        description: "土壌の湿度を管理し、ナメクジの生息環境を悪化させます。",
        timing_hint: "定期的な土壌管理が必要です。"
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

      # ネキリムシ
      pest = TempPest.find_or_initialize_by(name: "ネキリムシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Agrotis spp.",
        family: "ノシメトンボ科",
        order: "チョウ目",
        description: "ネキリムシは、幼虫が作物の茎や根を食害し、特にトマト、とうもろこし、キュウリ、玉ねぎ、キャベツに対して深刻な被害をもたらします。幼虫は土中で生活し、作物の根を食い荒らすことで、植物の成長を阻害します。",
        occurrence_season: "春から秋にかけて発生します。"
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
        description: "ネキリムシに効果的な殺虫剤を散布します。",
        timing_hint: "幼虫が発生する前に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "ネキリムシの天敵である寄生蜂を放飼します。",
        timing_hint: "幼虫が発生した時期に放飼します。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "ネキリムシの発生を抑えるために、作物を輪作します。",
        timing_hint: "毎年異なる作物を栽培することが重要です。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "トマト", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "とうもろこし", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キュウリ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "玉ねぎ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
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
        description: "ハダニは葉の裏側に生息し、植物の汁を吸うことで被害を与えます。特にトマトやキュウリでは、葉が黄変し、枯れることがあります。また、葉の表面に小さな白い点が見られることが特徴です。",
        occurrence_season: "春から秋にかけて発生します。"
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
        method_name: "アブラムシ用殺虫剤",
        description: "ハダニに効果的な殺虫剤を使用します。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "ハダニを捕食する天敵を放飼することで、自然に抑制します。",
        timing_hint: "ハダニの発生が確認された時期に放飼します。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "適切な水管理",
        description: "水分ストレスを避けることで、ハダニの発生を抑えます。",
        timing_hint: "生育期間中、常に適切な水分を保つことが重要です。"
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

      # ハムシ
      pest = TempPest.find_or_initialize_by(name: "ハムシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Phyllotreta spp.",
        family: "コウチュウ科",
        order: "コウチュウ目",
        description: "ハムシは、トマト、キュウリ、キャベツなどの葉を食害し、葉の表面に小さな穴を開けることが特徴です。特に若い葉や新芽に被害を与え、成長を阻害します。",
        occurrence_season: "春から夏にかけて発生します。"
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
        method_name: "殺虫剤散布",
        description: "ハムシに対して効果的な殺虫剤を散布します。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の利用",
        description: "ハムシの天敵である捕食者を導入します。",
        timing_hint: "ハムシの発生が確認された時期に導入します。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "ハムシの発生を抑えるために、作物を輪作します。",
        timing_hint: "毎年作物を変えることが効果的です。"
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
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # ハモグリバエ
      pest = TempPest.find_or_initialize_by(name: "ハモグリバエ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Liriomyza sativae",
        family: "ウリバエ科",
        order: "双翅目",
        description: "ハモグリバエは、葉の内部にトンネル状の食害を引き起こし、特に若い葉に被害を与えます。これにより、光合成能力が低下し、作物の成長が阻害されます。",
        occurrence_season: "春から秋にかけて発生します。"
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
        method_name: "殺虫剤散布",
        description: "効果的な殺虫剤を使用して、成虫や幼虫を駆除します。",
        timing_hint: "発生初期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の放飼",
        description: "寄生蜂などの天敵を放飼して、ハモグリバエの個体数を抑制します。",
        timing_hint: "発生が確認された時期に放飼します。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "ハモグリバエの発生を抑えるために、作物を定期的に変更します。",
        timing_hint: "毎年異なる作物を栽培することが望ましいです。"
      )

      # マダニ
      pest = TempPest.find_or_initialize_by(name: "マダニ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Ixodes ricinus",
        family: "ダニ科",
        order: "ダニ目",
        description: "マダニは、植物に寄生することはありませんが、動物や人間に対して吸血行動を行い、病気を媒介することがあります。農作物に直接的な被害を与えることは少ないですが、家畜やペットを通じて間接的に影響を及ぼすことがあります。",
        occurrence_season: "春から秋にかけて発生します。"
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
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "殺虫剤散布",
        description: "マダニに対して効果的な殺虫剤を散布します。",
        timing_hint: "発生が確認された時期に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の利用",
        description: "マダニの天敵となる生物を導入します。",
        timing_hint: "生態系のバランスを考慮して導入します。"
      )
      pest.pest_control_methods.create!(
        method_type: "physical",
        method_name: "手作業での除去",
        description: "目視で確認できるマダニを手作業で除去します。",
        timing_hint: "定期的に確認し、早期に除去します。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "農場の衛生管理",
        description: "農場内の衛生状態を保ち、マダニの発生を抑制します。",
        timing_hint: "常に清潔な環境を維持することが重要です。"
      )

      # メイガ
      pest = TempPest.find_or_initialize_by(name: "メイガ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Ostrinia nubilalis",
        family: "ウリ科",
        order: "チョウ目",
        description: "メイガはとうもろこしの葉や穂に穴をあけ、食害を引き起こします。特に幼虫が穂の中に侵入することで、穂の発育が阻害され、収量が大幅に減少することがあります。",
        occurrence_season: "夏から秋にかけて発生します。"
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
        description: "メイガに対して効果的な殺虫剤を散布します。",
        timing_hint: "幼虫が発生する前に散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の利用",
        description: "メイガの天敵である寄生蜂を利用して、自然に抑制します。",
        timing_hint: "発生初期に導入することが効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "メイガの発生を抑えるために、作物を輪作します。",
        timing_hint: "毎年異なる作物を栽培することが望ましいです。"
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "とうもろこし", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # ヨトウムシ
      pest = TempPest.find_or_initialize_by(name: "ヨトウムシ", is_reference: true, region: 'jp')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Spodoptera litura",
        family: "ノミバエ科",
        order: "チョウ目",
        description: "ヨトウムシは、葉を食害し、特に若い植物に対して深刻な被害を与えます。トマト、キュウリ、キャベツの葉を食べることで、成長を妨げ、収穫量を減少させることがあります。",
        occurrence_season: "春から秋にかけて発生します。"
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
        method_name: "殺虫剤散布",
        description: "効果的な殺虫剤を使用して、成虫や幼虫を駆除します。",
        timing_hint: "幼虫が発生した初期段階で散布することが推奨されます。"
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "天敵の利用",
        description: "寄生蜂や捕食者を利用して、ヨトウムシの個体数を抑制します。",
        timing_hint: "発生初期に天敵を放すことが効果的です。"
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "作物の輪作",
        description: "異なる作物を栽培することで、ヨトウムシの発生を抑える方法です。",
        timing_hint: "毎年作物を変えることが推奨されます。"
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
      crop = TempCrop.find_by(name: "キャベツ", is_reference: true, region: 'jp')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

  end
end
