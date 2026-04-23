# frozen_string_literal: true

module Domain
  module Pesticide
    module Gateways
      class PesticideGateway
        class << self
          def default
            @default ||= Adapters::Pesticide::Gateways::PesticideActiveRecordGateway.new
          end

          attr_writer :default

          def default_reset!
            @default = nil
          end
        end

        def list
          raise NotImplementedError, "Subclasses must implement list"
        end

        def find_by_id(pesticide_id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        def create(create_input_dto)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def update(pesticide_id, update_input_dto)
          raise NotImplementedError, "Subclasses must implement update"
        end

        def destroy(pesticide_id)
          raise NotImplementedError, "Subclasses must implement destroy"
        end

        def visible_records(user)
          raise NotImplementedError, "Subclasses must implement visible_records"
        end

        def selectable_records(user)
          raise NotImplementedError, "Subclasses must implement selectable_records"
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

        def list_from_relation(relation)
          raise NotImplementedError, "Subclasses must implement list_from_relation"
        end
      end
    end
  end
end
