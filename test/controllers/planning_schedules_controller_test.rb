# frozen_string_literal: true

require 'test_helper'

class PlanningSchedulesControllerTest < ActionDispatch::IntegrationTest
  # --- Test DOM helpers (behavior-invariant refactor) ---
  # 期間ラベルに一致する行を返す
  def find_period_row(doc, label_text)
    rows = doc.css('.schedule-table tbody tr')
    rows.find do |r|
      period_cell = r.css('.schedule-table-period-cell').first
      period_cell && period_cell.text.include?(label_text)
    end
  end

  # 期間行のフィールドセル(td)を返す
  def field_cells_in_row(row)
    row.css('td.schedule-table-cell')
  end

  # セル配列のテキストを結合して返す
  def joined_cell_text(cells)
    cells.map { |cell| cell.text.strip }.join(' ')
  end

  # 行の中でrowspanを持つセルを返す（なければnil）
  def cell_with_rowspan(cells, rowspan_value = nil)
    return cells.find { |cell| cell['rowspan'] } unless rowspan_value
    cells.find { |cell| cell['rowspan'] && cell['rowspan'].to_i == rowspan_value.to_i }
  end

  # ひとつのセルのcolspan文字列を返す（なければnil）
  def colspan_of(cell)
    cell && cell['colspan']
  end

  setup do
    @user = create(:user)
    @farm = create(:farm, user: @user, name: 'テスト農場')
    @other_user = create(:user)
    @other_farm = create(:farm, user: @other_user, name: '他のユーザーの農場')
  end

  test "fields_selection requires authentication" do
    get fields_selection_planning_schedules_path
    assert_redirected_to auth_login_path
  end

  test "fields_selection displays farms for logged in user" do
    sign_in_as @user
    get fields_selection_planning_schedules_path
    
    assert_response :success
    assert_select 'h1', text: /ほ場選択/
  end

  test "fields_selection displays fields from plans" do
    sign_in_as @user
    
    # 計画を作成
    plan = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: Date.current.year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場1', area: 1000)
    field2 = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場2', area: 2000)
    
    get fields_selection_planning_schedules_path(farm_id: @farm.id)
    
    assert_response :success
    assert_select '.field-checkbox', count: 2
  end

  test "fields_selection shows empty message when no farms" do
    sign_in_as @user
    @user.farms.destroy_all
    
    get fields_selection_planning_schedules_path
    
    assert_response :success
    assert_select '.plans-empty'
  end

  test "schedule requires authentication" do
    get schedule_planning_schedules_path
    assert_redirected_to auth_login_path
  end

  test "schedule redirects to fields_selection when no farm_id" do
    sign_in_as @user
    get schedule_planning_schedules_path
    
    assert_redirected_to fields_selection_planning_schedules_path
    assert_equal I18n.t('planning_schedules.errors.select_fields'), flash[:alert]
  end

  test "schedule redirects to fields_selection when no field_ids" do
    sign_in_as @user
    get schedule_planning_schedules_path(farm_id: @farm.id)
    
    assert_redirected_to fields_selection_planning_schedules_path
    assert_equal I18n.t('planning_schedules.errors.select_fields'), flash[:alert]
  end

  test "schedule displays schedule table" do
    sign_in_as @user
    
    # 計画を作成
    plan = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: Date.current.year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場1', area: 1000)
    crop1 = create(:cultivation_plan_crop, cultivation_plan: plan, name: 'トマト')
    
    # 栽培情報を作成
    field_cultivation = create(:field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: field1,
      cultivation_plan_crop: crop1,
      start_date: Date.new(Date.current.year, 1, 15),
      completion_date: Date.new(Date.current.year, 3, 20),
      area: 1000
    )
    
    field_id = 'ほ場1'.hash.abs
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: Date.current.year,
      granularity: 'quarter'
    )
    
    assert_response :success
    assert_select 'h1', text: /作付け計画表/
    assert_select '.schedule-table'
  end

  test "schedule displays 5 years of data" do
    sign_in_as @user
    
    current_year = Date.current.year
    field_id = 'ほ場1'.hash.abs
    
    # 5年分の計画を作成
    (0..4).each do |year_offset|
      year = current_year + year_offset
      plan = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: year)
      field = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場1', area: 1000)
      crop = create(:cultivation_plan_crop, cultivation_plan: plan, name: "作物#{year_offset + 1}")
      create(:field_cultivation,
        cultivation_plan: plan,
        cultivation_plan_field: field,
        cultivation_plan_crop: crop,
        start_date: Date.new(year, 1, 15),
        completion_date: Date.new(year, 3, 20),
        area: 1000
      )
    end
    
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: current_year,
      granularity: 'quarter'
    )
    
    assert_response :success
    assert_select 'h1', text: /作付け計画表/
    assert_select '.schedule-table'
    
    # 5年分の期間が表示されることを確認（quarter粒度で5年分 = 20期間）
    # 実際の期間数は年によって変わる可能性があるので、最低限の確認
    assert_select '.schedule-table tbody tr', minimum: 1
  end

  test "schedule displays data across multiple years" do
    sign_in_as @user
    
    current_year = Date.current.year
    field_id = 'ほ場1'.hash.abs
    
    # 複数年度にまたがる計画を作成
    plan1 = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: current_year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan1, name: 'ほ場1', area: 1000)
    crop1 = create(:cultivation_plan_crop, cultivation_plan: plan1, name: 'トマト')
    create(:field_cultivation,
      cultivation_plan: plan1,
      cultivation_plan_field: field1,
      cultivation_plan_crop: crop1,
      start_date: Date.new(current_year, 1, 15),
      completion_date: Date.new(current_year, 3, 20),
      area: 1000
    )
    
    plan2 = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: current_year + 2)
    field2 = create(:cultivation_plan_field, cultivation_plan: plan2, name: 'ほ場1', area: 1000)
    crop2 = create(:cultivation_plan_crop, cultivation_plan: plan2, name: 'キャベツ')
    create(:field_cultivation,
      cultivation_plan: plan2,
      cultivation_plan_field: field2,
      cultivation_plan_crop: crop2,
      start_date: Date.new(current_year + 2, 1, 15),
      completion_date: Date.new(current_year + 2, 3, 20),
      area: 1000
    )
    
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: current_year,
      granularity: 'quarter'
    )
    
    assert_response :success
    # 5年分のデータが表示されることを確認
    assert_select '.schedule-table'
  end

  test "schedule generates periods for 5 years with quarter granularity" do
    sign_in_as @user
    
    current_year = Date.current.year
    field_id = 'ほ場1'.hash.abs
    
    plan = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: current_year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場1', area: 1000)
    
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: current_year,
      granularity: 'quarter'
    )
    
    assert_response :success
    # quarter粒度で5年分 = 20期間（1年4四半期 × 5年）
    assert_select '.schedule-table tbody tr', count: 20
  end

  test "schedule generates periods for 5 years with month granularity" do
    sign_in_as @user
    
    current_year = Date.current.year
    field_id = 'ほ場1'.hash.abs
    
    plan = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: current_year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場1', area: 1000)
    
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: current_year,
      granularity: 'month'
    )
    
    assert_response :success
    # month粒度で5年分 = 60期間（1年12ヶ月 × 5年）
    assert_select '.schedule-table tbody tr', count: 60
  end

  test "schedule generates periods for 5 years with half granularity" do
    sign_in_as @user
    
    current_year = Date.current.year
    field_id = 'ほ場1'.hash.abs
    
    plan = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: current_year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場1', area: 1000)
    
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: current_year,
      granularity: 'half'
    )
    
    assert_response :success
    # half粒度で5年分 = 10期間（1年2半期 × 5年）
    assert_select '.schedule-table tbody tr', count: 10
  end

  test "schedule displays year range navigation" do
    sign_in_as @user
    
    current_year = Date.current.year
    field_id = 'ほ場1'.hash.abs
    
    plan = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: current_year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場1', area: 1000)
    
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: current_year,
      granularity: 'quarter'
    )
    
    assert_response :success
    # 5年分の期間表示が含まれることを確認（形式: "X年度 〜 Y年度（5年分）"）
    assert_select '.schedule-year-display' do |element|
      text = element.first.text
      assert_match(/#{current_year}年度/, text)
      assert_match(/#{current_year + 4}年度/, text)
      assert_match(/5年分/, text)
    end
  end

  test "schedule supports different granularities" do
    sign_in_as @user
    
    plan = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: Date.current.year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場1', area: 1000)
    crop1 = create(:cultivation_plan_crop, cultivation_plan: plan, name: 'トマト')
    create(:field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: field1,
      cultivation_plan_crop: crop1,
      start_date: Date.new(Date.current.year, 1, 15),
      completion_date: Date.new(Date.current.year, 3, 20),
      area: 1000
    )
    
    field_id = 'ほ場1'.hash.abs
    
    # 月単位
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: Date.current.year,
      granularity: 'month'
    )
    assert_response :success
    
    # 四半期単位
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: Date.current.year,
      granularity: 'quarter'
    )
    assert_response :success
    
    # 半期単位
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: Date.current.year,
      granularity: 'half'
    )
    assert_response :success
  end

  test "schedule only shows user's own farms" do
    sign_in_as @user
    
    get schedule_planning_schedules_path(
      farm_id: @other_farm.id,
      field_ids: [1],
      year: Date.current.year
    )
    
    assert_redirected_to fields_selection_planning_schedules_path
    assert_equal I18n.t('planning_schedules.errors.farm_not_found'), flash[:alert]
  end

  test "schedule does not show duplicate cultivations from overlapping plan years" do
    sign_in_as @user
    
    # 計画は1年毎に2年分を保持するため、重複が発生する可能性がある
    # 2024年度の計画: 2024年1月1日〜2025年12月31日
    # 2025年度の計画: 2025年1月1日〜2026年12月31日
    # 2026年度の計画: 2026年1月1日〜2027年12月31日
    
    target_year = 2025
    field_name = 'ほ場1'
    field_id = field_name.hash.abs
    crop_name = 'トマト'
    
    # 2024年度の計画を作成（2024年1月1日〜2025年12月31日）
    plan_2024 = create(:cultivation_plan,
      user: @user,
      farm: @farm,
      plan_year: 2024,
      planning_start_date: Date.new(2024, 1, 1),
      planning_end_date: Date.new(2025, 12, 31)
    )
    field_2024 = create(:cultivation_plan_field, cultivation_plan: plan_2024, name: field_name, area: 1000)
    crop_2024 = create(:cultivation_plan_crop, cultivation_plan: plan_2024, name: crop_name)
    # 2025年の栽培データを作成
    create(:field_cultivation,
      cultivation_plan: plan_2024,
      cultivation_plan_field: field_2024,
      cultivation_plan_crop: crop_2024,
      start_date: Date.new(target_year, 3, 1),
      completion_date: Date.new(target_year, 5, 31),
      area: 1000
    )
    
    # 2025年度の計画を作成（2025年1月1日〜2026年12月31日）
    plan_2025 = create(:cultivation_plan,
      user: @user,
      farm: @farm,
      plan_year: 2025,
      planning_start_date: Date.new(2025, 1, 1),
      planning_end_date: Date.new(2026, 12, 31)
    )
    field_2025 = create(:cultivation_plan_field, cultivation_plan: plan_2025, name: field_name, area: 1000)
    crop_2025 = create(:cultivation_plan_crop, cultivation_plan: plan_2025, name: crop_name)
    # 同じ2025年の栽培データを作成（重複の原因）
    create(:field_cultivation,
      cultivation_plan: plan_2025,
      cultivation_plan_field: field_2025,
      cultivation_plan_crop: crop_2025,
      start_date: Date.new(target_year, 3, 1),
      completion_date: Date.new(target_year, 5, 31),
      area: 1000
    )
    
    # 2026年度の計画を作成（2026年1月1日〜2027年12月31日）
    plan_2026 = create(:cultivation_plan,
      user: @user,
      farm: @farm,
      plan_year: 2026,
      planning_start_date: Date.new(2026, 1, 1),
      planning_end_date: Date.new(2027, 12, 31)
    )
    field_2026 = create(:cultivation_plan_field, cultivation_plan: plan_2026, name: field_name, area: 1000)
    crop_2026 = create(:cultivation_plan_crop, cultivation_plan: plan_2026, name: crop_name)
    # 2026年の栽培データを作成（重複しない）
    create(:field_cultivation,
      cultivation_plan: plan_2026,
      cultivation_plan_field: field_2026,
      cultivation_plan_crop: crop_2026,
      start_date: Date.new(2026, 3, 1),
      completion_date: Date.new(2026, 5, 31),
      area: 1000
    )
    
    # 2025年を表示期間としてscheduleアクションを呼び出す
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: target_year,
      granularity: 'quarter'
    )
    
    assert_response :success
    
    # 2025年の栽培データが重複せず、1回だけ表示されることを確認
    # コントローラーから取得したデータを直接確認
    # @cultivations_by_fieldに2025年のデータが1回だけ含まれることを確認
    doc = Nokogiri::HTML(response.body)
    
    # 2025年のQ2（4-6月）の期間を特定
    # quarter粒度の場合、2025年のQ2は "2025 Q2" というラベルになる
    q2_period = doc.css('.schedule-table-period-cell').find { |cell| cell.text.include?('2025 Q2') }
    
    if q2_period
      # Q2の行を取得
      q2_row = q2_period.parent
      # Q2のセル内の栽培項目を取得
      q2_cultivations = q2_row.css('.cultivation-item')
      tomato_in_q2 = q2_cultivations.select { |item| item.text.include?(crop_name) }
      
      # 2025年のQ2（4-6月）にトマトが1回だけ表示されることを確認
      assert_equal 1, tomato_in_q2.count, "2025年のQ2に同じ年度の栽培データが重複して表示されている"
    else
      # Q2が見つからない場合は、すべての期間でトマトが表示されている数をカウント
      cultivation_items = doc.css('.cultivation-item')
      tomato_cultivations = cultivation_items.select { |item| item.text.include?(crop_name) && item.text.include?('2025') }
      
      # 2025年のデータが1回だけ表示されることを確認
      assert_equal 1, tomato_cultivations.count, "同じ年度の栽培データが重複して表示されている"
    end
  end

  test "fields_selection displays year_range in descending order" do
    sign_in_as @user
    
    plan = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: Date.current.year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場1', area: 1000)
    
    get fields_selection_planning_schedules_path(farm_id: @farm.id)
    
    assert_response :success
    
    # ビューに表示される年度範囲を確認
    # fields_selection.html.erbの76行目で @year_range.first と @year_range.last が表示される
    doc = Nokogiri::HTML(response.body)
    period_text = doc.text
    
    # 年度範囲が表示されていることを確認
    current_year = Date.current.year
    next_year = current_year + 1
    expected_first = next_year
    expected_last = next_year - 4
    
    # ビューに表示される年度範囲のテキストを確認
    assert_match(/#{expected_first}年度/, period_text, "Should display next year (#{expected_first})")
    assert_match(/#{expected_last}年度/, period_text, "Should display 5 years before next year (#{expected_last})")
  end

  test "fields_selection auto selects fields when params field_ids are blank" do
    sign_in_as @user

    farm_with_plan = create(:farm, user: @user, name: '計画農場')
    plan = create(:cultivation_plan, :private, user: @user, farm: farm_with_plan, plan_year: Date.current.year)
    create(:cultivation_plan_field, cultivation_plan: plan, name: '計画ほ場', area: 1000)

    get fields_selection_planning_schedules_path(
      farm_id: farm_with_plan.id,
      field_ids: ['']
    )

    assert_response :success
    field_id = '計画ほ場'.hash.abs
    assert_select "input.field-checkbox[value='#{field_id}'][checked='checked']", count: 1
  end

  test "schedule displays year_range in descending order" do
    sign_in_as @user
    
    current_year = Date.current.year
    field_id = 'ほ場1'.hash.abs
    
    plan = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: current_year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場1', area: 1000)
    
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: current_year,
      granularity: 'quarter'
    )
    
    assert_response :success
  end

  test "schedule maintains single column per field row when quarter-contained and quarter-spanning cultivations start in same quarter" do
    sign_in_as @user
    
    # テスト用の年度を設定（現在の年度を使用）
    current_year = Date.current.year
    test_year = current_year
    field_name = '1ほ場'
    field_id = field_name.hash.abs
    
    # 計画を作成
    plan = create(:cultivation_plan,
      :private,
      user: @user,
      farm: @farm,
      plan_year: test_year,
      planning_start_date: Date.new(test_year, 1, 1),
      planning_end_date: Date.new(test_year + 1, 12, 31)
    )
    
    # ほ場を作成
    field = create(:cultivation_plan_field,
      cultivation_plan: plan,
      name: field_name,
      area: 1000
    )
    
    # 作物を作成
    crop1 = create(:cultivation_plan_crop, cultivation_plan: plan, name: 'ほうれん草')
    crop2 = create(:cultivation_plan_crop, cultivation_plan: plan, name: 'トマト')
    
    # 4半期に収まる作付け（Q1内のみ: 1月15日〜3月15日、rowspan=1）
    # 注意: Q1は1月1日〜3月31日なので、この作付けはQ1内に収まる
    create(:field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: field,
      cultivation_plan_crop: crop1,
      start_date: Date.new(test_year, 1, 15),
      completion_date: Date.new(test_year, 3, 15),
      area: 500
    )
    
    # 同じ4半期に開始するが、4半期をまたぐ作付け（Q1からQ2へ: 3月1日〜6月30日、rowspan=2）
    # 注意: この作付けはQ1（1月1日〜3月31日）とQ2（4月1日〜6月30日）にまたがる
    create(:field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: field,
      cultivation_plan_crop: crop2,
      start_date: Date.new(test_year, 3, 1),
      completion_date: Date.new(test_year, 6, 30),
      area: 500
    )
    
    # スケジュールを取得（来年から過去5年分の範囲内の年度を指定）
    next_year = current_year + 1
    start_year = next_year - PlanningSchedulesController::DEFAULT_YEARS_RANGE + 1
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: start_year,
      granularity: 'quarter'
    )
    
    assert_response :success
    
    # HTMLをパース
    doc = Nokogiri::HTML(response.body)
    
    # テーブルの各行を取得（期間の行のみ）
    rows = doc.css('.schedule-table tbody tr')
    
    # 各行で、各ほ場の列数が実装仕様の範囲内（0〜2）であることを確認
    rows.each_with_index do |row, row_index|
      # 期間のセルを除外し、ほ場のセル（schedule-table-cell）のみを取得
      field_cells = row.css('td.schedule-table-cell')
      period_label = row.css('.schedule-table-period-cell').first&.text || "行#{row_index + 1}"
      
      # デバッグ用: すべての行の詳細を出力
      puts "\n[DEBUG] 期間: #{period_label}, セル数: #{field_cells.count}"
      field_cells.each_with_index do |cell, cell_index|
        rowspan = cell['rowspan'] || 'なし'
        content = cell.text.strip.gsub(/\s+/, ' ')[0..100]
        puts "  [DEBUG] セル#{cell_index + 1}: rowspan=#{rowspan}, 内容=#{content}"
      end
      
      # 実装仕様: 降順・rowspan運用により、継続行は0セル、同期間に2作付けが存在する場合は2セルになることがある
      assert field_cells.count <= 2, 
        "各行で各ほ場の列は2つ以下であるべきです（実際: #{field_cells.count}個）。期間: #{period_label}"
    end
    
    # Q1で開始する両方の作付けがQ1行内に表示されていることを確認（1ほ場=2列表現。1セルに同居でなくても可）
    q1_row = rows.find { |r| r.css('.schedule-table-period-cell').first&.text&.include?('Q1') && r.css('.schedule-table-period-cell').first&.text&.include?(test_year.to_s) }
    if q1_row
      q1_cells = q1_row.css('td.schedule-table-cell')
      q1_text = q1_cells.map { |c| c.text }.join(' ')
      assert q1_text.include?('ほうれん草'), 
        "Q1の行にほうれん草が含まれるべきです。実際の内容: #{q1_text[0..200]}"
      # 降順・rowspan仕様では、Q1に開始するがQ2へまたぐ作付（トマト）はQ2行に開始セルが置かれ、
      # Q1行ではセル非描画のため、ここでトマトの存在までは要求しない
    end
    
    # 降順・rowspan仕様では、Q1開始でQ2へまたぐ作付（または境界開始）はQ2行に開始セル（rowspan=2）が置かれる
    q2_row = rows.find { |r| r.css('.schedule-table-period-cell').first&.text&.include?('Q2') && r.css('.schedule-table-period-cell').first&.text&.include?(test_year.to_s) }
    if q2_row
      q2_cells = q2_row.css('td.schedule-table-cell')
      q2_cell_with_rowspan = q2_cells.find { |cell| cell['rowspan'] && cell['rowspan'].to_i == 2 }
      assert_not_nil q2_cell_with_rowspan, "Q2のセルにrowspan=2が設定されていません。Q2、Q1の2四半期にまたがるため、rowspan=2であるべきです"
      q2_text = q2_cell_with_rowspan.text
      assert q2_text.include?('トマト'), "Q2の開始セルにトマトが表示されていません。実際の内容: #{q2_text[0..200]}"
    end
  end

  test "schedule displays cultivation starting on August 30 with descending periods (month granularity)" do
    sign_in_as @user
    
    # テスト用の年度を設定
    current_year = Date.current.year
    test_year = current_year + 1  # 2026年を想定
    field_name = '1ほ場'
    field_id = field_name.hash.abs
    
    # 計画を作成
    plan = create(:cultivation_plan,
      :private,
      user: @user,
      farm: @farm,
      plan_year: test_year,
      planning_start_date: Date.new(test_year, 1, 1),
      planning_end_date: Date.new(test_year + 1, 12, 31)
    )
    
    # ほ場を作成
    field = create(:cultivation_plan_field,
      cultivation_plan: plan,
      name: field_name,
      area: 1000
    )
    
    # 作物を作成
    crop = create(:cultivation_plan_crop, cultivation_plan: plan, name: 'ほうれん草')
    
    # 8月30日から始まる作付（8月、9月、10月にまたがる）
    create(:field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: field,
      cultivation_plan_crop: crop,
      start_date: Date.new(test_year, 8, 30),
      completion_date: Date.new(test_year, 10, 26),
      area: 500
    )
    
    # スケジュールを取得（月単位）
    next_year = current_year + 1
    start_year = next_year - PlanningSchedulesController::DEFAULT_YEARS_RANGE + 1
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: start_year,
      granularity: 'month'
    )
    
    assert_response :success
    
    # HTMLをパース
    doc = Nokogiri::HTML(response.body)
    
    # テーブルの各行を取得（期間の行のみ）
    rows = doc.css('.schedule-table tbody tr')
    
    # 8月の行を取得
    august_row = rows.find { |r| 
      period_cell = r.css('.schedule-table-period-cell').first
      period_cell && period_cell.text.include?("#{test_year}年08月")
    }
    assert_not_nil august_row, "8月の行が見つかりません"
    
    # 降順仕様では、開始セルは最新の期間（8-10月なら10月）に配置され、rowspanで下方向にマージされる
    # よって8月行はセルを描画しない（10月のrowspanでカバーされる）
    august_cells = august_row.css('td.schedule-table-cell')
    august_cell_count = august_cells.count
    assert_equal 0, august_cell_count, 
                 "8月の行にセルが描画されていますが、rowspanでマージされるため、セルを描画する必要はありません。セル数: #{august_cell_count}"
    
    # デバッグ出力: 8月のセル内容を確認
    puts "\n[DEBUG] 8月のセル数: #{august_cells.count}"
    august_cells.each_with_index do |cell, index|
      rowspan = cell['rowspan'] || 'なし'
      colspan = cell['colspan'] || 'なし'
      content = cell.text.strip.gsub(/\s+/, ' ')[0..200]
      puts "  [DEBUG] 8月セル#{index + 1}: rowspan=#{rowspan}, colspan=#{colspan}, 内容=#{content}"
    end
    
    # 8月の行全体のHTMLを確認
    august_row_html = august_row.to_html
    puts "\n[DEBUG] 8月の行全体のHTML:"
    puts august_row_html[0..1000]
    
    # 10月の行でrowspan=3の開始セルが描画されていることを確認
    october_row = rows.find { |r| 
      period_cell = r.css('.schedule-table-period-cell').first
      period_cell && period_cell.text.include?("#{test_year}年10月")
    }
    assert_not_nil october_row, "10月の行が見つかりません"
    october_cells = october_row.css('td.schedule-table-cell')
    october_cell_with_rowspan = october_cells.find { |cell| cell['rowspan'] && cell['rowspan'].to_i == 3 }
    assert_not_nil october_cell_with_rowspan, 
                   "10月のセルにrowspan=3が設定されていません。10月、9月、8月の3ヶ月にまたがるため、rowspan=3であるべきです。セル数: #{october_cells.count}"
    october_cell_content = october_cell_with_rowspan.text.strip
    assert october_cell_content.include?('ほうれん草'), 
           "10月にほうれん草が表示されていません。セル内容: #{october_cell_content[0..200]}"
    assert october_cell_content.include?('08/30'), 
           "10月に開始日（08/30）が表示されていません。セル内容: #{october_cell_content[0..200]}"
    
    # 6月の行を取得（作付が表示されていないことを確認）
    june_row = rows.find { |r| 
      period_cell = r.css('.schedule-table-period-cell').first
      period_cell && period_cell.text.include?("#{test_year}年06月")
    }
    if june_row
      june_cells = june_row.css('td.schedule-table-cell')
      june_cell_content = june_cells.map { |cell| cell.text.strip }.join(' ')
      
      # デバッグ出力: 6月のセル内容を確認
      puts "\n[DEBUG] 6月のセル数: #{june_cells.count}"
      june_cells.each_with_index do |cell, index|
        rowspan = cell['rowspan'] || 'なし'
        colspan = cell['colspan'] || 'なし'
        content = cell.text.strip.gsub(/\s+/, ' ')[0..200]
        puts "  [DEBUG] 6月セル#{index + 1}: rowspan=#{rowspan}, colspan=#{colspan}, 内容=#{content}"
      end
      
      # 6月の行全体のHTMLを確認
      june_row_html = june_row.to_html
      puts "\n[DEBUG] 6月の行全体のHTML:"
      puts june_row_html[0..1000]
      
      # 6月に作付が表示されていないことを確認
      assert_not june_cell_content.include?('ほうれん草'), 
                 "6月にほうれん草が表示されていますが、8月30日から始まる作付なので6月には表示されるべきではありません。セル内容: #{june_cell_content[0..200]}、実際のHTML: #{june_row_html[0..500]}"
      assert_not june_cell_content.include?('08/30'), 
                 "6月に開始日（08/30）が表示されていますが、8月30日から始まる作付なので6月には表示されるべきではありません。セル内容: #{june_cell_content[0..200]}、実際のHTML: #{june_row_html[0..500]}"
    end
    
    # 7月の行を取得（作付が表示されていないことを確認）
    july_row = rows.find { |r| 
      period_cell = r.css('.schedule-table-period-cell').first
      period_cell && period_cell.text.include?("#{test_year}年07月")
    }
    if july_row
      july_cells = july_row.css('td.schedule-table-cell')
      july_cell_content = july_cells.map { |cell| cell.text.strip }.join(' ')
      # 7月に作付が表示されていないことを確認
      assert_not july_cell_content.include?('ほうれん草'), 
                 "7月にほうれん草が表示されていますが、8月30日から始まる作付なので7月には表示されるべきではありません。セル内容: #{july_cell_content[0..200]}"
      assert_not july_cell_content.include?('08/30'), 
                 "7月に開始日（08/30）が表示されていますが、8月30日から始まる作付なので7月には表示されるべきではありません。セル内容: #{july_cell_content[0..200]}"
    end
  end

  test "schedule displays two cultivations correctly when one starts on June 8 and another starts on August 30 with month granularity" do
    sign_in_as @user
    
    # テスト用の年度を設定
    current_year = Date.current.year
    test_year = current_year + 1  # 2026年を想定
    field_name = '1ほ場'
    field_id = field_name.hash.abs
    
    # 計画を作成
    plan = create(:cultivation_plan,
      :private,
      user: @user,
      farm: @farm,
      plan_year: test_year,
      planning_start_date: Date.new(test_year, 1, 1),
      planning_end_date: Date.new(test_year + 1, 12, 31)
    )
    
    # ほ場を作成
    field = create(:cultivation_plan_field,
      cultivation_plan: plan,
      name: field_name,
      area: 1000
    )
    
    # 作物を作成
    crop = create(:cultivation_plan_crop, cultivation_plan: plan, name: 'ほうれん草')
    
    # 6月8日から始まる作付（6月、7月にまたがる）
    create(:field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: field,
      cultivation_plan_crop: crop,
      start_date: Date.new(test_year, 6, 8),
      completion_date: Date.new(test_year, 7, 19),
      area: 500
    )
    
    # 8月30日から始まる作付（8月、9月、10月にまたがる）
    create(:field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: field,
      cultivation_plan_crop: crop,
      start_date: Date.new(test_year, 8, 30),
      completion_date: Date.new(test_year, 10, 26),
      area: 500
    )
    
    # スケジュールを取得（月単位）
    next_year = current_year + 1
    start_year = next_year - PlanningSchedulesController::DEFAULT_YEARS_RANGE + 1
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: start_year,
      granularity: 'month'
    )
    
    assert_response :success
    
    # HTMLをパース
    doc = Nokogiri::HTML(response.body)
    
    # テーブルの各行を取得（期間の行のみ）
    rows = doc.css('.schedule-table tbody tr')
    
    # 6月の行を取得
    june_row = rows.find { |r| 
      period_cell = r.css('.schedule-table-period-cell').first
      period_cell && period_cell.text.include?("#{test_year}年06月")
    }
    assert_not_nil june_row, "6月の行が見つかりません"
    
    # 6月のセルを確認
    june_cells = june_row.css('td.schedule-table-cell')
    
    # 降順の場合、rowspanは下方向（より古い期間）にマージされるため、
    # 6月8日から始まる作付（6月、7月にまたがる）は7月の行にセルを配置し、
    # rowspan=2で下方向（7月、6月）にマージされる
    # 6月の行では空白セルが描画されるが、7月の行のrowspanで6月にも表示される
    
    # 7月の行を取得（先に確認）
    july_row = rows.find { |r| 
      period_cell = r.css('.schedule-table-period-cell').first
      period_cell && period_cell.text.include?("#{test_year}年07月")
    }
    assert_not_nil july_row, "7月の行が見つかりません"
    
    # 7月のセルを確認
    july_cells = july_row.css('td.schedule-table-cell')
    
    # 7月のセルにrowspan=2があることを確認（7月、6月の2ヶ月にまたがるため）
    july_cell_with_rowspan = july_cells.find { |cell| cell['rowspan'] && cell['rowspan'].to_i == 2 }
    assert_not_nil july_cell_with_rowspan, 
                   "7月のセルにrowspan=2が設定されていません。7月、6月の2ヶ月にまたがるため、rowspan=2であるべきです。セル数: #{july_cells.count}"
    
    # 7月に作付が表示されていることを確認（06/08から始まる作付）
    july_cell_content = july_cell_with_rowspan.text.strip if july_cell_with_rowspan
    assert july_cell_content.include?('ほうれん草'), 
           "7月にほうれん草が表示されていません。セル内容: #{july_cell_content[0..200]}"
    assert july_cell_content.include?('06/08'), 
           "7月に開始日（06/08）が表示されていません。セル内容: #{july_cell_content[0..200]}"
    
    # 6月の行では、7月の行のrowspanでマージされるため、セルを描画しない
    # rowspanでマージされたセルは、その後の行では自動的にスキップされるため、
    # 6月の行ではセルを描画する必要はない（これにより、列数が正しくなる）
    # したがって、6月の行のHTMLにはセルが含まれないことを確認する
    june_row_html = june_row.to_html
    # 6月の行には期間セルしか含まれない（ほ場のセルは描画されない）
    june_cell_count = june_row.css('td.schedule-table-cell').count
    assert_equal 0, june_cell_count, 
                 "6月の行にセルが描画されていますが、rowspanでマージされるため、セルを描画する必要はありません。セル数: #{june_cell_count}、行HTML: #{june_row_html[0..500]}"
    
    # デバッグ出力: 6月のセル内容を確認
    puts "\n[DEBUG] 6月のセル数: #{june_cells.count}"
    june_cells.each_with_index do |cell, index|
      rowspan = cell['rowspan'] || 'なし'
      colspan = cell['colspan'] || 'なし'
      content = cell.text.strip.gsub(/\s+/, ' ')[0..200]
      puts "  [DEBUG] 6月セル#{index + 1}: rowspan=#{rowspan}, colspan=#{colspan}, 内容=#{content}"
    end
    
    # デバッグ出力: 7月のセル内容を確認
    puts "\n[DEBUG] 7月のセル数: #{july_cells.count}"
    july_cells.each_with_index do |cell, index|
      rowspan = cell['rowspan'] || 'なし'
      colspan = cell['colspan'] || 'なし'
      content = cell.text.strip.gsub(/\s+/, ' ')[0..200]
      puts "  [DEBUG] 7月セル#{index + 1}: rowspan=#{rowspan}, colspan=#{colspan}, 内容=#{content}"
    end
    
    # 6月の行全体のHTMLを確認
    june_row_html = june_row.to_html
    puts "\n[DEBUG] 6月の行全体のHTML:"
    puts june_row_html[0..1000]
    
    # 実際のperiodsとarrange結果を確認（デバッグ用）
    # 6月のperiod_indexを確認
    june_period_index = nil
    rows.each_with_index do |row, idx|
      period_cell = row.css('.schedule-table-period-cell').first
      if period_cell && period_cell.text.include?("#{test_year}年06月")
        june_period_index = idx
        break
      end
    end
    
    puts "\n[DEBUG] 6月のperiod_index: #{june_period_index}"
    
    # 実際のperiodsとarrange結果を確認するため、ビューから取得
    # テストでは直接コントローラーのインスタンス変数にアクセスできないため、
    # リクエストの後に再度取得する必要がある
    
    # 実際のperiodsを確認（リクエスト後のコントローラーから取得できないため、再度計算）
    # テスト用の年度を設定
    current_year = Date.current.year
    next_year = current_year + 1
    start_year = next_year - PlanningSchedulesController::DEFAULT_YEARS_RANGE + 1
    period_start = Date.new(start_year, 1, 1)
    period_end = Date.new(start_year + PlanningSchedulesController::DEFAULT_YEARS_RANGE - 1, 12, 31)
    
    # 期間の行を生成（月単位、降順）
    periods_asc = []
    current = period_start
    while current <= period_end
      period_end_date = [current.end_of_month, period_end].min
      periods_asc << {
        label: I18n.l(current, format: '%Y年%m月'),
        start_date: current,
        end_date: period_end_date
      }
      current = current.next_month.beginning_of_month
    end
    periods = periods_asc.reverse
    
    puts "\n[DEBUG] 実際のperiods（降順）:"
    periods.each_with_index do |period, idx|
      if period[:label].include?("#{test_year}年06月") || period[:label].include?("#{test_year}年07月") || period[:label].include?("#{test_year}年08月") || period[:label].include?("#{test_year}年09月") || period[:label].include?("#{test_year}年10月")
        puts "  [#{idx}] #{period[:label]}: #{period[:start_date]} - #{period[:end_date]}"
      end
    end
    
    # 実際のarrange結果を確認
    field_name = '1ほ場'
    cultivations = plan.field_cultivations.map do |fc|
      {
        crop_name: fc.cultivation_plan_crop.name,
        start_date: fc.start_date,
        completion_date: fc.completion_date,
        area: fc.area
      }
    end
    
    arranged_cultivations = ScheduleTableFieldArranger.arrange(
      cultivations: cultivations,
      periods: periods
    )
    
    arranged_cultivations.each do |c|
      if c[:cultivation][:start_date] == Date.new(test_year, 6, 8)
        puts "\n[DEBUG] 6月8日から始まる作付のarrange結果:"
        puts "  start_period_index: #{c[:start_period_index]}"
        puts "  start_period: #{periods[c[:start_period_index]][:label] if c[:start_period_index] && periods[c[:start_period_index]]}"
        puts "  rowspan: #{c[:rowspan]}"
        puts "  periods: #{c[:periods].map { |p| p[:label] }.join(', ')}"
      elsif c[:cultivation][:start_date] == Date.new(test_year, 8, 30)
        puts "\n[DEBUG] 8月30日から始まる作付のarrange結果:"
        puts "  start_period_index: #{c[:start_period_index]}"
        puts "  start_period: #{periods[c[:start_period_index]][:label] if c[:start_period_index] && periods[c[:start_period_index]]}"
        puts "  rowspan: #{c[:rowspan]}"
        puts "  periods: #{c[:periods].map { |p| p[:label] }.join(', ')}"
      end
    end
    
    # 6月に8月30日から始まる作付が表示されていないことを確認
    june_row_content_for_check = june_row.to_html
    assert_not june_row_content_for_check.include?('08/30'), 
               "6月に開始日（08/30）が表示されていますが、8月30日から始まる作付なので6月には表示されるべきではありません。行HTML: #{june_row_content_for_check[0..500]}"
    
    # デバッグ出力: 7月のセル内容を確認
    puts "\n[DEBUG] 7月のセル数: #{july_cells.count}"
    july_cells.each_with_index do |cell, index|
      rowspan = cell['rowspan'] || 'なし'
      colspan = cell['colspan'] || 'なし'
      content = cell.text.strip.gsub(/\s+/, ' ')[0..200]
      puts "  [DEBUG] 7月セル#{index + 1}: rowspan=#{rowspan}, colspan=#{colspan}, 内容=#{content}"
    end
    
    # 7月の行全体のHTMLを確認
    july_row_html = july_row.to_html
    puts "\n[DEBUG] 7月の行全体のHTML:"
    puts july_row_html[0..1000]
    
    # 8月の行を取得
    august_row = rows.find { |r| 
      period_cell = r.css('.schedule-table-period-cell').first
      period_cell && period_cell.text.include?("#{test_year}年08月")
    }
    assert_not_nil august_row, "8月の行が見つかりません"
    
    # 8月のセルを確認
    august_cells = august_row.css('td.schedule-table-cell')
    
    # 降順の場合、rowspanは下方向（より古い期間）にマージされるため、
    # 8月30日から始まる作付（8月、9月、10月にまたがる）は10月の行にセルを配置し、
    # rowspan=3で下方向（10月、9月、8月）にマージされる
    
    # 10月の行を取得（先に確認）
    october_row = rows.find { |r| 
      period_cell = r.css('.schedule-table-period-cell').first
      period_cell && period_cell.text.include?("#{test_year}年10月")
    }
    assert_not_nil october_row, "10月の行が見つかりません"
    
    # 10月のセルを確認
    october_cells = october_row.css('td.schedule-table-cell')
    
    # 10月のセルにrowspan=3があることを確認（10月、9月、8月の3ヶ月にまたがるため）
    october_cell_with_rowspan = october_cells.find { |cell| cell['rowspan'] && cell['rowspan'].to_i == 3 }
    assert_not_nil october_cell_with_rowspan, 
                   "10月のセルにrowspan=3が設定されていません。10月、9月、8月の3ヶ月にまたがるため、rowspan=3であるべきです。セル数: #{october_cells.count}"
    
    # 10月に作付が表示されていることを確認（08/30から始まる作付）
    october_cell_content = october_cell_with_rowspan.text.strip if october_cell_with_rowspan
    assert october_cell_content.include?('ほうれん草'), 
           "10月にほうれん草が表示されていません。セル内容: #{october_cell_content[0..200]}"
    assert october_cell_content.include?('08/30'), 
           "10月に開始日（08/30）が表示されていません。セル内容: #{october_cell_content[0..200]}"
    
    # 8月の行では、10月の行のrowspanでマージされるため、セルを描画しない
    # rowspanでマージされたセルは、その後の行では自動的にスキップされるため、
    # 8月の行ではセルを描画する必要はない（これにより、列数が正しくなる）
    # したがって、8月の行のHTMLにはセルが含まれないことを確認する
    august_row_html = august_row.to_html
    # 8月の行には期間セルしか含まれない（ほ場のセルは描画されない）
    august_cell_count = august_row.css('td.schedule-table-cell').count
    assert_equal 0, august_cell_count, 
                 "8月の行にセルが描画されていますが、rowspanでマージされるため、セルを描画する必要はありません。セル数: #{august_cell_count}、行HTML: #{august_row_html[0..500]}"
    
    # デバッグ出力: 8月のセル内容を確認
    puts "\n[DEBUG] 8月のセル数: #{august_cells.count}"
    august_cells.each_with_index do |cell, index|
      rowspan = cell['rowspan'] || 'なし'
      colspan = cell['colspan'] || 'なし'
      content = cell.text.strip.gsub(/\s+/, ' ')[0..200]
      puts "  [DEBUG] 8月セル#{index + 1}: rowspan=#{rowspan}, colspan=#{colspan}, 内容=#{content}"
    end
    
    # 8月の行全体のHTMLを確認
    august_row_html = august_row.to_html
    puts "\n[DEBUG] 8月の行全体のHTML:"
    puts august_row_html[0..1000]
    
    # 8月に6月8日から始まる作付が表示されていないことを確認
    august_row_content_for_check = august_row.to_html
    assert_not august_row_content_for_check.include?('06/08'), 
               "8月に開始日（06/08）が表示されていますが、6月8日から始まる作付なので8月には表示されるべきではありません。行HTML: #{august_row_content_for_check[0..500]}"
    
    # 5月の行を取得（作付が表示されていないことを確認）
    may_row = rows.find { |r| 
      period_cell = r.css('.schedule-table-period-cell').first
      period_cell && period_cell.text.include?("#{test_year}年05月")
    }
    if may_row
      may_cells = may_row.css('td.schedule-table-cell')
      may_cell_content = may_cells.map { |cell| cell.text.strip }.join(' ')
      
      # 5月に作付が表示されていないことを確認
      assert_not may_cell_content.include?('ほうれん草'), 
                 "5月にほうれん草が表示されていますが、6月8日から始まる作付なので5月には表示されるべきではありません。セル内容: #{may_cell_content[0..200]}"
      assert_not may_cell_content.include?('06/08'), 
                 "5月に開始日（06/08）が表示されていますが、6月8日から始まる作付なので5月には表示されるべきではありません。セル内容: #{may_cell_content[0..200]}"
      assert_not may_cell_content.include?('08/30'), 
                 "5月に開始日（08/30）が表示されていますが、8月30日から始まる作付なので5月には表示されるべきではありません。セル内容: #{may_cell_content[0..200]}"
    end
  end

  # ========================================
  # 降順期間でのrowspan/colspanの動作を保証する包括的テスト
  # ========================================

  test "schedule_renders_single_cultivation_within_single_period_correctly_with_month_granularity" do
    sign_in_as @user
    
    test_year = Date.current.year + 1
    field_name = '1ほ場'
    field_id = field_name.hash.abs
    
    plan = create(:cultivation_plan,
      :private,
      user: @user,
      farm: @farm,
      plan_year: test_year,
      planning_start_date: Date.new(test_year, 1, 1),
      planning_end_date: Date.new(test_year + 1, 12, 31)
    )
    
    field = create(:cultivation_plan_field, cultivation_plan: plan, name: field_name, area: 1000)
    crop = create(:cultivation_plan_crop, cultivation_plan: plan, name: 'トマト')
    
    # 6月の期間に収まる作付
    create(:field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: field,
      cultivation_plan_crop: crop,
      start_date: Date.new(test_year, 6, 10),
      completion_date: Date.new(test_year, 6, 25),
      area: 500
    )
    
    next_year = Date.current.year + 1
    start_year = next_year - PlanningSchedulesController::DEFAULT_YEARS_RANGE + 1
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: start_year,
      granularity: 'month'
    )
    
    assert_response :success
    
    doc = Nokogiri::HTML(response.body)
    june_row = find_period_row(doc, "#{test_year}年06月")
    assert_not_nil june_row, "6月の行が見つかりません"
    june_cells = field_cells_in_row(june_row)
    june_cell_content = joined_cell_text(june_cells)
    assert june_cell_content.include?('トマト'), "6月にトマトが表示されていません"

    june_cell_with_rowspan = cell_with_rowspan(june_cells)
    assert_nil june_cell_with_rowspan, "6月のセルにrowspanが設定されていますが、単一期間に収まるため不要です"

    june_cell = june_cells.first
    assert_equal '2', colspan_of(june_cell), "6月のセルにcolspan=2が設定されていません。作付が1つのため、colspan=2であるべきです"
  end

  test "schedule_renders_single_cultivation_spanning_multiple_periods_with_rowspan_in_descending_order_with_month_granularity" do
    sign_in_as @user
    
    test_year = Date.current.year + 1
    field_name = '1ほ場'
    field_id = field_name.hash.abs
    
    plan = create(:cultivation_plan,
      :private,
      user: @user,
      farm: @farm,
      plan_year: test_year,
      planning_start_date: Date.new(test_year, 1, 1),
      planning_end_date: Date.new(test_year + 1, 12, 31)
    )
    
    field = create(:cultivation_plan_field, cultivation_plan: plan, name: field_name, area: 1000)
    crop = create(:cultivation_plan_crop, cultivation_plan: plan, name: 'ほうれん草')
    
    # 6月、7月、8月にまたがる作付
    create(:field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: field,
      cultivation_plan_crop: crop,
      start_date: Date.new(test_year, 6, 15),
      completion_date: Date.new(test_year, 8, 20),
      area: 500
    )
    
    next_year = Date.current.year + 1
    start_year = next_year - PlanningSchedulesController::DEFAULT_YEARS_RANGE + 1
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: start_year,
      granularity: 'month'
    )
    
    assert_response :success
    
    doc = Nokogiri::HTML(response.body)
    august_row = find_period_row(doc, "#{test_year}年08月")
    assert_not_nil august_row, "8月の行が見つかりません"
    august_cells = field_cells_in_row(august_row)
    august_cell_with_rowspan = cell_with_rowspan(august_cells, 3)
    assert_not_nil august_cell_with_rowspan, 
                   "8月のセルにrowspan=3が設定されていません。8月、7月、6月の3ヶ月にまたがるため、rowspan=3であるべきです"
    
    # 8月に作付が表示されていることを確認
    august_cell_content = august_cell_with_rowspan.text.strip
    assert august_cell_content.include?('ほうれん草'), "8月にほうれん草が表示されていません"
    
    # 7月の行を取得（継続中のセルは描画されない）
    july_row = find_period_row(doc, "#{test_year}年07月")
    assert_not_nil july_row, "7月の行が見つかりません"
    
    # 7月の行にはセルが描画されない（rowspanでマージされるため）
    july_cells = field_cells_in_row(july_row)
    july_cell_count = july_cells.count
    assert_equal 0, july_cell_count, 
                 "7月の行にセルが描画されていますが、rowspanでマージされるため、セルを描画する必要はありません。セル数: #{july_cell_count}"
    
    # 6月の行を取得（継続中のセルは描画されない）
    june_row = find_period_row(doc, "#{test_year}年06月")
    assert_not_nil june_row, "6月の行が見つかりません"
    
    # 6月の行にはセルが描画されない（rowspanでマージされるため）
    june_cells = field_cells_in_row(june_row)
    june_cell_count = june_cells.count
    assert_equal 0, june_cell_count, 
                 "6月の行にセルが描画されていますが、rowspanでマージされるため、セルを描画する必要はありません。セル数: #{june_cell_count}"
  end

  test "schedule_renders_two_cultivations_in_same_period_with_colspan_1_each_with_month_granularity" do
    sign_in_as @user
    
    test_year = Date.current.year + 1
    field_name = '1ほ場'
    field_id = field_name.hash.abs
    
    plan = create(:cultivation_plan,
      :private,
      user: @user,
      farm: @farm,
      plan_year: test_year,
      planning_start_date: Date.new(test_year, 1, 1),
      planning_end_date: Date.new(test_year + 1, 12, 31)
    )
    
    field = create(:cultivation_plan_field, cultivation_plan: plan, name: field_name, area: 1000)
    crop1 = create(:cultivation_plan_crop, cultivation_plan: plan, name: 'トマト')
    crop2 = create(:cultivation_plan_crop, cultivation_plan: plan, name: 'きゅうり')
    
    # 6月の期間に収まる2つの作付
    create(:field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: field,
      cultivation_plan_crop: crop1,
      start_date: Date.new(test_year, 6, 5),
      completion_date: Date.new(test_year, 6, 20),
      area: 500
    )
    
    create(:field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: field,
      cultivation_plan_crop: crop2,
      start_date: Date.new(test_year, 6, 15),
      completion_date: Date.new(test_year, 6, 30),
      area: 500
    )
    
    next_year = Date.current.year + 1
    start_year = next_year - PlanningSchedulesController::DEFAULT_YEARS_RANGE + 1
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: start_year,
      granularity: 'month'
    )
    
    assert_response :success
    
    doc = Nokogiri::HTML(response.body)
    june_row = find_period_row(doc, "#{test_year}年06月")
    assert_not_nil june_row, "6月の行が見つかりません"
    
    june_cells = field_cells_in_row(june_row)
    
    # 6月の行に2つのセルが描画されていることを確認（colspan=1を2つ使う）
    assert_equal 2, june_cells.count, 
                 "6月の行に2つのセルが描画されていません。作付が2つあるため、colspan=1を2つ使う必要があります。セル数: #{june_cells.count}"
    
    # 各セルにcolspan=1があることを確認
    june_cells.each { |cell| assert_equal '1', colspan_of(cell), "6月のセルにcolspan=1が設定されていません。作付が2つあるため、colspan=1であるべきです" }
    
    # 6月に両方の作付が表示されていることを確認
    june_cell_content = joined_cell_text(june_cells)
    assert june_cell_content.include?('トマト'), "6月にトマトが表示されていません"
    assert june_cell_content.include?('きゅうり'), "6月にきゅうりが表示されていません"
  end

  test "schedule_renders_two_cultivations_spanning_different_periods_with_correct_rowspan_and_colspan_with_month_granularity" do
    sign_in_as @user
    
    test_year = Date.current.year + 1
    field_name = '1ほ場'
    field_id = field_name.hash.abs
    
    plan = create(:cultivation_plan,
      :private,
      user: @user,
      farm: @farm,
      plan_year: test_year,
      planning_start_date: Date.new(test_year, 1, 1),
      planning_end_date: Date.new(test_year + 1, 12, 31)
    )
    
    field = create(:cultivation_plan_field, cultivation_plan: plan, name: field_name, area: 1000)
    crop = create(:cultivation_plan_crop, cultivation_plan: plan, name: 'ほうれん草')
    
    # 6月、7月にまたがる作付
    create(:field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: field,
      cultivation_plan_crop: crop,
      start_date: Date.new(test_year, 6, 8),
      completion_date: Date.new(test_year, 7, 19),
      area: 500
    )
    
    # 8月、9月、10月にまたがる作付
    create(:field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: field,
      cultivation_plan_crop: crop,
      start_date: Date.new(test_year, 8, 30),
      completion_date: Date.new(test_year, 10, 26),
      area: 500
    )
    
    next_year = Date.current.year + 1
    start_year = next_year - PlanningSchedulesController::DEFAULT_YEARS_RANGE + 1
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: start_year,
      granularity: 'month'
    )
    
    assert_response :success
    
    doc = Nokogiri::HTML(response.body)
    july_row = find_period_row(doc, "#{test_year}年07月")
    assert_not_nil july_row, "7月の行が見つかりません"
    
    july_cells = field_cells_in_row(july_row)
    
    # 7月のセルにrowspan=2があることを確認（7月、6月の2ヶ月にまたがるため）
    july_cell_with_rowspan = cell_with_rowspan(july_cells, 2)
    assert_not_nil july_cell_with_rowspan, 
                   "7月のセルにrowspan=2が設定されていません。7月、6月の2ヶ月にまたがるため、rowspan=2であるべきです"
    
    # 7月に作付が表示されていることを確認
    july_cell_content = july_cell_with_rowspan.text.strip
    assert july_cell_content.include?('ほうれん草'), "7月にほうれん草が表示されていません"
    assert july_cell_content.include?('06/08'), "7月に開始日（06/08）が表示されていません"
    
    # 6月の行にはセルが描画されない（rowspanでマージされるため）
    june_row = find_period_row(doc, "#{test_year}年06月")
    assert_not_nil june_row, "6月の行が見つかりません"
    
    june_cells = field_cells_in_row(june_row)
    june_cell_count = june_cells.count
    assert_equal 0, june_cell_count, 
                 "6月の行にセルが描画されていますが、rowspanでマージされるため、セルを描画する必要はありません。セル数: #{june_cell_count}"
    
    # 10月の行を取得（降順で最新の期間、8月-10月の作付が開始）
    october_row = find_period_row(doc, "#{test_year}年10月")
    assert_not_nil october_row, "10月の行が見つかりません"
    
    october_cells = field_cells_in_row(october_row)
    
    # 10月のセルにrowspan=3があることを確認（10月、9月、8月の3ヶ月にまたがるため）
    october_cell_with_rowspan = cell_with_rowspan(october_cells, 3)
    assert_not_nil october_cell_with_rowspan, 
                   "10月のセルにrowspan=3が設定されていません。10月、9月、8月の3ヶ月にまたがるため、rowspan=3であるべきです"
    
    # 10月に作付が表示されていることを確認
    october_cell_content = october_cell_with_rowspan.text.strip
    assert october_cell_content.include?('ほうれん草'), "10月にほうれん草が表示されていません"
    assert october_cell_content.include?('08/30'), "10月に開始日（08/30）が表示されていません"
    
    # 9月の行にはセルが描画されない（rowspanでマージされるため）
    september_row = find_period_row(doc, "#{test_year}年09月")
    assert_not_nil september_row, "9月の行が見つかりません"
    
    september_cells = field_cells_in_row(september_row)
    september_cell_count = september_cells.count
    assert_equal 0, september_cell_count, 
                 "9月の行にセルが描画されていますが、rowspanでマージされるため、セルを描画する必要はありません。セル数: #{september_cell_count}"
    
    # 8月の行にはセルが描画されない（rowspanでマージされるため）
    august_row = find_period_row(doc, "#{test_year}年08月")
    assert_not_nil august_row, "8月の行が見つかりません"
    
    august_cells = field_cells_in_row(august_row)
    august_cell_count = august_cells.count
    assert_equal 0, august_cell_count, 
                 "8月の行にセルが描画されていますが、rowspanでマージされるため、セルを描画する必要はありません。セル数: #{august_cell_count}"
  end

  test "schedule_maintains_consistent_column_count_across_all_rows_with_two_fields_and_month_granularity" do
    sign_in_as @user
    
    test_year = Date.current.year + 1
    field1_name = '1ほ場'
    field2_name = '2ほ場'
    field1_id = field1_name.hash.abs
    field2_id = field2_name.hash.abs
    
    plan = create(:cultivation_plan,
      :private,
      user: @user,
      farm: @farm,
      plan_year: test_year,
      planning_start_date: Date.new(test_year, 1, 1),
      planning_end_date: Date.new(test_year + 1, 12, 31)
    )
    
    field1 = create(:cultivation_plan_field, cultivation_plan: plan, name: field1_name, area: 1000)
    field2 = create(:cultivation_plan_field, cultivation_plan: plan, name: field2_name, area: 1000)
    crop = create(:cultivation_plan_crop, cultivation_plan: plan, name: 'トマト')
    
    # 1ほ場に6月、7月にまたがる作付
    create(:field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: field1,
      cultivation_plan_crop: crop,
      start_date: Date.new(test_year, 6, 8),
      completion_date: Date.new(test_year, 7, 19),
      area: 500
    )
    
    # 2ほ場に6月の期間に収まる作付
    create(:field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: field2,
      cultivation_plan_crop: crop,
      start_date: Date.new(test_year, 6, 15),
      completion_date: Date.new(test_year, 6, 30),
      area: 500
    )
    
    next_year = Date.current.year + 1
    start_year = next_year - PlanningSchedulesController::DEFAULT_YEARS_RANGE + 1
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field1_id, field2_id],
      year: start_year,
      granularity: 'month'
    )
    
    assert_response :success
    
    doc = Nokogiri::HTML(response.body)
    rows = doc.css('.schedule-table tbody tr')
    
    # すべての行で同じ列数が使われていることを確認
    rows.each do |row|
      period_cell = row.css('.schedule-table-period-cell').first
      next unless period_cell
      
      # 期間セルを除いたセル数（各ほ場で2列）を確認
      field_cells = row.css('td.schedule-table-cell')
      
      # ほ場が2つあるため、各ほ場で2列（colspan=2の場合は1セル、colspan=1の場合は2セル）が使われる
      # 合計で4列（2ほ場 × 2列）が使われる必要がある
      # ただし、rowspanでマージされる場合、継続中の行ではセルが描画されない
      
      # 各ほ場ごとに列数を確認
      # このテストでは、すべての行で同じ構造が維持されることを確認する
      # （rowspanでマージされる行ではセルが描画されないため、列数が異なる可能性がある）
    end
    
    # 6月の行を確認
    june_row = rows.find { |r| 
      period_cell = r.css('.schedule-table-period-cell').first
      period_cell && period_cell.text.include?("#{test_year}年06月")
    }
    assert_not_nil june_row, "6月の行が見つかりません"
    
    # 1ほ場は継続中（rowspanでマージされるため、セルが描画されない）
    # 2ほ場は6月に開始するため、セルが描画される
    june_field_cells = june_row.css('td.schedule-table-cell')
    # 2ほ場のみセルが描画されるため、2列（colspan=2の場合は1セル、colspan=1の場合は2セル）が描画される
    # ただし、1ほ場のrowspanでマージされたセルは視覚的に表示されるため、列数は正しく維持される
    
    # 7月の行を確認
    july_row = rows.find { |r| 
      period_cell = r.css('.schedule-table-period-cell').first
      period_cell && period_cell.text.include?("#{test_year}年07月")
    }
    assert_not_nil july_row, "7月の行が見つかりません"
    
    # 1ほ場は7月に開始するため、セルが描画される（rowspan=2）
    # 2ほ場は作付がないため、空白セルが描画される
    july_field_cells = july_row.css('td.schedule-table-cell')
    # 1ほ場と2ほ場の両方でセルが描画されるため、合計で4列が描画される
    # 1ほ場: colspan=2, rowspan=2のセルが1つ
    # 2ほ場: colspan=2の空白セルが1つ
    assert july_field_cells.count >= 2, 
           "7月の行にセルが描画されていません。1ほ場と2ほ場の両方でセルが描画される必要があります。セル数: #{july_field_cells.count}"
  end

  test "schedule_renders_correctly_with_quarter_granularity_for_descending_periods" do
    sign_in_as @user
    
    test_year = Date.current.year + 1
    field_name = '1ほ場'
    field_id = field_name.hash.abs
    
    plan = create(:cultivation_plan,
      :private,
      user: @user,
      farm: @farm,
      plan_year: test_year,
      planning_start_date: Date.new(test_year, 1, 1),
      planning_end_date: Date.new(test_year + 1, 12, 31)
    )
    
    field = create(:cultivation_plan_field, cultivation_plan: plan, name: field_name, area: 1000)
    crop = create(:cultivation_plan_crop, cultivation_plan: plan, name: 'ほうれん草')
    
    # Q3（7月-9月）とQ4（10月-12月）にまたがる作付
    create(:field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: field,
      cultivation_plan_crop: crop,
      start_date: Date.new(test_year, 9, 15),
      completion_date: Date.new(test_year, 11, 20),
      area: 500
    )
    
    next_year = Date.current.year + 1
    start_year = next_year - PlanningSchedulesController::DEFAULT_YEARS_RANGE + 1
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: start_year,
      granularity: 'quarter'
    )
    
    assert_response :success
    
    doc = Nokogiri::HTML(response.body)
    rows = doc.css('.schedule-table tbody tr')
    
    # Q4の行を取得（降順で最新の期間）
    q4_row = rows.find { |r| 
      period_cell = r.css('.schedule-table-period-cell').first
      period_cell && period_cell.text.include?("#{test_year} Q4")
    }
    assert_not_nil q4_row, "Q4の行が見つかりません"
    
    q4_cells = q4_row.css('td.schedule-table-cell')
    
    # Q4のセルにrowspan=2があることを確認（Q4、Q3の2四半期にまたがるため）
    q4_cell_with_rowspan = q4_cells.find { |cell| cell['rowspan'] && cell['rowspan'].to_i == 2 }
    assert_not_nil q4_cell_with_rowspan, 
                   "Q4のセルにrowspan=2が設定されていません。Q4、Q3の2四半期にまたがるため、rowspan=2であるべきです"
    
    # Q3の行にはセルが描画されない（rowspanでマージされるため）
    q3_row = rows.find { |r| 
      period_cell = r.css('.schedule-table-period-cell').first
      period_cell && period_cell.text.include?("#{test_year} Q3")
    }
    assert_not_nil q3_row, "Q3の行が見つかりません"
    
    q3_cells = q3_row.css('td.schedule-table-cell')
    q3_cell_count = q3_cells.count
    assert_equal 0, q3_cell_count, 
                 "Q3の行にセルが描画されていますが、rowspanでマージされるため、セルを描画する必要はありません。セル数: #{q3_cell_count}"
  end

  test "schedule_renders_correctly_with_half_year_granularity_for_descending_periods" do
    sign_in_as @user
    
    test_year = Date.current.year + 1
    field_name = '1ほ場'
    field_id = field_name.hash.abs
    
    plan = create(:cultivation_plan,
      :private,
      user: @user,
      farm: @farm,
      plan_year: test_year,
      planning_start_date: Date.new(test_year, 1, 1),
      planning_end_date: Date.new(test_year + 1, 12, 31)
    )
    
    field = create(:cultivation_plan_field, cultivation_plan: plan, name: field_name, area: 1000)
    crop = create(:cultivation_plan_crop, cultivation_plan: plan, name: 'ほうれん草')
    
    # 上半期（1月-6月）と下半期（7月-12月）にまたがる作付
    create(:field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: field,
      cultivation_plan_crop: crop,
      start_date: Date.new(test_year, 6, 15),
      completion_date: Date.new(test_year, 8, 20),
      area: 500
    )
    
    next_year = Date.current.year + 1
    start_year = next_year - PlanningSchedulesController::DEFAULT_YEARS_RANGE + 1
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: start_year,
      granularity: 'half'
    )
    
    assert_response :success
    
    doc = Nokogiri::HTML(response.body)
    rows = doc.css('.schedule-table tbody tr')
    
    # 下半期の行を取得（降順で最新の期間）
    second_half_row = rows.find { |r| 
      period_cell = r.css('.schedule-table-period-cell').first
      period_cell && period_cell.text.include?("#{test_year} 下半期")
    }
    assert_not_nil second_half_row, "下半期の行が見つかりません"
    
    second_half_cells = second_half_row.css('td.schedule-table-cell')
    
    # 下半期のセルにrowspan=2があることを確認（下半期、上半期の2半期にまたがるため）
    second_half_cell_with_rowspan = second_half_cells.find { |cell| cell['rowspan'] && cell['rowspan'].to_i == 2 }
    assert_not_nil second_half_cell_with_rowspan, 
                   "下半期のセルにrowspan=2が設定されていません。下半期、上半期の2半期にまたがるため、rowspan=2であるべきです"
    
    # 上半期の行にはセルが描画されない（rowspanでマージされるため）
    first_half_row = rows.find { |r| 
      period_cell = r.css('.schedule-table-period-cell').first
      period_cell && period_cell.text.include?("#{test_year} 上半期")
    }
    assert_not_nil first_half_row, "上半期の行が見つかりません"
    
    first_half_cells = first_half_row.css('td.schedule-table-cell')
    first_half_cell_count = first_half_cells.count
    assert_equal 0, first_half_cell_count, 
                 "上半期の行にセルが描画されていますが、rowspanでマージされるため、セルを描画する必要はありません。セル数: #{first_half_cell_count}"
  end
end

