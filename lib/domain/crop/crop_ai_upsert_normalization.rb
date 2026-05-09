# frozen_string_literal: true

module Domain
  module Crop
    # Crop AI 永続化アダプタから CropPolicy への直接依存を避け、正規化はドメイン側に集約する。
    module CropAiUpsertNormalization
      class << self
        def normalize_attrs_for_create(user, attrs)
          Domain::Shared::Policies::CropPolicy.normalize_attrs_for_create(user, attrs)
        end
      end
    end
  end
end
