# frozen_string_literal: true

require "test_helper"

class FertilizesFormViewTest < ActiveSupport::TestCase
  test "new画面のフォームに肥料名入力フィールドが存在する" do
    fertilize = build(:fertilize)
    html = ApplicationController.renderer.render(
      partial: "fertilizes/form",
      assigns: { fertilize: fertilize }
    )

    assert_includes html, 'name="fertilize[name]"'
  end

  test "new画面のフォームに肥料AIボタンのdata属性が設定されている" do
    fertilize = build(:fertilize)
    html = ApplicationController.renderer.render(
      partial: "fertilizes/form",
      assigns: { fertilize: fertilize }
    )

    assert_includes html, 'id="ai-save-fertilize-btn"'
    assert_includes html, 'data-enter-name='
    assert_includes html, 'data-fetching='
  end

  test "new画面のフォームに肥料というテキストが存在する" do
    fertilize = build(:fertilize)
    html = ApplicationController.renderer.render(
      partial: "fertilizes/form",
      assigns: { fertilize: fertilize }
    )

    assert_match(/肥料/, html)
  end

  test "new画面のフォームにAIボタンのアクセシビリティ属性が付与されている" do
    fertilize = build(:fertilize)
    html = ApplicationController.renderer.render(
      partial: "fertilizes/form",
      assigns: { fertilize: fertilize }
    )

    assert_includes html, 'aria-live="polite"'
    assert_includes html, 'aria-controls="ai-save-status"'
    assert_includes html, 'aria-describedby="ai-save-help"'
  end
end
