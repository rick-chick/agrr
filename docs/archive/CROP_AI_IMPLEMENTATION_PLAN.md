# AI作物情報取得機能の実装計画

## 📋 現状

**問題**: 「🤖 AIで作物情報を保存」ボタンがあるが、実際にはAIで情報を取得していない

### 現在の動作
```javascript
// app/javascript/controllers/crop_ai_controller.js
const cropData = {
  name: cropName,        // ユーザー入力そのまま
  variety: variety,      // ユーザー入力そのまま
  is_reference: false
}
```

## 🎯 実装すべき機能

### オプション1: `agrr crop --query` を使う（推奨されていた方法）

**前提条件:**
- `agrr crop --query "作物名"` コマンドが実装されている
- JSONで作物情報を返す

**実装手順:**

#### 1. バックエンドにAPIエンドポイントを追加

```ruby
# app/controllers/api/v1/crops_controller.rb (新規)
module Api
  module V1
    class CropsController < Api::V1::BaseController
      # POST /api/v1/crops/ai_query
      def ai_query
        crop_name = params[:name]
        
        unless crop_name.present?
          return render json: { error: 'Crop name is required' }, status: :bad_request
        end
        
        begin
          crop_info = fetch_crop_info_from_agrr(crop_name)
          render json: { success: true, data: crop_info }
        rescue => e
          Rails.logger.error "AI Query failed: #{e.message}"
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end
      
      private
      
      def fetch_crop_info_from_agrr(crop_name)
        require 'open3'
        
        agrr_path = Rails.root.join('lib', 'core', 'agrr').to_s
        command = [agrr_path, 'crop', '--query', crop_name, '--json']
        
        Rails.logger.debug "🔧 [AGRR Crop Query] #{command.join(' ')}"
        
        stdout, stderr, status = Open3.capture3(*command)
        
        unless status.success?
          Rails.logger.error "❌ [AGRR Crop Query Error] #{stderr}"
          raise "Failed to query crop info: #{stderr}"
        end
        
        JSON.parse(stdout)
      end
    end
  end
end
```

#### 2. ルートを追加

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    namespace :crops do
      post :ai_query, to: 'crops#ai_query'
      # ...existing routes
    end
  end
