# frozen_string_literal: true

require "test_helper"

class ApiLocaleKeysTest < ActiveSupport::TestCase
  test "api.errors.no_cultivation_period resolves for ja and us" do
    expected = {
      ja: "栽培期間が設定されていません",
      us: "Cultivation period not set"
    }
    expected.each do |locale, want|
      assert_equal want, I18n.t("api.errors.no_cultivation_period", locale: locale)
    end
  end
end
