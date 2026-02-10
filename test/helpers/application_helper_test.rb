# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "research_path_for maps us to /research/en/" do
    assert_equal "/research/en/", research_path_for(:us)
    assert_equal "/research/en/", research_path_for("us")
  end

  test "research_path_for maps ja to /research/" do
    assert_equal "/research/", research_path_for(:ja)
    assert_equal "/research/", research_path_for("ja")
  end

  test "research_path_for maps in to /research/" do
    assert_equal "/research/", research_path_for(:in)
    assert_equal "/research/", research_path_for("in")
  end

  test "research_path_for defaults to /research/ for unknown locale" do
    assert_equal "/research/", research_path_for(:unknown)
    assert_equal "/research/", research_path_for("xx")
    assert_equal "/research/", research_path_for(nil)
  end

  test "research_path_for returns path with trailing slash" do
    assert research_path_for(:ja).end_with?("/")
    assert_equal "/research/", research_path_for(:ja)
  end

  test "research_alternate_urls returns empty when file does not exist anywhere" do
    base_url = "https://example.com"
    alts = research_alternate_urls("research/nonexistent_page.html", base_url)
    assert_predicate alts, :empty?
  end

  test "research_alternate_urls returns ja and in for file existing only in /research/" do
    base_url = "https://example.com"
    # research/research_reports/broccoli/... exists in /research/ but not in /research/en/
    alts = research_alternate_urls("research/research_reports/broccoli/01_environmental_requirements/gdd_requirements.html", base_url)
    hreflangs = alts.map { |a| a[:hreflang] }
    assert_includes hreflangs, "ja"
    assert_includes hreflangs, "in"
    refute_includes hreflangs, "us"
    # ja/in point to /research/ directly (no lang subdir)
    alts.select { |a| %w[ja in].include?(a[:hreflang]) }.each do |alt|
      assert_equal "#{base_url}/research/research_reports/broccoli/01_environmental_requirements/gdd_requirements.html", alt[:href]
    end
  end

  test "research_alternate_urls returns all locales when both /research/ and /research/en/ have the file" do
    base_url = "https://example.com"
    # index.html exists in both /research/ and /research/en/
    alts = research_alternate_urls("research/index.html", base_url)
    assert_kind_of Array, alts
    hreflangs = alts.map { |a| a[:hreflang] }
    assert_includes hreflangs, "ja"
    assert_includes hreflangs, "in"
    assert_includes hreflangs, "us"
    # ja/in href is /research/index.html
    alts.select { |a| %w[ja in].include?(a[:hreflang]) }.each do |alt|
      assert_equal "#{base_url}/research/index.html", alt[:href]
    end
    # us href is /research/en/index.html
    us_alt = alts.find { |a| a[:hreflang] == "us" }
    assert_equal "#{base_url}/research/en/index.html", us_alt[:href]
  end
end
