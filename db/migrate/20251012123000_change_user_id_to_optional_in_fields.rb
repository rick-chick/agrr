# frozen_string_literal: true

class ChangeUserIdToOptionalInFields < ActiveRecord::Migration[8.0]
  def change
    change_column_null :fields, :user_id, true
  end
end
