# frozen_string_literal: true

class GenerateFreeCropPlanJob < ApplicationJob
  queue_as :default
  
  # インスタンス変数の定義
  attr_accessor :free_crop_plan_id, :channel_class

  def perform(free_crop_plan_id, channel_class: nil)
    free_crop_plan = FreeCropPlan.find(free_crop_plan_id)
    
    # 開始通知
    if channel_class
      channel_class.broadcast_to(free_crop_plan, {
        status: 'started',
        progress: 0,
        phase: 'calculating',
        phase_message: '作付け計画を計算中です...'
      })
      Rails.logger.info "🌱 [GenerateFreeCropPlanJob] Started calculation for plan ##{free_crop_plan_id}"
    end
    
    # 計算中に設定
    free_crop_plan.start_calculation!
    
    begin
      # 作付け計画を生成
      plan_data = generate_plan(free_crop_plan)
      
      # 広告表示時間を確保するため、少し待つ（実際の計算時間をシミュレート）
      sleep(5)
      
      # 計画データを保存
      free_crop_plan.complete_calculation!(plan_data)
      
      # 完了通知
      if channel_class
        channel_class.broadcast_to(free_crop_plan, {
          status: 'completed',
          progress: 100,
          phase: 'completed',
          phase_message: '作付け計画の計算が完了しました'
        })
        Rails.logger.info "🌱 [GenerateFreeCropPlanJob] Calculation completed for plan ##{free_crop_plan_id}"
      end
      
      Rails.logger.info "✅ FreeCropPlan ##{free_crop_plan.id} generated successfully"
    rescue StandardError => e
      Rails.logger.error "❌ FreeCropPlan ##{free_crop_plan.id} generation failed: #{e.message}"
      free_crop_plan.mark_failed!(e.message)
      
      # エラー通知
      if channel_class
        channel_class.broadcast_to(free_crop_plan, {
          status: 'failed',
          progress: 0,
          phase: 'failed',
          phase_message: '作付け計画の計算に失敗しました'
        })
        Rails.logger.info "🌱 [GenerateFreeCropPlanJob] Calculation failed for plan ##{free_crop_plan_id}"
      end
    end
  end
  
  private
  
  def generate_plan(free_crop_plan)
    crop = free_crop_plan.crop
    region = free_crop_plan.region
    
    # 簡易的な作付け計画データを生成
    # 実際にはもっと複雑な気候データ分析が必要
    {
      planting_windows: generate_planting_windows(crop, region),
      harvest_windows: generate_harvest_windows(crop, region),
      recommendations: generate_recommendations(crop, region, free_crop_plan.area_sqm)
    }
  end
  
  def generate_planting_windows(crop, region)
    # 簡易的な播種時期の推定
    # 実際には作物の特性と地域の気候データから計算
    case region.country_code
    when 'JP'
      [
        {
          name: '春播き',
          start_date: '3月中旬',
          end_date: '4月下旬',
          notes: '最終霜が降りる前に播種する場合は、霜よけが必要です。'
        },
        {
          name: '秋播き',
          start_date: '9月上旬',
          end_date: '10月中旬',
          notes: '秋播きは春播きに比べて成長がゆっくりですが、病害虫の被害が少ない傾向があります。'
        }
      ]
    when 'US'
      [
        {
          name: 'Spring Planting',
          start_date: 'Mid-March',
          end_date: 'Late May',
          notes: 'Wait until soil temperature reaches at least 50°F (10°C).'
        }
      ]
    else
      [
        {
          name: '推奨播種時期',
          start_date: '気候が安定する時期',
          end_date: '霜の心配がない時期',
          notes: '地域の気候に応じて調整してください。'
        }
      ]
    end
  end
  
  def generate_harvest_windows(crop, region)
    # 簡易的な収穫時期の推定
    case region.country_code
    when 'JP'
      [
        {
          name: '初夏収穫（春播き）',
          start_date: '6月上旬',
          end_date: '7月下旬',
          notes: '播種から約70-90日後が収穫の目安です。'
        },
        {
          name: '晩秋～初冬収穫（秋播き）',
          start_date: '11月上旬',
          end_date: '12月下旬',
          notes: '霜に当たると甘みが増します。'
        }
      ]
    when 'US'
      [
        {
          name: 'Summer Harvest',
          start_date: 'Early June',
          end_date: 'Late August',
          notes: 'Harvest approximately 70-90 days after planting.'
        }
      ]
    else
      [
        {
          name: '推奨収穫時期',
          start_date: '播種から70-90日後',
          end_date: '適期を逃さないよう注意',
          notes: '収穫適期は作物の状態を見て判断してください。'
        }
      ]
    end
  end
  
  def generate_recommendations(crop, region, area_sqm)
    recommendations = []
    
    # 農場サイズに応じた推奨事項
    if area_sqm < 20
      recommendations << "小規模農場では、集約的な栽培が可能です。畝間を詰めて栽培密度を上げることができます。"
    elsif area_sqm < 100
      recommendations << "中規模農場では、輪作計画を立てることをお勧めします。"
    else
      recommendations << "大規模農場では、機械化を検討すると効率が上がります。"
    end
    
    # 作物に応じた一般的な推奨事項
    recommendations << "#{crop.name}は日当たりの良い場所を好みます。"
    recommendations << "土壌は排水性の良いものを選びましょう。"
    recommendations << "定期的な水やりと追肥が重要です。"
    recommendations << "病害虫対策として、風通しを良くし、適切な株間を保ちましょう。"
    
    # 地域に応じた推奨事項
    case region.country_code
    when 'JP'
      recommendations << "日本の気候では、梅雨時期の湿害に注意が必要です。"
    when 'US'
      recommendations << "地域の農業普及センターに相談することをお勧めします。"
    end
    
    recommendations
  end
end
