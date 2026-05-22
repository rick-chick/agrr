# frozen_string_literal: true

require "test_helper"

# plans/index テンプレートのカード描画責務。
# どの計画が一覧に載るか（ユーザー絞り込み等）は PrivatePlanIndexInteractor の
# ユニットテストが担保する。ここは Interactor が渡した plan_rows を
# テンプレートがどう HTML カードに写すかだけを検証する。
class PlansIndexViewTest < ActiveSupport::TestCase
  def plan_row(id:, farm_display_name: "テスト農場", display_name: "テスト計画", status: "completed")
    Domain::CultivationPlan::Dtos::PrivatePlanIndexPlanRow.new(
      id: id,
      farm_display_name: farm_display_name,
      total_area: 100,
      crops_count: 1,
      fields_count: 1,
      status: status,
      display_name: display_name,
      created_at: Time.utc(2026, 1, 1)
    )
  end

  def render_index(rows)
    PlansController.renderer.render(
      template: "plans/index",
      layout: false,
      assigns: {
        private_plan_index: Domain::CultivationPlan::Dtos::PrivatePlanIndex.new(plan_rows: rows)
      }
    )
  end

  test "index は各 plan_row の詳細リンクを描画する" do
    html = render_index([ plan_row(id: 11), plan_row(id: 22) ])

    assert_includes html, %(href="#{Rails.application.routes.url_helpers.plan_path(11)}")
    assert_includes html, %(href="#{Rails.application.routes.url_helpers.plan_path(22)}")
  end

  test "index はカードタイトルに農場名を描画しステータスバッジを描画しない" do
    html = render_index([ plan_row(id: 1, farm_display_name: "テスト農場A") ])
    doc = Nokogiri::HTML(html)

    assert_equal "テスト農場A", doc.at_css("h3.plan-card-title")&.text&.strip
    assert_empty doc.css(".plan-card-status")
  end

  test "index は計画名・計画期間ラベルをカード本文に描画しない" do
    html = render_index([ plan_row(id: 1, display_name: "テスト計画") ])
    doc = Nokogiri::HTML(html)
    card = doc.at_css(".plan-card")

    assert card, "expected a plan card"
    visible_parts = card.css("h3.plan-card-title, .plan-card-details, .plan-card-meta").map(&:text).join("\n")
    assert_not visible_parts.include?("テスト計画")
    assert_no_match(/計画期間:/, visible_parts)
  end

  test "index は農場アコーディオン（details / .plans-farm-section）を描画しない" do
    html = render_index([ plan_row(id: 1) ])
    doc = Nokogiri::HTML(html)

    assert_empty doc.css("details")
    assert_empty doc.css(".plans-farm-section")
  end
end
