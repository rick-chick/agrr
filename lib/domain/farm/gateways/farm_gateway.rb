# frozen_string_literal: true

module Domain
  module Farm
    module Gateways
      class FarmGateway
        class << self
          def default
            @default ||= Adapters::Farm::Gateways::FarmActiveRecordGateway.new
          end

          attr_writer :default

          def default_reset!
            @default = nil
          end
        end

        def list(input_dto)
          raise NotImplementedError, "Subclasses must implement list"
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

        def destroy(farm_id)
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

        def visible_records(user)
          raise NotImplementedError, "Subclasses must implement visible_records"
        end

        def user_owned_records(user)
          raise NotImplementedError, "Subclasses must implement user_owned_records"
        end

        def reference_records(region: nil)
          raise NotImplementedError, "Subclasses must implement reference_records"
        end

        def find_authorized_for_view(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_view"
        end

        def find_authorized_for_edit(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_edit"
        end

        def find_model(id)
          raise NotImplementedError, "Subclasses must implement find_model"
        end

        def create_for_user(user, attrs)
          raise NotImplementedError, "Subclasses must implement create_for_user"
        end

        def update_for_user(user, id, attrs)
          raise NotImplementedError, "Subclasses must implement update_for_user"
        end
      end
    end
  end
end
