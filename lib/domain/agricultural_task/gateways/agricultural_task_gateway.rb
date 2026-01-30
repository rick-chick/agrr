# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Gateways
      class AgriculturalTaskGateway
        def list
          raise NotImplementedError, "Subclasses must implement list"
        end

        def find_by_id(task_id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        def create(create_input_dto)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def update(task_id, update_input_dto)
          raise NotImplementedError, "Subclasses must implement update"
        end

        def destroy(task_id)
          raise NotImplementedError, "Subclasses must implement destroy"
        end
      end
    end
  end
end
