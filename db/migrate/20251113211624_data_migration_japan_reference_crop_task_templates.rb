# frozen_string_literal: true

class DataMigrationJapanReferenceCropTaskTemplates < ActiveRecord::Migration[8.0]
  # 一時モデル定義（マイグレーション内でのみ使用）
  # モデルクラスへの依存を避け、スキーマ変更に強い設計

  class TempAgriculturalTask < ActiveRecord::Base
    self.table_name = 'agricultural_tasks'
  end

  class TempCropTaskTemplate < ActiveRecord::Base
    self.table_name = 'crop_task_templates'
    belongs_to :crop, class_name: 'DataMigrationJapanReferenceCropTaskTemplates::TempCrop', foreign_key: 'crop_id'
    belongs_to :agricultural_task, class_name: 'DataMigrationJapanReferenceCropTaskTemplates::TempAgriculturalTask', foreign_key: 'agricultural_task_id', optional: true
  end

  class TempCrop < ActiveRecord::Base
    self.table_name = 'crops'
  end

  ALL_CROPS = %w[かぼちゃ キャベツ キュウリ ジャガイモ 大根 とうもろこし トマト ナス ニンジン 白菜 ピーマン ブロッコリー ほうれん草 レタス 玉ねぎ].freeze
  DIRECT_SEEDING_CROPS = %w[かぼちゃ 大根 とうもろこし ニンジン ほうれん草].freeze
  TRANSPLANT_CROPS = %w[かぼちゃ キャベツ キュウリ ジャガイモ トマト ナス 白菜 ピーマン ブロッコリー レタス 玉ねぎ].freeze
  MULCHING_CROPS = %w[かぼちゃ キュウリ ジャガイモ 大根 トマト ナス ニンジン 白菜 ピーマン 玉ねぎ].freeze
  TUNNEL_CROPS = %w[キャベツ キュウリ 大根 トマト ナス ニンジン 白菜 ピーマン ブロッコリー ほうれん草 レタス 玉ねぎ].freeze
  SUPPORT_STRUCTURE_CROPS = %w[かぼちゃ キュウリ トマト ナス ピーマン].freeze
  NET_CROPS = %w[かぼちゃ キャベツ キュウリ 大根 白菜 ブロッコリー].freeze
  THINNING_CROPS = %w[かぼちゃ 大根 とうもろこし ニンジン ほうれん草].freeze
  PRUNING_CROPS = %w[かぼちゃ キュウリ トマト ナス ピーマン].freeze
  TRAINING_CROPS = %w[かぼちゃ キュウリ トマト ナス ピーマン].freeze

  TASK_DEFINITIONS = {
    '耕耘' => {
      description: '土を耕して柔らかくする作業',
      time_per_sqm: 0.05,
      weather_dependency: 'medium',
      required_tools: %w[スコップ クワ 鍬],
      skill_level: 'intermediate',
      crops: ALL_CROPS
    },
    '基肥' => {
      description: '植え付け前に土に混ぜ込む肥料',
      time_per_sqm: 0.01,
      weather_dependency: 'low',
      required_tools: %w[スコップ 肥料],
      skill_level: 'beginner',
      crops: ALL_CROPS
    },
    '播種' => {
      description: '種をまく作業',
      time_per_sqm: 0.005,
      weather_dependency: 'medium',
      required_tools: %w[種 まき溝切り器],
      skill_level: 'beginner',
      crops: DIRECT_SEEDING_CROPS
    },
    '定植' => {
      description: '苗を植え付ける作業',
      time_per_sqm: 0.02,
      weather_dependency: 'medium',
      required_tools: %w[苗 移植ごて],
      skill_level: 'beginner',
      crops: TRANSPLANT_CROPS
    },
    '灌水' => {
      description: '作物に水を与える作業',
      time_per_sqm: 0.01,
      weather_dependency: 'high',
      required_tools: %w[ホース 散水器],
      skill_level: 'beginner',
      crops: ALL_CROPS
    },
    '除草' => {
      description: '雑草を取り除く作業',
      time_per_sqm: 0.03,
      weather_dependency: 'medium',
      required_tools: %w[鎌 草取りフォーク],
      skill_level: 'beginner',
      crops: ALL_CROPS
    },
    '収穫' => {
      description: '作物を収穫する作業',
      time_per_sqm: 0.05,
      weather_dependency: 'medium',
      required_tools: %w[ハサミ 収穫かご],
      skill_level: 'beginner',
      crops: ALL_CROPS
    },
    '出荷準備' => {
      description: '出荷前の準備作業（洗浄、選別など）',
      time_per_sqm: 0.05,
      weather_dependency: 'low',
      required_tools: %w[バケツ 選別用かご ブラシ],
      skill_level: 'intermediate',
      crops: ALL_CROPS
    },
    'マルチング' => {
      description: 'マルチシートを敷く作業',
      time_per_sqm: 0.01,
      weather_dependency: 'medium',
      required_tools: %w[マルチシート マルチ押さえ],
      skill_level: 'intermediate',
      crops: MULCHING_CROPS
    },
    'トンネル設置' => {
      description: 'トンネル支柱を設置する作業',
      time_per_sqm: 0.02,
      weather_dependency: 'medium',
      required_tools: %w[トンネル支柱 ビニール],
      skill_level: 'intermediate',
      crops: TUNNEL_CROPS
    },
    '支柱立て' => {
      description: '支柱を立てて作物を支える作業',
      time_per_sqm: 0.015,
      weather_dependency: 'low',
      required_tools: %w[支柱 結束バンド],
      skill_level: 'intermediate',
      crops: SUPPORT_STRUCTURE_CROPS
    },
    '防虫ネット張り' => {
      description: '防虫ネットを設置する作業',
      time_per_sqm: 0.015,
      weather_dependency: 'medium',
      required_tools: %w[防虫ネット ネット押さえ],
      skill_level: 'intermediate',
      crops: NET_CROPS
    },
    '間引き' => {
      description: '過密な苗を間引く作業',
      time_per_sqm: 0.01,
      weather_dependency: 'low',
      required_tools: %w[ハサミ],
      skill_level: 'beginner',
      crops: THINNING_CROPS
    },
    '剪定' => {
      description: '不要な枝を切る作業',
      time_per_sqm: 0.02,
      weather_dependency: 'low',
      required_tools: %w[剪定ばさみ],
      skill_level: 'intermediate',
      crops: PRUNING_CROPS
    },
    '誘引' => {
      description: '作物を支柱などに誘引する作業',
      time_per_sqm: 0.015,
      weather_dependency: 'low',
      required_tools: %w[結束バンド 支柱],
      skill_level: 'intermediate',
      crops: TRAINING_CROPS
    },
    '規格選別' => {
      description: '収穫物を規格ごとに選別する作業',
      time_per_sqm: 0.05,
      weather_dependency: 'low',
      required_tools: %w[選別用かご 規格表 はかり],
      skill_level: 'intermediate',
      crops: ALL_CROPS
    },
    '箱詰め・袋詰め' => {
      description: '出荷用の箱や袋に詰める作業',
      time_per_sqm: 0.03,
      weather_dependency: 'low',
      required_tools: %w[箱 袋 ラベル],
      skill_level: 'beginner',
      crops: ALL_CROPS
    }
  }.freeze

  def up
    say "🌱 日本（jp）の参照CropTaskTemplateを投入しています..."

    TASK_DEFINITIONS.each do |task_name, attributes|
      # 既存のAgriculturalTaskを取得（DataMigrationJapanReferenceTasksで作成されたもの）
      agricultural_task = TempAgriculturalTask.find_by(name: task_name, region: 'jp', is_reference: true)

      unless agricultural_task
        say "⚠️  AgriculturalTask '#{task_name}' が見つかりません。スキップします。"
        next
      end

      attributes[:crops].each do |crop_name|
        crop = TempCrop.find_by(name: crop_name, region: 'jp', is_reference: true)

        unless crop
          say "⚠️  Crop '#{crop_name}' が見つかりません。スキップします。"
          next
        end

        # 既存のCropTaskTemplateが存在する場合は削除
        existing_template = TempCropTaskTemplate.find_by(
          crop_id: crop.id,
          name: task_name
        )
        existing_template&.destroy

        # CropTaskTemplateを作成
        TempCropTaskTemplate.create!(
          crop_id: crop.id,
          agricultural_task_id: agricultural_task.id,
          name: task_name,
          description: attributes[:description],
          time_per_sqm: attributes[:time_per_sqm],
          weather_dependency: attributes[:weather_dependency],
          required_tools: attributes[:required_tools].to_json,
          skill_level: attributes[:skill_level],
          is_reference: true
        )
      end
    end

    say "✅ 日本の参照CropTaskTemplate投入が完了しました"
  end

  def down
    say "🗑️ 日本（jp）の参照CropTaskTemplateを削除しています..."

    task_names = TASK_DEFINITIONS.keys
    task_ids = TempAgriculturalTask.where(name: task_names, region: 'jp', is_reference: true).pluck(:id)

    if task_ids.any?
      TempCropTaskTemplate.where(agricultural_task_id: task_ids, is_reference: true).delete_all
    end

    say "✅ 日本の参照CropTaskTemplateを削除しました"
  end
end
