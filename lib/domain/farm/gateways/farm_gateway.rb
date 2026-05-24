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

        def count_user_owned_non_reference_farms(user_id:)
          raise NotImplementedError, "Subclasses must implement count_user_owned_non_reference_farms"
        end

        def create_for_user(user, attrs)
          raise NotImplementedError, "Subclasses must implement create_for_user"
        end

        def update_for_user(user, id, attrs)
          raise NotImplementedError, "Subclasses must implement update_for_user"
        end

        # 農場と圃場一覧を Entity/DTO で返す（Interactor 用。認可は Interactor 側）
        def farm_detail_with_fields(id)
          raise NotImplementedError, "Subclasses must implement farm_detail_with_fields"
        end

        # @return [Domain::Farm::Dtos::FarmDeleteUsage]
        def find_delete_usage(farm_id)
          raise NotImplementedError, "Subclasses must implement find_delete_usage"
        end

        def soft_delete_with_undo(user:, farm_id:, auto_hide_after:, toast_message:)
          raise NotImplementedError, "Subclasses must implement soft_delete_with_undo"
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
      end
    end
  end
end
