require "test_helper"

class SitemapsIndexViewTest < ActiveSupport::TestCase
  test "研究記事のファイルが存在しない場合はエラーになる" do
    error = assert_raises(ActionView::Template::Error) do
      ApplicationController.renderer.render(
        template: "sitemaps/index",
        formats: [:xml],
        assigns: {
          base_url: "https://example.com",
          research_pages: ["research/missing.html"]
        }
      )
    end

    assert_kind_of Errno::ENOENT, error.cause
    assert_includes error.cause.message, "research/missing.html"
  end
end

