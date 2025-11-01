#!/usr/bin/env python3
"""
アメリカのweatherデータの地域差を統計的に分析するスクリプト
"""
import json
import sys
from pathlib import Path
from collections import defaultdict
import statistics

# プロジェクトルートをパスに追加
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

def load_weather_data():
    """weatherデータをロード"""
    fixture_path = project_root / 'db/fixtures/us_reference_weather.json'
    
    if not fixture_path.exists():
        print(f"❌ ファイルが見つかりません: {fixture_path}")
        sys.exit(1)
    
    with open(fixture_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def extract_state(farm_name):
    """ファーム名から州を抽出"""
    # "County, STATE" の形式を想定
    parts = farm_name.split(', ')
    if len(parts) >= 2:
        return parts[1]
    return "Unknown"

def calculate_statistics(weather_data):
    """weatherデータから統計値を計算"""
    if not weather_data:
        return None
    
    # 有効なデータのみ抽出
    temp_max_list = [d.get('temperature_max') for d in weather_data if d.get('temperature_max') is not None]
    temp_min_list = [d.get('temperature_min') for d in weather_data if d.get('temperature_min') is not None]
    temp_mean_list = [d.get('temperature_mean') for d in weather_data if d.get('temperature_mean') is not None]
    precipitation_list = [d.get('precipitation') for d in weather_data if d.get('precipitation') is not None]
    sunshine_list = [d.get('sunshine_hours') for d in weather_data if d.get('sunshine_hours') is not None]
    wind_speed_list = [d.get('wind_speed') for d in weather_data if d.get('wind_speed') is not None]
    
    stats = {}
    
    if temp_max_list:
        stats['temp_max'] = {
            'mean': statistics.mean(temp_max_list),
            'median': statistics.median(temp_max_list),
            'stdev': statistics.stdev(temp_max_list) if len(temp_max_list) > 1 else 0,
            'min': min(temp_max_list),
            'max': max(temp_max_list),
            'count': len(temp_max_list)
        }
    
    if temp_min_list:
        stats['temp_min'] = {
            'mean': statistics.mean(temp_min_list),
            'median': statistics.median(temp_min_list),
            'stdev': statistics.stdev(temp_min_list) if len(temp_min_list) > 1 else 0,
            'min': min(temp_min_list),
            'max': max(temp_min_list),
            'count': len(temp_min_list)
        }
    
    if temp_mean_list:
        stats['temp_mean'] = {
            'mean': statistics.mean(temp_mean_list),
            'median': statistics.median(temp_mean_list),
            'stdev': statistics.stdev(temp_mean_list) if len(temp_mean_list) > 1 else 0,
            'min': min(temp_mean_list),
            'max': max(temp_mean_list),
            'count': len(temp_mean_list)
        }
    
    if precipitation_list:
        stats['precipitation'] = {
            'mean': statistics.mean(precipitation_list),
            'median': statistics.median(precipitation_list),
            'stdev': statistics.stdev(precipitation_list) if len(precipitation_list) > 1 else 0,
            'min': min(precipitation_list),
            'max': max(precipitation_list),
            'count': len(precipitation_list),
            'total': sum(precipitation_list)
        }
    else:
        stats['precipitation'] = {'mean': None, 'count': 0}
    
    if sunshine_list:
        stats['sunshine_hours'] = {
            'mean': statistics.mean(sunshine_list),
            'median': statistics.median(sunshine_list),
            'stdev': statistics.stdev(sunshine_list) if len(sunshine_list) > 1 else 0,
            'min': min(sunshine_list),
            'max': max(sunshine_list),
            'count': len(sunshine_list),
            'total': sum(sunshine_list)
        }
    else:
        stats['sunshine_hours'] = {'mean': None, 'count': 0}
    
    if wind_speed_list:
        stats['wind_speed'] = {
            'mean': statistics.mean(wind_speed_list),
            'median': statistics.median(wind_speed_list),
            'stdev': statistics.stdev(wind_speed_list) if len(wind_speed_list) > 1 else 0,
            'min': min(wind_speed_list),
            'max': max(wind_speed_list),
            'count': len(wind_speed_list)
        }
    
    return stats

def analyze_regional_differences(data):
    """地域差を分析"""
    # ファームごとの統計
    farm_stats = {}
    state_groups = defaultdict(list)
    
    print("=" * 80)
    print("📊 アメリカweatherデータの地域差分析")
    print("=" * 80)
    print()
    
    # 各ファームの統計を計算
    for farm_name, farm_data in data.items():
        weather_data = farm_data.get('weather_data', [])
        stats = calculate_statistics(weather_data)
        
        if stats:
            farm_stats[farm_name] = {
                'latitude': float(farm_data.get('latitude', 0)),
                'longitude': float(farm_data.get('longitude', 0)),
                'state': extract_state(farm_name),
                'stats': stats,
                'data_count': len(weather_data)
            }
            
            state = extract_state(farm_name)
            state_groups[state].append(farm_name)
    
    # ファームごとの詳細統計を表示
    print("📍 ファーム別統計情報")
    print("-" * 80)
    
    for farm_name, info in sorted(farm_stats.items()):
        stats = info['stats']
        print(f"\n{farm_name} ({info['state']})")
        print(f"  位置: {info['latitude']}, {info['longitude']}")
        print(f"  データ数: {info['data_count']:,}")
        
        if 'temp_mean' in stats:
            print(f"  平均気温: {stats['temp_mean']['mean']:.2f}°C (SD: {stats['temp_mean']['stdev']:.2f})")
            print(f"    最高気温: 平均{stats['temp_max']['mean']:.2f}°C, 最低気温: 平均{stats['temp_min']['mean']:.2f}°C")
        
        if stats['precipitation']['mean'] is not None:
            print(f"  降水量: 平均{stats['precipitation']['mean']:.2f}mm/日 (合計: {stats['precipitation']['total']:.2f}mm)")
        else:
            print(f"  降水量: データなし")
        
        if stats['sunshine_hours']['mean'] is not None:
            print(f"  日照時間: 平均{stats['sunshine_hours']['mean']:.2f}時間/日")
        else:
            print(f"  日照時間: データなし")
        
        if 'wind_speed' in stats:
            print(f"  風速: 平均{stats['wind_speed']['mean']:.2f}km/h")
    
    # 州別の統計
    print("\n\n" + "=" * 80)
    print("🗺️  州別統計")
    print("=" * 80)
    
    state_statistics = {}
    
    for state, farms in sorted(state_groups.items()):
        state_stats = []
        temp_means = []
        precip_means = []
        
        for farm_name in farms:
            if farm_name in farm_stats:
                stats = farm_stats[farm_name]['stats']
                state_stats.append(farm_stats[farm_name])
                
                if 'temp_mean' in stats:
                    temp_means.append(stats['temp_mean']['mean'])
                if stats['precipitation']['mean'] is not None:
                    precip_means.append(stats['precipitation']['mean'])
        
        if state_stats:
            state_statistics[state] = {
                'farms': len(state_stats),
                'temp_means': temp_means,
                'precip_means': precip_means,
                'farms_list': [f['latitude'] for f in state_stats]
            }
            
            print(f"\n{state} ({len(state_stats)} farms)")
            
            if temp_means:
                print(f"  平均気温の平均: {statistics.mean(temp_means):.2f}°C")
                print(f"  平均気温の範囲: {min(temp_means):.2f}°C ～ {max(temp_means):.2f}°C")
                if len(temp_means) > 1:
                    print(f"  平均気温の標準偏差: {statistics.stdev(temp_means):.2f}°C")
            
            if precip_means:
                print(f"  降水量の平均: {statistics.mean(precip_means):.2f}mm/日")
                print(f"  降水量の範囲: {min(precip_means):.2f}mm/日 ～ {max(precip_means):.2f}mm/日")
    
    # 全体の統計と地域差の検証
    print("\n\n" + "=" * 80)
    print("📈 全体統計と地域差の評価")
    print("=" * 80)
    
    all_temp_means = [fs['stats']['temp_mean']['mean'] 
                     for fs in farm_stats.values() 
                     if 'temp_mean' in fs['stats']]
    
    all_precip_means = [fs['stats']['precipitation']['mean'] 
                        for fs in farm_stats.values() 
                        if fs['stats']['precipitation']['mean'] is not None]
    
    if all_temp_means:
        print(f"\n🌡️  平均気温（全ファーム）")
        print(f"  平均: {statistics.mean(all_temp_means):.2f}°C")
        print(f"  中央値: {statistics.median(all_temp_means):.2f}°C")
        print(f"  標準偏差: {statistics.stdev(all_temp_means):.2f}°C")
        print(f"  範囲: {min(all_temp_means):.2f}°C ～ {max(all_temp_means):.2f}°C")
        print(f"  変動係数: {(statistics.stdev(all_temp_means) / statistics.mean(all_temp_means) * 100):.2f}%")
        
        # 地域差の評価
        range_ratio = (max(all_temp_means) - min(all_temp_means)) / statistics.mean(all_temp_means) * 100
        print(f"\n  地域差の評価:")
        print(f"  最高気温と最低気温の差: {max(all_temp_means) - min(all_temp_means):.2f}°C")
        print(f"  平均に対する差の割合: {range_ratio:.2f}%")
        
        if range_ratio < 5:
            print(f"  ⚠️  地域差が非常に小さいです（差が5%未満）")
        elif range_ratio < 10:
            print(f"  ⚠️  地域差が小さいです（差が10%未満）")
        else:
            print(f"  ✅ 地域差は適度にあります")
    
    if all_precip_means:
        print(f"\n🌧️  降水量（全ファーム）")
        print(f"  平均: {statistics.mean(all_precip_means):.2f}mm/日")
        print(f"  中央値: {statistics.median(all_precip_means):.2f}mm/日")
        if len(all_precip_means) > 1:
            print(f"  標準偏差: {statistics.stdev(all_precip_means):.2f}mm/日")
        print(f"  範囲: {min(all_precip_means):.2f}mm/日 ～ {max(all_precip_means):.2f}mm/日")
        
        if len(all_precip_means) > 1 and statistics.mean(all_precip_means) > 0:
            range_ratio = (max(all_precip_means) - min(all_precip_means)) / statistics.mean(all_precip_means) * 100
            print(f"  変動係数: {(statistics.stdev(all_precip_means) / statistics.mean(all_precip_means) * 100):.2f}%")
            print(f"\n  地域差の評価:")
            print(f"  最高降水量と最低降水量の差: {max(all_precip_means) - min(all_precip_means):.2f}mm/日")
            print(f"  平均に対する差の割合: {range_ratio:.2f}%")
    
    # データの欠損状況
    print("\n\n" + "=" * 80)
    print("⚠️  データ欠損状況")
    print("=" * 80)
    
    missing_precip = sum(1 for fs in farm_stats.values() 
                        if fs['stats']['precipitation']['mean'] is None)
    missing_sunshine = sum(1 for fs in farm_stats.values() 
                          if fs['stats']['sunshine_hours']['mean'] is None)
    
    print(f"\n降水量データが欠損しているファーム: {missing_precip}/{len(farm_stats)}")
    print(f"日照時間データが欠損しているファーム: {missing_sunshine}/{len(farm_stats)}")
    
    if missing_precip > len(farm_stats) * 0.5:
        print(f"\n⚠️  降水量データの欠損が多く、地域差の評価が困難です")
    
    if missing_sunshine > len(farm_stats) * 0.5:
        print(f"⚠️  日照時間データの欠損が多く、地域差の評価が困難です")

if __name__ == '__main__':
    data = load_weather_data()
    analyze_regional_differences(data)

