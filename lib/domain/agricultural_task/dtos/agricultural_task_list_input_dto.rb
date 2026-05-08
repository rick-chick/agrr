# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Dtos
      class AgriculturalTaskListInputDto
        attr_reader :is_admin, :filter, :query

        def initialize(is_admin: false, filter: nil, query: nil)
          @is_admin = is_admin
          @filter = self.class.send(:normalize_list_filter, is_admin: is_admin, raw_filter: filter)
          @query = query
        end

        def self.from_hash(hash)
          new(
            is_admin: hash[:is_admin] || false,
            filter: hash[:filter],
            query: hash[:query]
          )
        end

        def self.normalize_list_filter(is_admin:, raw_filter:)
          allowed_filters = %w[user reference all]
          filter = raw_filter.to_s.presence
          return filter if is_admin && allowed_filters.include?(filter)

          is_admin ? "all" : "user"
        end
        private_class_method :normalize_list_filter
      end
    end
  end
end
