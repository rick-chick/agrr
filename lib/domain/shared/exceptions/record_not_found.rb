# frozen_string_literal: true

module Domain
  module Shared
    module Exceptions
      # ActiveRecord::RecordNotFound の代わりに Gateway / Adapter で翻訳して投げる。
      class RecordNotFound < StandardError
      end
    end
  end
end
