# frozen_string_literal: true

# ActiveModel ベースの Form Object 共通基盤。
#
# 役割:
# - HTML View / form_with から AR を取り除くための受け皿。
# - Domain Entity を AR ではなく Form Object として view に渡す。
# - エラー表示・URL推論・dom_id を AR 非依存で再現する。
#
# 使い方の規約:
# - サブクラスは `attribute :name, :string` 等で属性宣言。
# - `from_entity(entity)` クラスメソッドで Entity から復元。
# - `from_params(params)` クラスメソッドでフォーム入力から復元。
# - `errors_from(messages_hash)` で外部から errors を流し込み可能。
# - `model_name`、`to_param`、`persisted?`、`to_key` を Entity ID と
#   サブクラス名から推論。Rails の `form_with model: form` をそのまま使える。
class Adapters::Shared::Forms::ApplicationForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attribute :id, :integer

  class << self
    # サブクラスが対応する Rails のリソース名（複数形ベース URL）を返す。
    # 既定: クラス名から `Form` を除いた snake_case。
    # 例: PestForm -> "pest"
    def resource_name
      @resource_name ||= name.to_s.sub(/Form\z/, "").demodulize.underscore
    end

    def resource_name=(value)
      @resource_name = value.to_s
    end

    # Rails の polymorphic_path / dom_id 用に ActiveModel::Name を提供。
    def model_name
      @model_name ||= ActiveModel::Name.new(self, nil, resource_name.classify)
    end
  end

  # 配列 params 等で `_destroy` や子要素 hash を保持できるよう、
  # サブクラスは必要に応じて `attribute :children_attributes` を追加する。

  def persisted?
    !id.nil?
  end

  def new_record?
    !persisted?
  end

  def to_param
    persisted? ? id.to_s : nil
  end

  def to_key
    persisted? ? [ id ] : nil
  end

  def model_name
    self.class.model_name
  end

  # 外部（Interactor 失敗時など）から validations 結果を流し込む。
  # 受け取る形式:
  #   - Hash<Symbol, Array<String>>  例: { name: ["は必須です"] }
  #   - Hash<Symbol, String>          例: { name: "は必須です" }
  #   - Array<String>                 例: ["何かが失敗しました"]
  def errors_from(source)
    case source
    when Hash
      source.each do |attr, messages|
        Array(messages).each { |m| errors.add(attr, m) }
      end
    when Array
      source.each { |m| errors.add(:base, m) }
    when String
      errors.add(:base, source)
    end
    self
  end

  # ActiveRecord の as_json を参考にした JSON 出力（テストや debug 用）。
  def to_h
    attributes
  end

  # サブクラスで上書き推奨: Entity を受け取りフォームを組み立てる。
  def self.from_entity(entity, **extra)
    return new(**extra) if entity.nil?

    attrs = if entity.respond_to?(:to_hash)
              entity.to_hash
    elsif entity.respond_to?(:as_json)
              entity.as_json.to_h
    else
              {}
    end
    new(**attrs.symbolize_keys, **extra)
  end

  # サブクラスで上書き推奨: 生 params から作る。
  # Strong Parameters の責務は Controller 側に残す。
  def self.from_params(params, **extra)
    new(**params.to_h.symbolize_keys, **extra)
  end
end
