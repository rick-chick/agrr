# frozen_string_literal: true

# AgriculturalTaskCrop（農業タスクと作物の中間テーブル）モデル
#
# Attributes:
#   agricultural_task_id: 農業タスクID（必須）
#   crop_id: 作物ID（必須）
#
# 農業タスクと作物のN:N関係を管理
class AgriculturalTaskCrop < ApplicationRecord
  belongs_to :agricultural_task
  belongs_to :crop

  validates :agricultural_task_id, uniqueness: { scope: :crop_id }
end



