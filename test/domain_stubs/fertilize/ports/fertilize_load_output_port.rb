# frozen_string_literal: true

# テスト用スタブ: lib/domain に FertilizeLoadOutputPort が未定義のため。
# 本番では Domain::Fertilize::Ports::FertilizeLoadOutputPort を定義すること。
module Domain
  module Fertilize
    module Ports
      class FertilizeLoadOutputPort
        def on_success(_bundle); raise NotImplementedError; end
        def on_permission_denied; raise NotImplementedError; end
        def on_not_found; raise NotImplementedError; end
      end
    end
  end
end
