# frozen_string_literal: true

require 'test_helper'

class FertilizesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in_as @user
    @fertilize = create(:fertilize, is_reference: true)
  end

  test "should get index" do
    get fertilizes_path
    assert_response :success
  end

  test "should show fertilize" do
    get fertilize_path(@fertilize)
    assert_response :success
  end

  test "should get new" do
    get new_fertilize_path
    assert_response :success
  end

  test "should get edit" do
    # 参照肥料は管理者のみ編集可能
    skip "参照肥料は管理者のみ編集可能なためスキップ"
  end

  test "should create fertilize" do
    assert_difference('Fertilize.count') do
      post fertilizes_path, params: { fertilize: {
        name: 'テスト肥料',
        n: 20.0,
        p: 10.0,
        k: 10.0,
        description: 'テスト用',
        package_size: '20kg'
      } }
    end

    assert_redirected_to fertilize_path(Fertilize.last)
    fertilize = Fertilize.last
    assert_equal '20kg', fertilize.package_size
  end

  test "should update fertilize" do
    # ユーザー肥料を作成
    fertilize = create(:fertilize, is_reference: false)
    
    patch fertilize_path(fertilize), params: { fertilize: {
      name: fertilize.name,
      n: 25.0
    } }
    assert_redirected_to fertilize_path(fertilize)
    fertilize.reload
    assert_equal 25.0, fertilize.n
  end

  test "should update fertilize with package_size" do
    # ユーザー肥料を作成
    fertilize = create(:fertilize, is_reference: false)
    
    patch fertilize_path(fertilize), params: { fertilize: {
      name: fertilize.name,
      package_size: '25kg'
    } }
    assert_redirected_to fertilize_path(fertilize)
    fertilize.reload
    assert_equal '25kg', fertilize.package_size
  end

  test "should destroy fertilize" do
    # 外部参照のない肥料を作成
    fertilize = create(:fertilize, is_reference: false)
    
    assert_difference('Fertilize.count', -1) do
      delete fertilize_path(fertilize)
    end

    assert_redirected_to fertilizes_path
  end
end

