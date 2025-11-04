# frozen_string_literal: true

FactoryBot.define do
  factory :crop_pest do
    association :crop
    association :pest
  end
end




