# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Dtos
      class AgriculturalTaskListInputDto
        attr_reader :is_admin, :filter, :query

        def initialize(is_admin: false, filter: nil, query: nil)
          @is_admin = is_admin
          @filter = filter
          @query = query
        end

        def self.from_hash(hash)
          new(
            is_admin: hash[:is_admin] || false,
            filter: hash[:filter],
            query: hash[:query]
          )
        end
      end
    end
  end
end