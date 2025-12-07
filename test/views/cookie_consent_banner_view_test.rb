require "test_helper"

class CookieConsentBannerViewTest < ActiveSupport::TestCase
  test "renders without inline scripts and relies on Stimulus handlers" do
    html = ApplicationController.renderer.render(
      partial: "shared/cookie_consent_banner"
    )

    assert_includes html, 'data-action="click->cookie-consent#accept"'
    assert_includes html, 'data-action="click->cookie-consent#reject"'
    assert_no_match(/<script\b/i, html)
  end
end

