# frozen_string_literal: true

module Forms
  # form_with / fields_for が期待する errors / valid? / model_name（インスタンス）を提供する。
  # ActiveModel::Model に依存しない。
  module HtmlFormSupport
    def errors
      @errors ||= Domain::Shared::ValidationErrors.new
    end

    def valid?
      errors.empty?
    end

    def model_name
      self.class.model_name
    end

    def to_model
      self
    end
  end
end
