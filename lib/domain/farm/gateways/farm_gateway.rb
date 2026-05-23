# frozen_string_literal: true

module Domain
  module Farm
    module Gateways
      class FarmGateway
        def list_user_owned_farms(user_id:)
          raise NotImplementedError, "Subclasses must implement list_user_owned_farms"
        end

        def list_user_and_reference_farms(user_id:)
          raise NotImplementedError, "Subclasses must implement list_user_and_reference_farms"
        end

        def list_reference_farms
          raise NotImplementedError, "Subclasses must implement list_reference_farms"
        end

        def list_user_owned_farm_rows(user_id:)
          raise NotImplementedError, "Subclasses must implement list_user_owned_farm_rows"
        end

        def list_user_and_reference_farm_rows(user_id:)
          raise NotImplementedError, "Subclasses must implement list_user_and_reference_farm_rows"
        end

        def list_reference_farm_rows
          raise NotImplementedError, "Subclasses must implement list_reference_farm_rows"
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

        def delete(farm_id, toast_message:)
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

        # @param access_filter [Domain::Shared::ReferenceRecordAccessFilter] FarmPolicy.record_access_filter(user)
        def find_authorized_for_view(user, id, access_filter:)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_view"
        end

        def find_authorized_for_edit(user, id, access_filter:)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_edit"
        end

        def find_authorized_farm_loaded_bundle!(user, id, for_edit:, access_filter:)
          raise NotImplementedError, "Subclasses must implement find_authorized_farm_loaded_bundle!"
        end

        def create_for_user(user, attrs)
          raise NotImplementedError, "Subclasses must implement create_for_user"
        end

        def update_for_user(user, id, attrs, access_filter:)
          raise NotImplementedError, "Subclasses must implement update_for_user"
        end

        # 認可済み農場と圃場一覧を Entity/DTO で返す（Interactor 用）
        def detail_for_authorized_view(user, id, access_filter:)
          raise NotImplementedError, "Subclasses must implement detail_for_authorized_view"
        end

        # 認可・DeletionUndo スケジュールをアダプタ内で完結。Interactor に AR を渡さない。
        def soft_delete_with_undo(user:, farm_id:, auto_hide_after:, toast_message:, access_filter:)
          raise NotImplementedError, "Subclasses must implement soft_delete_with_undo"
        end

        # プライベート計画ウィザード「農場選択」HTML 用の農場選択肢のみ（PageDto は Assembler 側）
        # @return [Array<Domain::CultivationPlan::Dtos::PrivatePlanNewFarmChoice>]
        def private_plan_new_farm_choices(user:)
          raise NotImplementedError, "Subclasses must implement private_plan_new_farm_choices"
        end

        # 公開ウィザード等: 農場 id から region を解決（存在しなければ nil）
        def farm_region_for_wizard_lookup_by_id(farm_id)
          raise NotImplementedError, "Subclasses must implement farm_region_for_wizard_lookup_by_id"
        end

        # 農場天気参照: 所有農場のみ（Interactor が管理者なら別メソッドを呼ぶ）。
        # @return [Domain::Farm::Dtos::FarmWeatherDataAccessContext, nil]
        def farm_weather_data_access_context_for_owned_farm(user_id:, farm_id:)
          raise NotImplementedError, "Subclasses must implement farm_weather_data_access_context_for_owned_farm"
        end

        # 農場 id のみ（管理者ユースケースで Interactor からのみ呼ぶ）。
        # @return [Domain::Farm::Dtos::FarmWeatherDataAccessContext, nil]
        def farm_weather_data_access_context_for_admin_lookup(farm_id:)
          raise NotImplementedError, "Subclasses must implement farm_weather_data_access_context_for_admin_lookup"
        end

        # 作付計画表: ユーザー所有農場のみ、名前順（HTML 選択 UI）
        # @return [Array<Domain::Farm::Dtos::FarmIdName>]
        def planning_schedule_user_owned_farms(user:)
          raise NotImplementedError, "Subclasses must implement planning_schedule_user_owned_farms"
        end

        # 農場マスタ新規フォーム用スナップショット（永続化しない）
        # @return [Domain::Farm::Dtos::FarmMasterFormSnapshot]
        def blank_farm_master_form_snapshot_for_new!(user_id:)
          raise NotImplementedError, "Subclasses must implement blank_farm_master_form_snapshot_for_new!"
        end
      end
    end
  end
end
