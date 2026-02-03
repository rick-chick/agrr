require 'test_helper'
require 'active_job/test_helper'

class PlansControllerCreateFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = create(:user)
    @farm = create(:farm, user: @user, latitude: 35.0, longitude: 135.0)
    # Ensure the farm has at least one field so total_area is non-zero during plan creation
    create(:field, farm: @farm, user: @user)
    @crop = create(:crop, user: @user, is_reference: false)
    sign_in_as @user
  end

  test 'create redirects to optimizing page after creating plan' do
    travel_to Time.zone.local(Date.current.year, 1, 15) do
      # セッションに計画データを設定
      plan_name = "テスト計画"
      total_area = 100.0
      plan_year = Date.current.year

      # Cookie セッションに直接書き込むため、リクエスト前にheadersを準備
      session_id = create_session_for(@user)
      headers = session_cookie_header(session_id)

      # セッション保存はコントローラのフローに従って select_crop を踏む
      get select_crop_plans_path, params: { plan_year: plan_year, farm_id: @farm.id }, headers: headers
      # RailsセッションCookieを次のリクエストでも維持する
      set_cookie = response.get_header('Set-Cookie') || response.headers['Set-Cookie']
      if set_cookie
        rails_session_cookie = set_cookie.split(';').first
        merged_cookie = [headers['Cookie'], rails_session_cookie].compact.join('; ')
        headers = { 'Cookie' => merged_cookie }
      end
      # plan_name は farm 名が自動設定されるため上書き不要。total_area も自動計算される。

      post plans_path, params: { crop_ids: [@crop.id] }, headers: headers

      # リダイレクト先が最適化進捗ページであることを確認
      assert_response :redirect
      follow_redirect!
      assert_match %r{/plans/\d+/optimizing}, path
    end
  end

  test 'create annual plan without plan_year redirects to optimizing page' do
    travel_to Time.zone.local(Date.current.year, 1, 15) do
      # Cookie セッションに直接書き込むため、リクエスト前にheadersを準備
      session_id = create_session_for(@user)
      headers = session_cookie_header(session_id)

      # 年度選択なしで select_crop を呼び出す（通年計画）
      get select_crop_plans_path, params: { farm_id: @farm.id }, headers: headers
      assert_response :success

      # RailsセッションCookieを次のリクエストでも維持する
      set_cookie = response.get_header('Set-Cookie') || response.headers['Set-Cookie']
      if set_cookie
        rails_session_cookie = set_cookie.split(';').first
        merged_cookie = [headers['Cookie'], rails_session_cookie].compact.join('; ')
        headers = { 'Cookie' => merged_cookie }
      end

      post plans_path, params: { crop_ids: [@crop.id] }, headers: headers

      # リダイレクト先が最適化進捗ページであることを確認
      assert_response :redirect
      follow_redirect!
      assert_match %r{/plans/\d+/optimizing}, path

      # 作成された計画を確認
      plan = CultivationPlan.where(user: @user, farm: @farm, plan_type: 'private').last
      assert_not_nil plan, '計画が作成されていない'
      assert_nil plan.plan_year, 'plan_yearがnullであること'
      assert_not_nil plan.planning_start_date, 'planning_start_dateが設定されていること'
      assert_not_nil plan.planning_end_date, 'planning_end_dateが設定されていること'
    end
  end
end