end
```

#### 3. JavaScriptを更新

```javascript
// app/javascript/controllers/crop_ai_controller.js
async saveCrop(event) {
  event.preventDefault()
  
  const cropName = this.nameField?.value?.trim()
  const variety = this.varietyField?.value?.trim()
  
  if (!cropName) {
    this.showStatus('作物名を入力してください', 'error')
    return
  }
  
  this.button.disabled = true
  this.button.textContent = '🤖 AIで情報を取得中...'
  this.showStatus('AIで作物情報を取得しています...', 'info')
  
  try {
    const csrfToken = document.querySelector('[name="csrf-token"]')?.content
    
    // Step 1: AI Query - 作物情報を取得
    const queryResponse = await fetch('/api/v1/crops/ai_query', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken
      },
      body: JSON.stringify({ name: cropName })
    })
    
    if (!queryResponse.ok) {
      throw new Error('作物情報の取得に失敗しました')
    }
    
    const queryData = await queryResponse.json()
    
    // Step 2: 取得した情報をフォームに反映（オプション）
    if (queryData.data.area_per_unit) {
      document.querySelector('input[name="crop[area_per_unit]"]').value = queryData.data.area_per_unit
    }
    if (queryData.data.revenue_per_area) {
      document.querySelector('input[name="crop[revenue_per_area]"]').value = queryData.data.revenue_per_area
    }
    
    this.button.textContent = '🤖 保存中...'
    this.showStatus('作物情報を保存しています...', 'info')
    
    // Step 3: 作物を保存
    const cropData = {
      name: cropName,
      variety: variety || queryData.data.variety,
      is_reference: false,
      area_per_unit: queryData.data.area_per_unit,
      revenue_per_area: queryData.data.revenue_per_area
    }
    
    const response = await fetch('/api/v1/crops', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken
      },
      body: JSON.stringify({ crop: cropData })
    })
    
    const data = await response.json()
    
    if (response.ok) {
      this.showStatus(`✓ 作物「${data.crop_name}」が保存されました！`, 'success')
      setTimeout(() => {
        window.location.href = `/crops/${data.crop_id}`
      }, 1500)
    } else {
      throw new Error(data.error || '作物の保存に失敗しました')
    }
  } catch (error) {
    console.error('Error:', error)
    this.showStatus(`エラー: ${error.message}`, 'error')
    this.resetButton()
  }
}
```

### オプション2: バックエンドでAI処理（推奨）

フロントエンドからは作物名だけ送信し、バックエンドでAI処理と保存を一度に行う：

```javascript
// app/javascript/controllers/crop_ai_controller.js
async saveCrop(event) {
  event.preventDefault()
  
  const cropName = this.nameField?.value?.trim()
  
  if (!cropName) {
    this.showStatus('作物名を入力してください', 'error')
    return
  }
  
  this.button.disabled = true
  this.button.textContent = '🤖 AIで処理中...'
  this.showStatus('AIで作物情報を取得・保存しています...', 'info')
  
  try {
    const csrfToken = document.querySelector('[name="csrf-token"]')?.content
    
    const response = await fetch('/api/v1/crops/ai_create', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken
      },
      body: JSON.stringify({ name: cropName })
    })
    
    const data = await response.json()
    
    if (response.ok) {
      this.showStatus(`✓ 作物「${data.crop_name}」が保存されました！`, 'success')
      setTimeout(() => {
        window.location.href = `/crops/${data.crop_id}`
      }, 1500)
    } else {
      throw new Error(data.error || '作物の保存に失敗しました')
    }
  } catch (error) {
    console.error('Error:', error)
    this.showStatus(`エラー: ${error.message}`, 'error')
    this.resetButton()
  }
}
```

```ruby
# app/controllers/api/v1/crops_controller.rb
def ai_create
  crop_name = params[:name]
  
  # 1. agrrで情報取得
  crop_info = fetch_crop_info_from_agrr(crop_name)
  
  # 2. データベースに保存
  attrs = {
    user_id: current_user.id,
    name: crop_name,
    variety: crop_info['variety'],
    area_per_unit: crop_info['area_per_unit'],
    revenue_per_area: crop_info['revenue_per_area'],
    is_reference: false
  }
  
  result = @create_interactor.call(attrs)
  
  if result.success?
    render json: crop_to_json(result.data), status: :created
  else
    render json: { error: result.error }, status: :unprocessable_entity
  end
end
```

### オプション3: ボタン名を変更（最も簡単）

AI機能が実装されていない場合は、誤解を招かないようにボタン名を変更：

```erb
<!-- app/views/crops/_form.html.erb -->
<button type="button" id="ai-save-crop-btn" class="btn btn-ai" data-controller="crop-ai">
  💾 作物情報を保存
</button>
```

```javascript
// app/javascript/controllers/crop_ai_controller.js
resetButton() {
  this.button.disabled = false
  this.button.textContent = '💾 作物情報を保存'
}
```

## 🔧 実装チェックリスト

- [ ] `agrr crop --query` コマンドが利用可能か確認
- [ ] コマンドの出力形式を確認（JSON構造）
- [ ] バックエンドAPIエンドポイント作成
- [ ] ルート追加
- [ ] JavaScriptコントローラー更新
- [ ] エラーハンドリング追加
- [ ] テスト作成
- [ ] ログ追加（デバッグ用）
- [ ] ドキュメント更新

## 📝 agrrコマンドの確認方法

```bash
# コマンドが存在するか
docker-compose exec web /app/lib/core/agrr --help

# crop サブコマンドがあるか
docker-compose exec web /app/lib/core/agrr crop --help

# テスト実行
docker-compose exec web /app/lib/core/agrr crop --query "トマト" --json
```

## 💡 推奨事項

1. **まずagrrコマンドを確認**: `agrr crop --query` が実装されているか
2. **実装されていない場合**: ボタン名を変更して誤解を防ぐ
3. **実装する場合**: オプション2（バックエンドで処理）を推奨
   - フロントエンドがシンプル
   - エラーハンドリングが容易
   - セキュリティが高い

## 🐛 デバッグ時のログ

実装する場合は、以下のログを追加：

```ruby
Rails.logger.debug "🔧 [AGRR Crop Query] Command: #{command.join(' ')}"
Rails.logger.debug "📥 [AGRR Crop Response] #{stdout[0..500]}"
Rails.logger.debug "📊 [AGRR Crop Data] #{parsed_data.inspect}"
```

