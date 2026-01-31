# frozen_string_literal: true

require "test_helper"

# HtmlCrudResponderの動作確認
# 実際の使用例はFarmsControllerなどで確認可能だが、
# ここではConcernの基本的な動作を確認する
class HtmlCrudResponderTest < ActionDispatch::IntegrationTest
  # HtmlCrudResponderが正しく定義されていることを確認
  test "HtmlCrudResponder is defined" do
    assert defined?(HtmlCrudResponder)
    assert_kind_of Module, HtmlCrudResponder
  end
end
