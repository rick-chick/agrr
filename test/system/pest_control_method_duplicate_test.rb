# frozen_string_literal: true

require "application_system_test_case"

class PestControlMethodDuplicateTest < ApplicationSystemTestCase
  setup do
    @user = create(:user, admin: true)
    login_as_system_user(@user)
  end

  test "防除方法追加ボタンを1回クリックすると1つのパネルのみが追加される" do
    visit new_pest_path
    
    # 初期状態を確認
    initial_count = page.all('.control-method-fields', visible: :all).count
    
    # 防除方法追加ボタンをクリック
    click_button I18n.t('pests.form.add_control_method')
    
    # 1つだけ追加されることを確認
    sleep 0.5  # JavaScriptの処理を待つ
    new_count = page.all('.control-method-fields', visible: :all).count
    assert_equal initial_count + 1, new_count, "防除方法パネルが1つだけ追加されるべき"
  end

  test "防除方法追加ボタンを2回クリックすると2つのパネルが追加される" do
    visit new_pest_path
    
    # 初期状態を確認
    initial_count = page.all('.control-method-fields', visible: :all).count
    
    # 防除方法追加ボタンを2回クリック
    click_button I18n.t('pests.form.add_control_method')
    sleep 0.3
    click_button I18n.t('pests.form.add_control_method')
    
    # 2つ追加されることを確認
    sleep 0.5  # JavaScriptの処理を待つ
    new_count = page.all('.control-method-fields', visible: :all).count
    assert_equal initial_count + 2, new_count, "防除方法パネルが2つ追加されるべき"
  end

  test "turbo:loadイベント後も追加ボタンが1回のクリックで1つのパネルのみ追加する" do
    visit new_pest_path
    
    # 初期状態を確認
    initial_count = page.all('.control-method-fields', visible: :all).count
    
    # turbo:loadイベントをシミュレート（ページ遷移を再現）
    page.execute_script("document.dispatchEvent(new Event('turbo:load'));")
    sleep 0.3
    
    # 防除方法追加ボタンをクリック
    click_button I18n.t('pests.form.add_control_method')
    
    # 1つだけ追加されることを確認（重複登録されていないことを確認）
    sleep 0.5
    new_count = page.all('.control-method-fields', visible: :all).count
    assert_equal initial_count + 1, new_count, "turbo:load後も1つのパネルのみ追加されるべき"
  end

  test "複数回のturbo:loadイベント後も追加ボタンが正常に動作する" do
    visit new_pest_path
    
    # 初期状態を確認
    initial_count = page.all('.control-method-fields', visible: :all).count
    
    # turbo:loadイベントを複数回発火（重複登録をシミュレート）
    page.execute_script("document.dispatchEvent(new Event('turbo:load'));")
    sleep 0.2
    page.execute_script("document.dispatchEvent(new Event('turbo:load'));")
    sleep 0.2
    page.execute_script("document.dispatchEvent(new Event('turbo:load'));")
    sleep 0.3
    
    # 防除方法追加ボタンを1回クリック
    click_button I18n.t('pests.form.add_control_method')
    
    # 1つだけ追加されることを確認（重複登録されていないことを確認）
    sleep 0.5
    new_count = page.all('.control-method-fields', visible: :all).count
    assert_equal initial_count + 1, new_count, "複数回のturbo:load後も1つのパネルのみ追加されるべき"
  end

  test "編集画面でも防除方法追加ボタンが正常に動作する" do
    pest = create(:pest, :complete, is_reference: true)
    visit edit_pest_path(pest)
    
    # 既存の防除方法を確認
    initial_count = page.all('.control-method-fields', visible: :all).count
    assert initial_count > 0, "編集画面には既存の防除方法が表示されるべき"
    
    # 防除方法追加ボタンをクリック
    click_button I18n.t('pests.form.add_control_method')
    
    # 1つだけ追加されることを確認
    sleep 0.5
    new_count = page.all('.control-method-fields', visible: :all).count
    assert_equal initial_count + 1, new_count, "編集画面でも1つのパネルのみ追加されるべき"
  end
end

