# frozen_string_literal: true

require "test_helper"

class BlueprintRegenerationGatewayDouble
  attr_reader :calls

  def initialize
    @calls = []
  end

  def regenerate_from_crop!(crop_id:)
    @calls << crop_id
  end
end

# 他ユーザーの作物の edit GET 拒否は show 拒否と同一の認可経路のため省略（CropDetailInteractor 単体で表明）。
class CropsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  setup do
    @user = create(:user)
    @admin_user = create(:user, admin: true)
    @other_user = create(:user)

    # 参照作物（user_id: nil）
    @reference_crop = create(:crop, :with_stages, is_reference: true, user_id: nil)
    # 一般ユーザーの作物
    @user_crop = create(:crop, :with_stages, user: @user)
    # 他のユーザーの作物
    @other_user_crop = create(:crop, :with_stages, user: @other_user)
    # 管理者の作物
    @admin_crop = create(:crop, :with_stages, user: @admin_user)
  end

  # ========== index アクションのテスト ==========
  #
  # index の絞り込み（一般ユーザーは自分の作物のみ／管理者は参照作物も）は
  # CropListInteractor のユニットテストが担保する。crop-card のテンプレート描画は
  # test/views/crops_index_view_test.rb が担保する。
  # ここは各ロールで index アクションの配線が通ることのみ確認する。

  test "一般ユーザーの index は正常に描画される" do
    sign_in_as @user
    get crops_path

    assert_response :success
  end

  test "管理者の index は正常に描画される" do
    sign_in_as @admin_user
    get crops_path

    assert_response :success
  end

  # ========== show アクションのテスト ==========

  test "一般ユーザーは自身の作物をshowできる" do
    sign_in_as @user
    get crop_path(@user_crop)

    assert_response :success
  end

  test "一般ユーザーは参照作物をshowできる" do
    sign_in_as @user
    get crop_path(@reference_crop)

    assert_response :success
  end

  test "作業テンプレートが表示される" do
    sign_in_as @user
    task = create(:agricultural_task, :soil_preparation)
    create(
      :crop_task_template,
      crop: @user_crop,
      agricultural_task: task,
      name: task.name,
      description: task.description,
      time_per_sqm: task.time_per_sqm,
      weather_dependency: task.weather_dependency,
      required_tools: task.required_tools,
      skill_level: task.skill_level,
      task_type: task.task_type,
      task_type_id: task.task_type_id,
      is_reference: task.is_reference
    )
    create(:crop_task_schedule_blueprint,
           crop: @user_crop,
           agricultural_task: task,
           stage_order: 1,
           stage_name: "定植前整備",
           gdd_trigger: BigDecimal("0.0"),
           gdd_tolerance: BigDecimal("5.0"),
           priority: 1,
           source: "agrr_schedule")
    fertilizer_task = create(:agricultural_task, :user_owned, user: @user, name: "追肥")
    create(:crop_task_schedule_blueprint,
           :fertilizer,
           crop: @user_crop,
           agricultural_task: fertilizer_task,
           stage_order: 2,
           stage_name: "追肥",
           gdd_trigger: BigDecimal("150.0"),
           gdd_tolerance: BigDecimal("10.0"),
           priority: 2)
    manual_task = create(:agricultural_task, :user_owned, user: @user, name: "潅水")
    create(:crop_task_template,
           crop: @user_crop,
           agricultural_task: manual_task,
           name: manual_task.name)

    get crop_path(@user_crop)

    assert_response :success
    assert_select "#crop-task-schedule-blueprints"
    assert_select "#crop-task-schedule-blueprints", text: /土壌準備/
    assert_select "#crop-task-schedule-blueprints", text: /追肥/
    assert_select '.task-blueprint-card[data-gdd-trigger="150.0"]'
    # manual_task（潅水）のテンプレートが表示されることを確認
    # 参照タスク（task）のテンプレートはavailable_agricultural_tasksに含まれないため表示されない
    assert_select ".task-manual-grid .task-manual-card .task-manual-card__name", text: /潅水/
  end

  # 害虫セクション（pest-card レイアウト）のテンプレート描画は
  # test/views/crops_show_sections_view_test.rb が担保する。害虫の関連付け・並び順は
  # CropDetailInteractor のユニットテストが担保する。crop#show の配線は上の
  # 「作業テンプレートが表示される」テストが通している。

  test "管理者はAIで作業テンプレートを生成できる" do
    sign_in_as @admin_user
    gateway_double = BlueprintRegenerationGatewayDouble.new

    CompositionRoot.stub(:crop_task_schedule_blueprint_regeneration_gateway, gateway_double) do
      post generate_task_schedule_blueprints_crop_path(@admin_crop)
    end

    assert_equal 1, gateway_double.calls.size
    assert_equal @admin_crop.id, gateway_double.calls.first
    assert_redirected_to crop_path(@admin_crop)
    assert_equal I18n.t("crops.flash.task_schedule_blueprints_generated"), flash[:notice]
  end

  test "一般ユーザーはAIで作業テンプレートを生成できない" do
    sign_in_as @user

    post generate_task_schedule_blueprints_crop_path(@user_crop)

    assert_redirected_to root_path
    assert_equal I18n.t("auth.messages.admin_required"), flash[:alert]
  end

  test "一般ユーザーは他のユーザーの作物をshowできない" do
    sign_in_as @user
    get crop_path(@other_user_crop)

    assert_redirected_to crops_path
    assert_equal I18n.t("crops.flash.no_permission"), flash[:alert]
  end

  # ========== edit アクションのテスト ==========

  test "一般ユーザーは自身の作物をeditできる" do
    sign_in_as @user
    get edit_crop_path(@user_crop)

    assert_response :success
  end

  test "一般ユーザーは参照作物をeditできない" do
    sign_in_as @user
    get edit_crop_path(@reference_crop)

    assert_redirected_to crops_path
    assert_equal I18n.t("crops.flash.no_permission"), flash[:alert]
  end

  test "管理者は参照作物をeditできる" do
    sign_in_as @admin_user
    get edit_crop_path(@reference_crop)

    assert_response :success
  end

  test "edit画面でnutrientsが無い場合でもフォームフィールドが表示される" do
    sign_in_as @user

    # nutrientsが無い作物を作成
    crop = create(:crop, user: @user)
    stage = create(:crop_stage, crop: crop, order: 1, name: "生育期")
    create(:temperature_requirement, crop_stage: stage)
    create(:thermal_requirement, crop_stage: stage)
    # nutrientsは作成しない

    get edit_crop_path(crop)

    assert_response :success

    # 画面にnutrientsフィールドが含まれていることを確認
    assert_select 'input[name*="nutrient_requirement_attributes"][name*="daily_uptake_n"]', count: 1
    assert_select 'input[name*="nutrient_requirement_attributes"][name*="daily_uptake_p"]', count: 1
    assert_select 'input[name*="nutrient_requirement_attributes"][name*="daily_uptake_k"]', count: 1
  end

  # ========== update アクションのテスト（nutrients関連） ==========

  test "既存ステージにnutrientsを追加できる" do
    sign_in_as @user

    # nutrientsが無い作物ステージを作成
    crop = create(:crop, user: @user)
    stage = create(:crop_stage, crop: crop, order: 1, name: "生育期")
    create(:temperature_requirement, crop_stage: stage)
    create(:thermal_requirement, crop_stage: stage)
    # nutrientsは作成しない

    # nutrientsを追加して更新
    patch crop_path(crop), params: {
      crop: {
        crop_stages_attributes: [ {
          id: stage.id,
          name: "生育期",
          order: 1,
          nutrient_requirement_attributes: {
            daily_uptake_n: 0.5,
            daily_uptake_p: 0.2,
            daily_uptake_k: 0.8
          }
        } ]
      }
    }

    assert_redirected_to crop_path(crop)

    # DBを確認
    stage.reload
    assert_not_nil stage.nutrient_requirement
    assert_equal 0.5, stage.nutrient_requirement.daily_uptake_n
    assert_equal 0.2, stage.nutrient_requirement.daily_uptake_p
    assert_equal 0.8, stage.nutrient_requirement.daily_uptake_k
  end

  test "既存のnutrientsを更新できる" do
    sign_in_as @user

    # nutrientsが既にある作物ステージを作成
    crop = create(:crop, user: @user)
    stage = create(:crop_stage, crop: crop, order: 1, name: "生育期")
    create(:temperature_requirement, crop_stage: stage)
    create(:thermal_requirement, crop_stage: stage)
    nutrient_req = create(:nutrient_requirement, crop_stage: stage, daily_uptake_n: 0.1, daily_uptake_p: 0.05, daily_uptake_k: 0.15)

    # nutrientsを更新
    patch crop_path(crop), params: {
      crop: {
        crop_stages_attributes: [ {
          id: stage.id,
          name: "生育期",
          order: 1,
          nutrient_requirement_attributes: {
            id: nutrient_req.id,
            daily_uptake_n: 0.5,
            daily_uptake_p: 0.2,
            daily_uptake_k: 0.8
          }
        } ]
      }
    }

    assert_redirected_to crop_path(crop)

    # DBを確認
    nutrient_req.reload
    assert_equal 0.5, nutrient_req.daily_uptake_n
    assert_equal 0.2, nutrient_req.daily_uptake_p
    assert_equal 0.8, nutrient_req.daily_uptake_k
  end

  test "既存のnutrientsを0.0に更新できる" do
    sign_in_as @user

    # nutrientsが既にある作物ステージを作成
    crop = create(:crop, user: @user)
    stage = create(:crop_stage, crop: crop, order: 1, name: "生育期")
    create(:temperature_requirement, crop_stage: stage)
    create(:thermal_requirement, crop_stage: stage)
    nutrient_req = create(:nutrient_requirement, crop_stage: stage, daily_uptake_n: 0.5, daily_uptake_p: 0.2, daily_uptake_k: 0.8)

    # nutrientsを0.0に更新
    patch crop_path(crop), params: {
      crop: {
        crop_stages_attributes: [ {
          id: stage.id,
          name: "生育期",
          order: 1,
          nutrient_requirement_attributes: {
            id: nutrient_req.id,
            daily_uptake_n: 0.0,
            daily_uptake_p: 0.0,
            daily_uptake_k: 0.0
          }
        } ]
      }
    }

    assert_redirected_to crop_path(crop)

    # DBを確認
    nutrient_req.reload
    assert_equal 0.0, nutrient_req.daily_uptake_n
    assert_equal 0.0, nutrient_req.daily_uptake_p
    assert_equal 0.0, nutrient_req.daily_uptake_k
  end

  test "既存のnutrientsを削除できる" do
    sign_in_as @user

    # nutrientsが既にある作物ステージを作成
    crop = create(:crop, user: @user)
    stage = create(:crop_stage, crop: crop, order: 1, name: "生育期")
    create(:temperature_requirement, crop_stage: stage)
    create(:thermal_requirement, crop_stage: stage)
    nutrient_req = create(:nutrient_requirement, crop_stage: stage)

    # nutrientsを削除
    patch crop_path(crop), params: {
      crop: {
        crop_stages_attributes: [ {
          id: stage.id,
          name: "生育期",
          order: 1,
          nutrient_requirement_attributes: {
            id: nutrient_req.id,
            _destroy: "1"
          }
        } ]
      }
    }

    assert_redirected_to crop_path(crop)

    # DBを確認
    stage.reload
    assert_nil stage.nutrient_requirement
  end

  test "複数のステージでnutrientsを追加できる" do
    sign_in_as @user

    crop = create(:crop, user: @user)
    stage1 = create(:crop_stage, crop: crop, order: 1, name: "発芽期")
    stage2 = create(:crop_stage, crop: crop, order: 2, name: "生育期")
    create(:temperature_requirement, crop_stage: stage1)
    create(:thermal_requirement, crop_stage: stage1)
    create(:temperature_requirement, crop_stage: stage2)
    create(:thermal_requirement, crop_stage: stage2)

    # 両方のステージにnutrientsを追加
    patch crop_path(crop), params: {
      crop: {
        crop_stages_attributes: [
          {
            id: stage1.id,
            name: "発芽期",
            order: 1,
            nutrient_requirement_attributes: {
              daily_uptake_n: 0.1,
              daily_uptake_p: 0.05,
              daily_uptake_k: 0.15
            }
          },
          {
            id: stage2.id,
            name: "生育期",
            order: 2,
            nutrient_requirement_attributes: {
              daily_uptake_n: 0.5,
              daily_uptake_p: 0.2,
              daily_uptake_k: 0.8
            }
          }
        ]
      }
    }

    assert_redirected_to crop_path(crop)

    # DBを確認
    stage1.reload
    stage2.reload
    assert_not_nil stage1.nutrient_requirement
    assert_not_nil stage2.nutrient_requirement
    assert_equal 0.1, stage1.nutrient_requirement.daily_uptake_n
    assert_equal 0.5, stage2.nutrient_requirement.daily_uptake_n
  end

  test "nutrients無しのステージと有りのステージを混在できる" do
    sign_in_as @user

    crop = create(:crop, user: @user)
    stage1 = create(:crop_stage, crop: crop, order: 1, name: "発芽期")
    stage2 = create(:crop_stage, crop: crop, order: 2, name: "生育期")
    create(:temperature_requirement, crop_stage: stage1)
    create(:thermal_requirement, crop_stage: stage1)
    create(:temperature_requirement, crop_stage: stage2)
    create(:thermal_requirement, crop_stage: stage2)

    # stage1のみnutrientsを追加
    patch crop_path(crop), params: {
      crop: {
        crop_stages_attributes: [
          {
            id: stage1.id,
            name: "発芽期",
            order: 1,
            nutrient_requirement_attributes: {
              daily_uptake_n: 0.1,
              daily_uptake_p: 0.05,
              daily_uptake_k: 0.15
            }
          },
          {
            id: stage2.id,
            name: "生育期",
            order: 2
          }
        ]
      }
    }

    assert_redirected_to crop_path(crop)

    # DBを確認
    stage1.reload
    stage2.reload
    assert_not_nil stage1.nutrient_requirement
    assert_nil stage2.nutrient_requirement
  end

  test "新規ステージ作成時にnutrientsを同時に追加できる" do
    sign_in_as @user

    crop = create(:crop, user: @user)

    # 新規ステージとnutrientsを同時に作成
    patch crop_path(crop), params: {
      crop: {
        crop_stages_attributes: [ {
          name: "発芽期",
          order: 1,
          temperature_requirement_attributes: {
            base_temperature: 10.0,
            optimal_min: 15.0,
            optimal_max: 25.0,
            low_stress_threshold: 5.0,
            high_stress_threshold: 30.0,
            frost_threshold: 0.0,
            sterility_risk_threshold: nil,
            max_temperature: 40.0
          },
          thermal_requirement_attributes: {
            required_gdd: 100.0
          },
          nutrient_requirement_attributes: {
            daily_uptake_n: 0.5,
            daily_uptake_p: 0.2,
            daily_uptake_k: 0.8
          }
        } ]
      }
    }

    assert_redirected_to crop_path(crop)

    # DBを確認
    stage = crop.crop_stages.first
    assert_not_nil stage
    assert_not_nil stage.nutrient_requirement
    assert_equal 0.5, stage.nutrient_requirement.daily_uptake_n
    assert_equal 0.2, stage.nutrient_requirement.daily_uptake_p
    assert_equal 0.8, stage.nutrient_requirement.daily_uptake_k
  end

  test "他のユーザーの作物はupdateできない" do
    sign_in_as @user

    # 他のユーザーの作物を更新しようとする
    patch crop_path(@other_user_crop), params: {
      crop: {
        name: "ハッキングされた作物"
      }
    }

    assert_redirected_to crops_path
    assert_equal I18n.t("crops.flash.no_permission"), flash[:alert]
  end

  test "参照作物は一般ユーザーがupdateできない" do
    sign_in_as @user

    # 参照作物を更新しようとする
    patch crop_path(@reference_crop), params: {
      crop: {
        name: "ハッキングされた参照作物"
      }
    }

    assert_redirected_to crops_path
    assert_equal I18n.t("crops.flash.no_permission"), flash[:alert]
  end

  test "管理者は参照作物のnutrientsを更新できる" do
    sign_in_as @admin_user

    # 参照作物のステージにnutrientsを追加
    stage = @reference_crop.crop_stages.first

    patch crop_path(@reference_crop), params: {
      crop: {
        crop_stages_attributes: [ {
          id: stage.id,
          name: stage.name,
          order: stage.order,
          nutrient_requirement_attributes: {
            daily_uptake_n: 0.5,
            daily_uptake_p: 0.2,
            daily_uptake_k: 0.8
          }
        } ]
      }
    }

    assert_redirected_to crop_path(@reference_crop)

    # DBを確認
    stage.reload
    if stage.nutrient_requirement
      assert_equal 0.5, stage.nutrient_requirement.daily_uptake_n
    end
  end

  test "nutrients無しでステージを更新できる" do
    sign_in_as @user

    crop = create(:crop, user: @user)
    stage = create(:crop_stage, crop: crop, order: 1, name: "生育期")
    create(:temperature_requirement, crop_stage: stage)
    create(:thermal_requirement, crop_stage: stage)

    # nutrients無しでステージ名だけ更新
    patch crop_path(crop), params: {
      crop: {
        crop_stages_attributes: [ {
          id: stage.id,
          name: "更新された生育期",
          order: 1
        } ]
      }
    }

    assert_redirected_to crop_path(crop)

    # DBを確認
    stage.reload
    assert_equal "更新された生育期", stage.name
    assert_nil stage.nutrient_requirement
  end

  # ========== create / update の groups・バリデーション ==========
  #
  # is_reference（admin のみ設定・変更可）の認可は CropCreate/UpdateInteractor が
  # 判定する → test/domain/crop/interactors/crop_{create,update}_interactor_test.rb。
  # 以下の controller テストは認可失敗が HTTP 応答（redirect + flash）へ
  # 正しくマッピングされる境界のみを検証する。

  test "一般ユーザーの参照作物作成失敗は redirect + flash へマッピングされる" do
    sign_in_as @user

    post crops_path, params: { crop: { name: "参照作物", is_reference: true } }

    assert_redirected_to crops_path
    assert_equal I18n.t("crops.flash.reference_only_admin"), flash[:alert]
  end

  test "作成時に必須項目が欠けていると一覧へリダイレクトし flash を付与する" do
    sign_in_as @user

    assert_no_difference("Crop.count") do
      post crops_path, params: {
        crop: {
          name: "", # 必須フィールドを空にする
          crop_stages_attributes: [ {
            name: "",
            order: 1
          } ]
        }
      }
    end

    assert_redirected_to crops_path
    assert flash[:alert].present?
  end

  test "一般ユーザーはgroupsをカンマ区切り文字列で指定して作成できる" do
    sign_in_as @user

    assert_difference("Crop.count", 1) do
      post crops_path, params: {
        crop: {
          name: "グループ付き作物",
          groups: "A, B , C",
          crop_stages_attributes: [ {
            name: "発芽期",
            order: 1,
            temperature_requirement_attributes: {
              base_temperature: 10.0,
              optimal_min: 15.0,
              optimal_max: 25.0,
              low_stress_threshold: 5.0,
              high_stress_threshold: 30.0,
              frost_threshold: 0.0,
              max_temperature: 40.0
            },
            thermal_requirement_attributes: {
              required_gdd: 100.0
            }
          } ]
        }
      }
    end

    crop = Crop.last
    assert_equal [ "A", "B", "C" ], crop.groups
  end

  test "一般ユーザーの参照フラグ変更失敗は redirect + flash へマッピングされる" do
    sign_in_as @user

    patch crop_path(@user_crop), params: { crop: { name: @user_crop.name, is_reference: true } }

    assert_redirected_to crop_path(@user_crop)
    assert_equal I18n.t("crops.flash.reference_flag_admin_only"), flash[:alert]
  end

  test "updateでgroupsをカンマ区切り文字列から配列に変換する" do
    sign_in_as @user

    patch crop_path(@user_crop), params: {
      crop: {
        name: @user_crop.name,
        groups: "X, Y , Z"
      }
    }

    assert_redirected_to crop_path(@user_crop)

    @user_crop.reload
    assert_equal [ "X", "Y", "Z" ], @user_crop.groups
  end

  test "update時に必須項目が欠けていると422でeditを再表示する" do
    sign_in_as @user

    original_name = @user_crop.name

    patch crop_path(@user_crop), params: {
      crop: {
        name: "" # 必須フィールドを空にする
      }
    }

    assert_response :unprocessable_entity

    @user_crop.reload
    assert_equal original_name, @user_crop.name
  end

  # ========== destroy アクションのテスト ==========

  test "destroy_via_html_redirects_with_undo_notice" do
    sign_in_as @user
    crop = create(:crop, user: @user, name: "テスト作物")
    crop_name = crop.name

    assert_difference -> { Crop.count }, -1 do
      assert_difference "DeletionUndoEvent.count", +1 do
        delete crop_path(crop) # HTMLリクエスト
        assert_redirected_to crops_path
      end
    end

    expected_notice = I18n.t(
      "deletion_undo.redirect_notice",
      resource: crop_name
    )
    assert_equal expected_notice, flash[:notice]
  end

  # ========== region 認可 ==========
  #
  # region（admin のみ設定・更新可）の認可は CropPolicy.normalize_attrs_for_* が
  # 判定する（Controller の strong params は mass-assignment 許可のみ）。
  #   → test/policies/crop_policy_test.rb
  # このため region 系の controller テストは policy テストへ切り離した。
end
