# frozen_string_literal: true

module Domain
  module Shared
    module Exceptions
      # 外部参照などにより削除不可（ActiveRecord::InvalidForeignKey 等の代替）
      class AssociationInUse < StandardError
      end
    end
  end
end
