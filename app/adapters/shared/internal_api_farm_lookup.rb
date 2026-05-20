# frozen_string_literal: true

module Adapters
  module Shared
    # 内部API等で Farm.find を結果ハッシュに正規化し、コントローラの rescue RecordNotFound を減らす。
    module InternalApiFarmLookup
      module_function

      # @return [Hash] { kind: :ok, farm: Farm } または { kind: :not_found }
      def find_farm(farm_id_param)
        id = farm_id_param.to_s.presence&.to_i
        unless id && id.positive?
          return { kind: :not_found }
        end

        { kind: :ok, farm: ::Farm.find(id) }
      rescue ActiveRecord::RecordNotFound
        { kind: :not_found }
      end
    end
  end
end
