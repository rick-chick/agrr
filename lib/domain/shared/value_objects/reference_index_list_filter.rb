# frozen_string_literal: true

module Domain
  module Shared
    module ValueObjects
      # 参照マスタ一覧の永続化スコープ（Interactor / Policy が組み立て、Gateway は mode を SQL に写すだけ）。
      class ReferenceIndexListFilter
        MODES = %i[reference_or_owned owned_non_reference].freeze

        attr_reader :mode, :user_id

        def initialize(mode:, user_id:)
          raise ArgumentError, "invalid mode: #{mode.inspect}" unless MODES.include?(mode)

          @mode = mode
          @user_id = user_id
        end

        def ==(other)
          other.is_a?(ReferenceIndexListFilter) && other.mode == mode && other.user_id == user_id
        end

        alias eql? ==

        def hash
          [ mode, user_id ].hash
        end
      end
    end
  end
end
