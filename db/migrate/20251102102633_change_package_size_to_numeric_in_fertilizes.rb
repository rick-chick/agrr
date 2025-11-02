# frozen_string_literal: true

class ChangePackageSizeToNumericInFertilizes < ActiveRecord::Migration[8.0]
  def up
    # 既存のstringデータを数値に変換（"25kg" -> 25.0）
    # すべてのレコードを取得して変換
    Fertilize.reset_column_information
    Fertilize.find_each do |fertilize|
      if fertilize.package_size.present?
        # "25kg"や"25.5kg"のような文字列から数値を抽出
        numeric_value = fertilize.package_size.to_s.gsub(/[^0-9.]/, '').to_f
        numeric_value = nil if numeric_value == 0.0 && !fertilize.package_size.match?(/\d/)
        fertilize.update_column(:package_size, numeric_value)
      end
    end
    
    # カラム型をfloatに変更
    change_column :fertilizes, :package_size, :float
  end

  def down
    # floatからstringに戻す（数値を文字列に変換）
    change_column :fertilizes, :package_size, :string
    Fertilize.reset_column_information
    Fertilize.find_each do |fertilize|
      if fertilize.package_size.present?
        fertilize.update_column(:package_size, "#{fertilize.package_size}kg")
      end
    end
  end
end

