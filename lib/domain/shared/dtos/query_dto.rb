# frozen_string_literal: true

module Domain
  module Shared
    module Dtos
      # Gatewayのクエリパラメータを抽象化したDTO
      # ActiveRecord::Relationの代わりに使用し、Rails非依存を維持
      class QueryDto
        attr_reader :filters, :sort, :pagination, :includes

        def initialize(filters: {}, sort: {}, pagination: {}, includes: [])
          @filters = filters || {}
          @sort = sort || {}
          @pagination = pagination || {}
          @includes = includes || []
        end

        def self.all
          new
        end

        def self.where(conditions = {})
          new(filters: conditions)
        end

        def self.order(sort_options = {})
          new(sort: sort_options)
        end

        def self.limit(limit_value)
          new(pagination: { limit: limit_value })
        end

        def self.offset(offset_value)
          new(pagination: { offset: offset_value })
        end

        def self.includes(*associations)
          new(includes: associations.flatten)
        end

        def merge(other_query)
          return self unless other_query.is_a?(QueryDto)

          merged_filters = filters.merge(other_query.filters)
          merged_sort = sort.merge(other_query.sort)
          merged_pagination = pagination.merge(other_query.pagination)
          merged_includes = (includes + other_query.includes).uniq

          self.class.new(
            filters: merged_filters,
            sort: merged_sort,
            pagination: merged_pagination,
            includes: merged_includes
          )
        end

        def present?
          Domain::Shared::ValidationHelpers.present?(filters) ||
          Domain::Shared::ValidationHelpers.present?(sort) ||
          Domain::Shared::ValidationHelpers.present?(pagination) ||
          Domain::Shared::ValidationHelpers.present?(includes)
        end
      end
    end
  end
end