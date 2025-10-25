# frozen_string_literal: true

class FieldsAllocator
  attr_reader :total_area, :crops
  
  MAX_FIELDS = 5  # 圃場数の上限
  
  def initialize(total_area, crops)
    @total_area = total_area.to_f
    @crops = Array(crops)
  end
  
  def allocate
    # total_areaが0または作物が空の場合は空配列を返す
    return [] if total_area <= 0 || @crops.empty?
    
    base_area = (total_area / field_count).floor
    remainder = (total_area - (base_area * field_count)).round
    
    prioritized_crops.map.with_index do |crop, index|
      # 余りを優先順位順に1㎡ずつ分配
      # 最初の remainder 個の圃場に +1㎡
      additional_area = if index < remainder
        1.0
      else
        0.0
      end
      
      {
        crop: crop,
        area: base_area + additional_area
      }
    end
  end
  
  def field_count
    @field_count ||= calculate_field_count
  end
  
  private
  
  def calculate_field_count
    # 作物数と上限のうち小さい方を最大値とする
    max_count = [@crops.count, MAX_FIELDS].min
    
    max_count.downto(1).find do |count|
      (total_area / count) >= max_area_per_unit
    end || 1
  end
  
  def max_area_per_unit
    @max_area_per_unit ||= @crops.map(&:area_per_unit).compact.max || 10.0
  end
  
  def prioritized_crops
    @crops.sort_by { |c| -(c.area_per_unit || 0) }.take(field_count)
  end
end

