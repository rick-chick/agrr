# frozen_string_literal: true

module Domain
  module ContactMessages
    module Gateways
      # Abstract Gateway interface for ContactMessage persistence.
      # Implementations must implement :find_by_id and :create.
      class ContactMessageGateway
        def find_by_id(_id)
          raise NotImplementedError
        end

        # create_dto: Domain::ContactMessages::Dtos::CreateContactMessageInput
        def create(_create_dto)
          raise NotImplementedError
        end
      end
    end
  end
end
