# frozen_string_literal: true

module Domain
  module Farm
    module Gateways
      class FarmGateway
        def list(input_dto)
          raise NotImplementedError, "Subclasses must implement list"
        end

        # 農場一覧 HTML 用: 管理者のみ参照農場エンティティ一覧（非管理者は []）
        def reference_farms_for_admin_list(is_admin:)
          raise NotImplementedError, "Subclasses must implement reference_farms_for_admin_list"
        end

        def find_by_id(farm_id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        def create(create_input_dto)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def update(farm_id, update_input_dto)
          raise NotImplementedError, "Subclasses must implement update"
        end

        def destroy(farm_id, toast_message:)
          raise NotImplementedError, "Subclasses must implement destroy"
        end

        def mark_weather_data_failed(farm_id, error_msg)
          raise NotImplementedError
        end

        def increment_weather_data_progress(farm_id)
          raise NotImplementedError
        end

        def get_weather_data_progress(farm_id)
          raise NotImplementedError
        end

        def get_weather_data_fetched_years(farm_id)
          raise NotImplementedError
        end

        def get_weather_data_total_years(farm_id)
          raise NotImplementedError
        end

        def update_weather_location_id(farm_id, weather_location_id)
          raise NotImplementedError
        end

        def update_predicted_weather_data(farm_id, payload)
          raise NotImplementedError, "Subclasses must implement update_predicted_weather_data"
        end

        def user_owned_records(user)
          raise NotImplementedError, "Subclasses must implement user_owned_records"
        end

        def list_reference_farms_for_region(region)
          raise NotImplementedError, "Subclasses must implement list_reference_farms_for_region"
        end

        def find_authorized_for_view(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_view"
        end

        def find_authorized_for_edit(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_edit"
        end

        # HTML/Presenter 用: 認可後に1回の取得で AR を返す（Controller の二重 find を避ける）
        def find_authorized_model_for_view(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_model_for_view"
        end

        def find_authorized_model_for_edit(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_model_for_edit"
        end

        def find_authorized_farm_loaded_bundle!(user, id, for_edit:)
          raise NotImplementedError, "Subclasses must implement find_authorized_farm_loaded_bundle!"
        end

        def create_for_user(user, attrs)
          raise NotImplementedError, "Subclasses must implement create_for_user"
        end

        # HTML `farms#new` 用。`User` の `farms` に `build` した未保存 `Farm` を返す（AR はアダプタ内のみ）。
        # `user_id` はログイン済みユーザー。
        def build_blank_farm_for_master_form!(user_id:)
          raise NotImplementedError, "Subclasses must implement build_blank_farm_for_master_form!"
        end

        def update_for_user(user, id, attrs)
          raise NotImplementedError, "Subclasses must implement update_for_user"
        end

        # 認可済み農場と圃場一覧を Entity/DTO で返す（Interactor 用）
        def detail_for_authorized_view(user, id)
          raise NotImplementedError, "Subclasses must implement detail_for_authorized_view"
        end

        # 認可・DeletionUndo スケジュールをアダプタ内で完結。Interactor に AR を渡さない。
        def soft_destroy_with_undo(user:, farm_id:, auto_hide_after:, toast_message:)
          raise NotImplementedError, "Subclasses must implement soft_destroy_with_undo"
        end

        # 農場一覧カード行: メイン一覧＋参照農場行を一度に組み立てる（list + 行DTO 変換の二重クエリを避ける）
        def farm_list_rows_bundle(input_dto)
          raise NotImplementedError, "Subclasses must implement farm_list_rows_bundle"
        end

        # プライベート計画ウィザード「農場選択」HTML 用の農場選択肢のみ（PageDto は Assembler 側）
        # @return [Array<Domain::CultivationPlan::Dtos::PrivatePlanNewFarmChoiceDto>]
        def private_plan_new_farm_choices(user:)
          raise NotImplementedError, "Subclasses must implement private_plan_new_farm_choices"
        end

        # 公開ウィザード等: 農場 id から region を解決（存在しなければ nil）
        def farm_region_for_wizard_lookup_by_id(farm_id)
          raise NotImplementedError, "Subclasses must implement farm_region_for_wizard_lookup_by_id"
        end

        # 農場天気参照: 所有農場のみ（Interactor が管理者なら別メソッドを呼ぶ）。
        # @return [Domain::Farm::Dtos::FarmWeatherDataAccessContextDto, nil]
        def farm_weather_data_access_context_for_owned_farm(user_id:, farm_id:)
          raise NotImplementedError, "Subclasses must implement farm_weather_data_access_context_for_owned_farm"
        end

        # 農場 id のみ（管理者ユースケースで Interactor からのみ呼ぶ）。
        # @return [Domain::Farm::Dtos::FarmWeatherDataAccessContextDto, nil]
        def farm_weather_data_access_context_for_admin_lookup(farm_id:)
          raise NotImplementedError, "Subclasses must implement farm_weather_data_access_context_for_admin_lookup"
        end

        # 作付計画表: ユーザー所有農場のみ、名前順（HTML 選択 UI）
        # @return [Array<Domain::Farm::Dtos::FarmIdNameDto>]
        def planning_schedule_user_owned_farms(user:)
          raise NotImplementedError, "Subclasses must implement planning_schedule_user_owned_farms"
        end
      end
    end
  end
end
