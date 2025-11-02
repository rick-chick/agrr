# frozen_string_literal: true

require 'test_helper'

module Crops
  # 肥料プロファイルの施用計画追加・削除・更新パターンの統合テスト
  class CropFertilizeProfilesApplicationPatternsTest < ActionDispatch::IntegrationTest
    setup do
      @user = create(:user)
      sign_in_as @user
      @crop = create(:crop, :tomato, user: @user)
    end

    # パターン1: 新規作成 → 更新 → 編集 → 追加 → 更新
    test 'pattern1: create -> update -> edit -> add application -> update' do
      # 1. 新規作成（プロファイルなし）
      get new_crop_crop_fertilize_profile_path(@crop)
      assert_response :success

      # プロファイルを新規作成（アプリケーションなし）
      assert_difference('CropFertilizeProfile.count', 1) do
        assert_difference('CropFertilizeApplication.count', 0) do
          post crop_crop_fertilize_profiles_path(@crop), params: {
            crop_fertilize_profile: {
              confidence: 0.7,
              notes: 'Initial profile'
            }
          }
        end
      end

      assert_redirected_to crop_path(@crop)
      profile = @crop.reload.crop_fertilize_profile
      assert_not_nil profile

      # 2. 更新（アプリケーション追加なし）
      patch crop_crop_fertilize_profile_path(@crop, profile), params: {
        crop_fertilize_profile: {
          confidence: 0.8,
          notes: 'First update'
        }
      }

      assert_redirected_to crop_path(@crop)
      profile.reload
      assert_equal 0.8, profile.confidence
      assert_equal 'First update', profile.notes
      assert_equal 0, profile.crop_fertilize_applications.count

      # 3. 編集画面を開く
      get edit_crop_crop_fertilize_profile_path(@crop, profile)
      assert_response :success

      # 4. 編集画面で施用計画を追加して更新
      assert_difference('CropFertilizeApplication.count', 1) do
        patch crop_crop_fertilize_profile_path(@crop, profile), params: {
          crop_fertilize_profile: {
            confidence: 0.8,
            notes: 'First update',
            crop_fertilize_applications_attributes: [
              {
                application_type: 'basal',
                count: 1,
                schedule_hint: 'pre-plant',
                per_application_n: 10.0,
                per_application_p: 5.0,
                per_application_k: 8.0
              }
            ]
          }
        }
      end

      assert_redirected_to crop_path(@crop)
      profile.reload
      assert_equal 1, profile.crop_fertilize_applications.count
      app = profile.crop_fertilize_applications.first
      assert_equal 'basal', app.application_type
      assert_equal 10.0, app.per_application_n
      assert_equal 10.0, profile.total_n

      # 5. 再度更新（アプリケーションの値を変更）
      app_id = app.id
      assert_no_difference('CropFertilizeApplication.count') do
        patch crop_crop_fertilize_profile_path(@crop, profile), params: {
          crop_fertilize_profile: {
            confidence: 0.85,
            notes: 'Second update',
            crop_fertilize_applications_attributes: [
              {
                id: app_id,
                application_type: 'basal',
                count: 2,
                schedule_hint: 'pre-plant',
                per_application_n: 12.0,
                per_application_p: 6.0,
                per_application_k: 10.0
              }
            ]
          }
        }
      end

      assert_redirected_to crop_path(@crop)
      profile.reload
      app.reload
      assert_equal 2, app.count
      assert_equal 12.0, app.per_application_n
      assert_equal 24.0, profile.total_n # 12.0 * 2
    end

    # パターン2: 新規作成 → 更新 → 編集 → 追加 → 削除 → 更新
    test 'pattern2: create -> update -> edit -> add application -> remove -> update' do
      # 1. 新規作成
      get new_crop_crop_fertilize_profile_path(@crop)
      assert_response :success

      assert_difference('CropFertilizeProfile.count', 1) do
        post crop_crop_fertilize_profiles_path(@crop), params: {
          crop_fertilize_profile: {
            confidence: 0.7,
            notes: 'Initial'
          }
        }
      end

      profile = @crop.reload.crop_fertilize_profile

      # 2. 更新
      patch crop_crop_fertilize_profile_path(@crop, profile), params: {
        crop_fertilize_profile: {
          confidence: 0.8
        }
      }

      # 3. 編集画面を開く
      get edit_crop_crop_fertilize_profile_path(@crop, profile)
      assert_response :success

      # 4. 施用計画を追加
      assert_difference('CropFertilizeApplication.count', 1) do
        patch crop_crop_fertilize_profile_path(@crop, profile), params: {
          crop_fertilize_profile: {
            confidence: 0.8,
            crop_fertilize_applications_attributes: [
              {
                application_type: 'basal',
                count: 1,
                per_application_n: 10.0,
                per_application_p: 5.0,
                per_application_k: 8.0
              }
            ]
          }
        }
      end

      profile.reload
      assert_equal 1, profile.crop_fertilize_applications.count
      app = profile.crop_fertilize_applications.first

      # 5. 編集画面で削除（_destroy=1を送信）
      assert_difference('CropFertilizeApplication.count', -1) do
        patch crop_crop_fertilize_profile_path(@crop, profile), params: {
          crop_fertilize_profile: {
            confidence: 0.8,
            crop_fertilize_applications_attributes: [
              {
                id: app.id,
                _destroy: '1'
              }
            ]
          }
        }
      end

      profile.reload
      assert_equal 0, profile.crop_fertilize_applications.count
      assert_equal 0.0, profile.total_n

      # 6. 再度更新（アプリケーションなし）
      patch crop_crop_fertilize_profile_path(@crop, profile), params: {
        crop_fertilize_profile: {
          confidence: 0.9,
          notes: 'After removal'
        }
      }

      profile.reload
      assert_equal 0.9, profile.confidence
      assert_equal 'After removal', profile.notes
      assert_equal 0, profile.crop_fertilize_applications.count
    end

    # パターン3: 新規作成 → 更新 → 編集 → 追加 → 削除 → 追加 → 更新
    test 'pattern3: create -> update -> edit -> add -> remove -> add -> update' do
      # 1. 新規作成
      assert_difference('CropFertilizeProfile.count', 1) do
        post crop_crop_fertilize_profiles_path(@crop), params: {
          crop_fertilize_profile: {
            confidence: 0.7
          }
        }
      end

      profile = @crop.reload.crop_fertilize_profile

      # 2. 更新
      patch crop_crop_fertilize_profile_path(@crop, profile), params: {
        crop_fertilize_profile: {
          confidence: 0.8
        }
      }

      # 3. 編集画面を開く
      get edit_crop_crop_fertilize_profile_path(@crop, profile)
      assert_response :success

      # 4. 1つ目の施用計画を追加
      assert_difference('CropFertilizeApplication.count', 1) do
        patch crop_crop_fertilize_profile_path(@crop, profile), params: {
          crop_fertilize_profile: {
            confidence: 0.8,
            crop_fertilize_applications_attributes: [
              {
                application_type: 'basal',
                count: 1,
                per_application_n: 10.0,
                per_application_p: 5.0,
                per_application_k: 8.0
              }
            ]
          }
        }
      end

      profile.reload
      app1 = profile.crop_fertilize_applications.first
      assert_equal 1, profile.crop_fertilize_applications.count

      # 5. 1つ目を削除
      assert_difference('CropFertilizeApplication.count', -1) do
        patch crop_crop_fertilize_profile_path(@crop, profile), params: {
          crop_fertilize_profile: {
            confidence: 0.8,
            crop_fertilize_applications_attributes: [
              {
                id: app1.id,
                _destroy: '1'
              }
            ]
          }
        }
      end

      profile.reload
      assert_equal 0, profile.crop_fertilize_applications.count

      # 6. 新しい施用計画を追加
      assert_difference('CropFertilizeApplication.count', 1) do
        patch crop_crop_fertilize_profile_path(@crop, profile), params: {
          crop_fertilize_profile: {
            confidence: 0.8,
            crop_fertilize_applications_attributes: [
              {
                application_type: 'topdress',
                count: 2,
                schedule_hint: 'fruiting',
                per_application_n: 15.0,
                per_application_p: 7.0,
                per_application_k: 12.0
              }
            ]
          }
        }
      end

      profile.reload
      app2 = profile.crop_fertilize_applications.first
      assert_equal 1, profile.crop_fertilize_applications.count
      assert_equal 'topdress', app2.application_type
      assert_equal 30.0, profile.total_n # 15.0 * 2

      # 7. 再度更新（アプリケーションの値を変更）
      assert_no_difference('CropFertilizeApplication.count') do
        patch crop_crop_fertilize_profile_path(@crop, profile), params: {
          crop_fertilize_profile: {
            confidence: 0.85,
            crop_fertilize_applications_attributes: [
              {
                id: app2.id,
                application_type: 'topdress',
                count: 3,
                schedule_hint: 'fruiting',
                per_application_n: 16.0,
                per_application_p: 8.0,
                per_application_k: 13.0
              }
            ]
          }
        }
      end

      profile.reload
      app2.reload
      assert_equal 3, app2.count
      assert_equal 16.0, app2.per_application_n
      assert_equal 48.0, profile.total_n # 16.0 * 3
    end

    # パターン4: 編集 → 詳細 → 追加 → 更新
    test 'pattern4: edit -> show -> add application -> update' do
      # 既存のプロファイルを作成
      profile = create(:crop_fertilize_profile, crop: @crop, confidence: 0.7)
      assert_equal 0, profile.crop_fertilize_applications.count

      # 1. 編集画面を開く
      get edit_crop_crop_fertilize_profile_path(@crop, profile)
      assert_response :success

      # 2. 詳細画面を開く（編集せずに戻る）
      get crop_crop_fertilize_profile_path(@crop, profile)
      assert_response :success
      assert_select '.no-stages', text: /まだ施用計画が登録されていません|No application plans registered yet/

      # 3. 再度編集画面で施用計画を追加
      get edit_crop_crop_fertilize_profile_path(@crop, profile)
      assert_response :success

      assert_difference('CropFertilizeApplication.count', 1) do
        patch crop_crop_fertilize_profile_path(@crop, profile), params: {
          crop_fertilize_profile: {
            confidence: 0.7,
            crop_fertilize_applications_attributes: [
              {
                application_type: 'basal',
                count: 1,
                per_application_n: 10.0,
                per_application_p: 5.0,
                per_application_k: 8.0
              }
            ]
          }
        }
      end

      profile.reload
      assert_equal 1, profile.crop_fertilize_applications.count

      # 4. 詳細画面を確認
      get crop_crop_fertilize_profile_path(@crop, profile)
      assert_response :success
      assert_select '.stage-item', count: 1
      assert_match /10.0/, response.body

      # 5. 再度更新（アプリケーションの値を変更）
      app = profile.crop_fertilize_applications.first
      patch crop_crop_fertilize_profile_path(@crop, profile), params: {
        crop_fertilize_profile: {
          confidence: 0.8,
          crop_fertilize_applications_attributes: [
            {
              id: app.id,
              application_type: 'basal',
              count: 2,
              per_application_n: 12.0,
              per_application_p: 6.0,
              per_application_k: 10.0
            }
          ]
        }
      }

      profile.reload
      app.reload
      assert_equal 2, app.count
      assert_equal 12.0, app.per_application_n
      assert_equal 24.0, profile.total_n
    end

    # パターン5: 複数の施用計画を一度に追加 → 一部削除 → 更新
    test 'pattern5: add multiple applications -> remove some -> update' do
      profile = create(:crop_fertilize_profile, crop: @crop)

      # 1. 複数の施用計画を一度に追加
      assert_difference('CropFertilizeApplication.count', 2) do
        patch crop_crop_fertilize_profile_path(@crop, profile), params: {
          crop_fertilize_profile: {
            confidence: profile.confidence,
            crop_fertilize_applications_attributes: [
              {
                application_type: 'basal',
                count: 1,
                per_application_n: 10.0,
                per_application_p: 5.0,
                per_application_k: 8.0
              },
              {
                application_type: 'topdress',
                count: 2,
                per_application_n: 12.0,
                per_application_p: 6.0,
                per_application_k: 10.0
              }
            ]
          }
        }
      end

      profile.reload
      assert_equal 2, profile.crop_fertilize_applications.count
      assert_equal 34.0, profile.total_n # 10.0 + 12.0*2

      apps = profile.crop_fertilize_applications.order(:application_type)
      basal_app = apps.find { |a| a.application_type == 'basal' }
      topdress_app = apps.find { |a| a.application_type == 'topdress' }

      # 2. 一部（basal）を削除
      assert_difference('CropFertilizeApplication.count', -1) do
        patch crop_crop_fertilize_profile_path(@crop, profile), params: {
          crop_fertilize_profile: {
            confidence: profile.confidence,
            crop_fertilize_applications_attributes: [
              {
                id: basal_app.id,
                _destroy: '1'
              },
              {
                id: topdress_app.id,
                application_type: 'topdress',
                count: 2,
                per_application_n: 12.0,
                per_application_p: 6.0,
                per_application_k: 10.0
              }
            ]
          }
        }
      end

      profile.reload
      assert_equal 1, profile.crop_fertilize_applications.count
      assert_equal 'topdress', profile.crop_fertilize_applications.first.application_type
      assert_equal 24.0, profile.total_n # 12.0 * 2

      # 3. 残りの施用計画を更新
      remaining_app = profile.crop_fertilize_applications.first
      assert_no_difference('CropFertilizeApplication.count') do
        patch crop_crop_fertilize_profile_path(@crop, profile), params: {
          crop_fertilize_profile: {
            confidence: 0.9,
            crop_fertilize_applications_attributes: [
              {
                id: remaining_app.id,
                application_type: 'topdress',
                count: 3,
                per_application_n: 15.0,
                per_application_p: 8.0,
                per_application_k: 12.0
              }
            ]
          }
        }
      end

      profile.reload
      remaining_app.reload
      assert_equal 3, remaining_app.count
      assert_equal 15.0, remaining_app.per_application_n
      assert_equal 45.0, profile.total_n # 15.0 * 3
    end

    # パターン6: 新規作成時に複数の施用計画を追加 → 更新で全て削除 → 再追加
    test 'pattern6: create with multiple applications -> remove all -> add again' do
      # 1. 新規作成時に複数の施用計画を追加
      assert_difference('CropFertilizeProfile.count', 1) do
        assert_difference('CropFertilizeApplication.count', 3) do
          post crop_crop_fertilize_profiles_path(@crop), params: {
            crop_fertilize_profile: {
              confidence: 0.7,
              crop_fertilize_applications_attributes: [
                {
                  application_type: 'basal',
                  count: 1,
                  per_application_n: 10.0
                },
                {
                  application_type: 'topdress',
                  count: 1,
                  per_application_n: 8.0
                },
                {
                  application_type: 'topdress',
                  count: 1,
                  per_application_n: 6.0
                }
              ]
            }
          }
        end
      end

      profile = @crop.reload.crop_fertilize_profile
      assert_equal 3, profile.crop_fertilize_applications.count
      assert_equal 24.0, profile.total_n # 10.0 + 8.0 + 6.0

      # 2. 全ての施用計画を削除
      apps = profile.crop_fertilize_applications.to_a
      app_ids = apps.map(&:id)

      assert_difference('CropFertilizeApplication.count', -3) do
        patch crop_crop_fertilize_profile_path(@crop, profile), params: {
          crop_fertilize_profile: {
            confidence: profile.confidence,
            crop_fertilize_applications_attributes: app_ids.map { |id| { id: id, _destroy: '1' } }
          }
        }
      end

      profile.reload
      assert_equal 0, profile.crop_fertilize_applications.count
      assert_equal 0.0, profile.total_n

      # 3. 再度施用計画を追加
      assert_difference('CropFertilizeApplication.count', 1) do
        patch crop_crop_fertilize_profile_path(@crop, profile), params: {
          crop_fertilize_profile: {
            confidence: 0.8,
            crop_fertilize_applications_attributes: [
              {
                application_type: 'basal',
                count: 1,
                per_application_n: 20.0,
                per_application_p: 10.0,
                per_application_k: 15.0
              }
            ]
          }
        }
      end

      profile.reload
      assert_equal 1, profile.crop_fertilize_applications.count
      assert_equal 20.0, profile.total_n
      assert_equal 0.8, profile.confidence
    end

    # パターン7: 既存の施用計画を更新しながら新しいものを追加
    test 'pattern7: update existing application and add new one simultaneously' do
      profile = create(:crop_fertilize_profile, crop: @crop)
      app = create(:crop_fertilize_application, :basal, crop_fertilize_profile: profile,
                   per_application_n: 10.0, per_application_p: 5.0, per_application_k: 8.0, count: 1)

      assert_equal 1, profile.crop_fertilize_applications.count

      # 既存の施用計画を更新しながら新しいものを追加
      assert_difference('CropFertilizeApplication.count', 1) do
        patch crop_crop_fertilize_profile_path(@crop, profile), params: {
          crop_fertilize_profile: {
            confidence: profile.confidence,
            crop_fertilize_applications_attributes: [
              {
                id: app.id,
                application_type: 'basal',
                count: 2,
                per_application_n: 15.0,
                per_application_p: 7.0,
                per_application_k: 10.0
              },
              {
                application_type: 'topdress',
                count: 1,
                per_application_n: 12.0,
                per_application_p: 6.0,
                per_application_k: 9.0
              }
            ]
          }
        }
      end

      profile.reload
      assert_equal 2, profile.crop_fertilize_applications.count
      app.reload
      assert_equal 2, app.count
      assert_equal 15.0, app.per_application_n
      assert_equal 42.0, profile.total_n # 15.0*2 + 12.0*1
    end

    # パターン8: 新規作成時と更新時で異なるインデックスを使った追加（JavaScript の動作をシミュレート）
    test 'pattern8: add applications with different indices as javascript does' do
      # 新規作成時: インデックス0から開始
      assert_difference('CropFertilizeProfile.count', 1) do
        assert_difference('CropFertilizeApplication.count', 1) do
          post crop_crop_fertilize_profiles_path(@crop), params: {
            crop_fertilize_profile: {
              confidence: 0.7,
              crop_fertilize_applications_attributes: [
                {
                  application_type: 'basal',
                  count: 1,
                  per_application_n: 10.0
                }
              ]
            }
          }
        end
      end

      profile = @crop.reload.crop_fertilize_profile
      app1 = profile.crop_fertilize_applications.first

      # 更新時: 既存のIDを使用し、新しいインデックスで追加（JavaScriptの動作）
      assert_difference('CropFertilizeApplication.count', 1) do
        patch crop_crop_fertilize_profile_path(@crop, profile), params: {
          crop_fertilize_profile: {
            confidence: 0.8,
            crop_fertilize_applications_attributes: [
              {
                id: app1.id,
                application_type: 'basal',
                count: 1,
                per_application_n: 10.0
              },
              {
                application_type: 'topdress',
                count: 2,
                per_application_n: 12.0
              }
            ]
          }
        }
      end

      profile.reload
      assert_equal 2, profile.crop_fertilize_applications.count
      assert_equal 34.0, profile.total_n # 10.0 + 12.0*2
    end

    # パターン9: 削除マークを付けた後にキャンセル（_destroyをfalseに戻す）
    test 'pattern9: mark for destroy then cancel (set _destroy back to false)' do
      profile = create(:crop_fertilize_profile, crop: @crop)
      app = create(:crop_fertilize_application, :basal, crop_fertilize_profile: profile,
                   per_application_n: 10.0, count: 1)

      # 削除マークを付ける
      patch crop_crop_fertilize_profile_path(@crop, profile), params: {
        crop_fertilize_profile: {
          confidence: profile.confidence,
          crop_fertilize_applications_attributes: [
            {
              id: app.id,
              _destroy: '1'
            }
          ]
        }
      }

      profile.reload
      assert_equal 0, profile.crop_fertilize_applications.count

      # 別の操作として、削除をキャンセル（これは実際には新しいアプリケーションを追加することになる）
      # 削除されたアプリケーションと同じ値で再作成
      assert_difference('CropFertilizeApplication.count', 1) do
        patch crop_crop_fertilize_profile_path(@crop, profile), params: {
          crop_fertilize_profile: {
            confidence: profile.confidence,
            crop_fertilize_applications_attributes: [
              {
                application_type: 'basal',
                count: 1,
                per_application_n: 10.0,
                per_application_p: 5.0,
                per_application_k: 8.0
              }
            ]
          }
        }
      end

      profile.reload
      assert_equal 1, profile.crop_fertilize_applications.count
      new_app = profile.crop_fertilize_applications.first
      assert_not_equal app.id, new_app.id # 新しいIDで作成されている
      assert_equal 10.0, new_app.per_application_n
    end

    # パターン10: バリデーションエラー後に再送信（アプリケーションが保持される）
    test 'pattern10: validation error then resubmit (applications are preserved)' do
      profile = create(:crop_fertilize_profile, crop: @crop)

      # 無効なデータ（confidence が nil）で送信 - バリデーションエラー
      assert_no_difference('CropFertilizeApplication.count') do
        patch crop_crop_fertilize_profile_path(@crop, profile), params: {
          crop_fertilize_profile: {
            confidence: nil,
            crop_fertilize_applications_attributes: [
              {
                application_type: 'basal',
                count: 1,
                per_application_n: 10.0
              }
            ]
          }
        }
      end

      assert_response :unprocessable_entity
      assert_select '.errors'

      # 正しいデータで再送信 - アプリケーションが追加される
      assert_difference('CropFertilizeApplication.count', 1) do
        patch crop_crop_fertilize_profile_path(@crop, profile), params: {
          crop_fertilize_profile: {
            confidence: 0.8,
            crop_fertilize_applications_attributes: [
              {
                application_type: 'basal',
                count: 1,
                per_application_n: 10.0,
                per_application_p: 5.0,
                per_application_k: 8.0
              }
            ]
          }
        }
      end

      profile.reload
      assert_equal 1, profile.crop_fertilize_applications.count
      assert_equal 10.0, profile.total_n
    end
  end
end

