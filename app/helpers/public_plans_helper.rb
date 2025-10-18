# frozen_string_literal: true

module PublicPlansHelper
  # 地域コードから国旗絵文字を返す
  def region_flag(region)
    case region
    when 'jp'
      '🇯🇵'
    when 'us'
      '🇺🇸'
    when 'cn'
      '🇨🇳'
    when 'au'
      '🇦🇺'
    when 'eu'
      '🇪🇺'
    else
      '🌍'
    end
  end

  # 地域コードから地域名を返す
  def region_name(region)
    case region
    when 'jp'
      'Japan'
    when 'us'
      'United States'
    when 'cn'
      'China'
    when 'au'
      'Australia'
    when 'eu'
      'European Union'
    else
      region.upcase
    end
  end
end

