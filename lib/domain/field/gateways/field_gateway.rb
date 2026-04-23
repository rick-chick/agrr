# frozen_string_literal: true

module Domain
  module Field
    module Gateways
      class FieldGateway
        class << self
          def default
            @default ||= Adapters::Field::Gateways::FieldActiveRecordGateway.new
          end

          attr_writer :default

          def default_reset!
            @default = nil
          end
        end

        def list_by_farm(farm_id, user_id)
          raise NotImplementedError, "Subclasses must implement list_by_farm"
        end

        def find_by_id_and_user(field_id, user_id)
          raise NotImplementedError, "Subclasses must implement find_by_id_and_user"
        end

        def create(create_input_dto, farm_id, user_id)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def update(field_id, update_input_dto, user_id)
          raise NotImplementedError, "Subclasses must implement update"
        end

        def destroy(field_id, user_id)
          raise NotImplementedError, "Subclasses must implement destroy"
        end

        # Presenter 等で AR を再取得するための生 lookup（認可なし）
        def find_model(id)
          raise NotImplementedError, "Subclasses must implement find_model"
        end
      end
    end
  end
end
