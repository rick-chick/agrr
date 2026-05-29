# frozen_string_literal: true

# lib/domain 内の実行可能コードに ActiveRecord / AR モデル定数参照が無いことを検査する。
# domain-lib-test および architecture テストから利用する。
module LibDomainActiveRecordReferenceScanner
  DOMAIN_ROOT = Pathname.new(__dir__).join("..", "..", "lib", "domain").expand_path

  # app/models の ApplicationRecord サブクラス（Zeitwerk のトップレベル定数）
  APPLICATION_RECORD_MODELS = %w[
    AgriculturalTask
    ContactMessage
    Crop
    CropPest
    CropStage
    CropTaskScheduleBlueprint
    CropTaskTemplate
    CultivationPlan
    CultivationPlanCrop
    CultivationPlanField
    DeletionUndoEvent
    Farm
    Fertilize
    Field
    FieldCultivation
    FreeCropPlan
    InteractionRule
    NutrientRequirement
    Pest
    PestControlMethod
    PestTemperatureProfile
    PestThermalRequirement
    Pesticide
    PesticideApplicationDetail
    PesticideUsageConstraint
    Session
    SunshineRequirement
    TaskSchedule
    TaskScheduleItem
    TemperatureRequirement
    ThermalRequirement
    User
    WeatherDatum
    WeatherLocation
  ].freeze

  FORBIDDEN_PATTERNS = [
    /\bActiveRecord::/,
    /\bApplicationRecord\b/,
    /\bAdapters::/,
    /\bRails\.(?!root)/, # Rails.logger 等の直参照（コメントは executable_source で除外済み）
    /\bData\.define\s*\(/ # docs/migration/lib-domain-rust/ARCHITECTURE.md — Rust struct 1:1 前提
  ].freeze

  module_function

  # ルート定数（::Field.find）のみ。Domain::...::WeatherLocation 等のドメイン DTO は除外する。
  def model_constant_reference_pattern
    @model_constant_reference_pattern ||= begin
      names = APPLICATION_RECORD_MODELS.join("|")
      /(?:^|[^\w:])::(#{names})\./
    end
  end

  def all_patterns
    FORBIDDEN_PATTERNS + [ model_constant_reference_pattern ]
  end

  # @return [Array<String>] "lib/domain/...:42: matched /.../ in `...`"
  def violations
    found = []

    DOMAIN_ROOT.glob("**/*.rb").sort.each do |path|
      scan_file(path, found)
    end

    found
  end

  def scan_file(path, found = [])
    rel = path.relative_path_from(DOMAIN_ROOT.parent.parent).to_s

    executable_source(path).each_with_index do |line, index|
      line_no = index + 1
      all_patterns.each do |pattern|
        next unless line.match?(pattern)

        snippet = line.strip[0, 120]
        found << "#{rel}:#{line_no}: #{pattern.inspect} in `#{snippet}`"
      end
    end

    found
  end

  # コメント行と行末コメントを除いた「実行可能っぽい」行だけ返す
  def executable_source(path)
    File.readlines(path).filter_map do |line|
      stripped = line.strip
      next if stripped.empty?
      next if stripped.start_with?("#")

      without_inline_comment = line.sub(/#.*$/, "")
      next if without_inline_comment.strip.empty?

      without_inline_comment
    end
  end
end
