# frozen_string_literal: true

module Api
  module V1
    class FertilizesController < Api::V1::BaseController
      # ai_createは認証不要（無料プラン機能の一部）
      # ai_updateはHTMLフォームから呼び出すため認証必須
      skip_before_action :authenticate_api_request, only: [:ai_create]
      before_action :authenticate_api_request, only: [:ai_update]
      before_action :set_interactors, only: [:ai_create, :ai_update]
      before_action :set_fertilize, only: [:ai_update]

      # POST /api/v1/fertilizes/ai_create
      # AIで肥料情報を取得して保存
      def ai_create
        fertilize_name = params[:name]&.strip

        unless fertilize_name.present?
          return render json: { error: I18n.t('api.errors.fertilizes.name_required') }, status: :bad_request
        end

        begin
          Rails.logger.info "🤖 [AI Fertilize] Querying fertilize info for: #{fertilize_name}"
          fertilize_info = ai_gateway.fetch_for_create(name: fertilize_name)

          # エラーチェック（エラー時は success: false が返る）
          if fertilize_info['success'] == false
            error_msg = fertilize_info['error'] || I18n.t('api.errors.fertilizes.fetch_failed')
            # デーモン未起動の場合は特別なステータスコードを使用
            status_code = fertilize_info['code'] == 'daemon_not_running' ? :service_unavailable : :unprocessable_entity
            return render json: { error: error_msg }, status: status_code
          end

          fertilize_data = normalize_fertilize_payload(fertilize_info)
          
          unless fertilize_data
            return render json: { error: I18n.t('api.errors.fertilizes.invalid_payload') }, status: :unprocessable_entity
          end
          
          # agrrの結果に基づいて、name（商品名）とpackage_sizeを使用
          # nameはagrrから返された商品名をそのまま使用
          fertilize_name_from_agrr = fertilize_data['name']
          fertilize_package_size_from_agrr = parse_package_size(fertilize_data['package_size'])
          
          Rails.logger.info "📊 [AI Fertilize] Retrieved data: name=#{fertilize_name_from_agrr}, n=#{fertilize_data['n']}, p=#{fertilize_data['p']}, k=#{fertilize_data['k']}, package_size=#{fertilize_package_size_from_agrr}"

          base_attrs = {
            name: fertilize_name_from_agrr,  # agrrから返された商品名
            n: fertilize_data['n'],
            p: fertilize_data['p'],
            k: fertilize_data['k'],
            description: fertilize_data['description'],
            package_size: fertilize_package_size_from_agrr  # agrrから返されたpackage_size
          }

          # 既存のユーザー肥料を検索（所有者は current_user のみ）
          existing_fertilize = ::Fertilize.find_by(
            name: fertilize_name_from_agrr,
            is_reference: false,
            user_id: current_user.id
          )

          if existing_fertilize
            # 既存の肥料を更新（所有者・参照フラグは変更しない）
            Rails.logger.info "🔄 [AI Fertilize] Updating existing fertilize##{existing_fertilize.id}: #{fertilize_name_from_agrr}"
            result = @update_interactor.call(existing_fertilize.id, base_attrs)
            status_code = :ok
          else
            # 新規作成（所有者・参照フラグの決定は Policy に委譲）
            Rails.logger.info "🆕 [AI Fertilize] Creating new fertilize: #{fertilize_name_from_agrr}"
            policy_fertilize = FertilizePolicy.build_for_create(current_user, base_attrs)
            attrs_for_create = base_attrs.merge(
              user_id: policy_fertilize.user_id,
              is_reference: policy_fertilize.is_reference
            )
            result = @create_interactor.call(attrs_for_create)
            status_code = :created
          end

          if result.success?
            fertilize_entity = result.data
            action = existing_fertilize ? "Updated" : "Created"
            Rails.logger.info "✅ [AI Fertilize] #{action} fertilize##{fertilize_entity.id}: #{fertilize_entity.name}"

            render json: {
              success: true,
              fertilize_id: fertilize_entity.id,
              fertilize_name: fertilize_entity.name,
              n: fertilize_entity.n,
              p: fertilize_entity.p,
              k: fertilize_entity.k,
              description: fertilize_entity.description,
              package_size: fertilize_entity.package_size,
              message: I18n.t('api.messages.fertilizes.created_by_ai', name: fertilize_entity.name)
            }, status: status_code
          else
            Rails.logger.error "❌ [AI Fertilize] Failed to #{existing_fertilize ? 'update' : 'create'}: #{result.error}"
            render json: { error: result.error }, status: :unprocessable_entity
          end

        rescue => e
          Rails.logger.error "❌ [AI Fertilize] Error: #{e.message}"
          Rails.logger.error "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
          render json: { error: I18n.t('api.errors.fertilizes.fetch_failed_with_reason', message: e.message) }, status: :internal_server_error
        end
      end

      # POST /api/v1/fertilizes/:id/ai_update
      # AIで肥料情報を取得して更新（編集時は既存を編集）
      def ai_update
        fertilize_name = params[:name]&.strip

        unless fertilize_name.present?
          return render json: { error: I18n.t('api.errors.fertilizes.name_required') }, status: :bad_request
        end

        unless @fertilize
          return render json: { error: I18n.t('api.errors.fertilizes.not_found', default: '肥料が見つかりません') }, status: :not_found
        end

        begin
          # agrrコマンドで肥料情報を取得
          Rails.logger.info "🤖 [AI Fertilize] Querying fertilize info for update: #{fertilize_name} (ID: #{@fertilize.id})"
          fertilize_info = ai_gateway.fetch_for_update(id: @fertilize.id, name: fertilize_name)

          # エラーチェック
          if fertilize_info['success'] == false
            error_msg = fertilize_info['error'] || I18n.t('api.errors.fertilizes.fetch_failed')
            status_code = fertilize_info['code'] == 'daemon_not_running' ? :service_unavailable : :unprocessable_entity
            return render json: { error: error_msg }, status: status_code
          end

          fertilize_data = normalize_fertilize_payload(fertilize_info)
          unless fertilize_data
            return render json: { error: I18n.t('api.errors.fertilizes.invalid_payload') }, status: :unprocessable_entity
          end

          fertilize_name_from_agrr = fertilize_data['name']
          fertilize_package_size_from_agrr = parse_package_size(fertilize_data['package_size'])

          Rails.logger.info "🔄 [AI Fertilize] Updating fertilize##{@fertilize.id} with latest data from agrr"

          # agrrから返された商品名とpackage_sizeを使用して更新
          attrs = {
            name: fertilize_name_from_agrr,  # agrrから返された商品名
            n: fertilize_data['n'],
            p: fertilize_data['p'],
            k: fertilize_data['k'],
            description: fertilize_data['description'],
            package_size: fertilize_package_size_from_agrr  # agrrから返されたpackage_size
          }

          result = @update_interactor.call(@fertilize.id, attrs)

          if result.success?
            fertilize_entity = result.data
            Rails.logger.info "✅ [AI Fertilize] Updated fertilize##{fertilize_entity.id}: #{fertilize_entity.name}"

            render json: {
              success: true,
              fertilize_id: fertilize_entity.id,
              fertilize_name: fertilize_entity.name,
              n: fertilize_entity.n,
              p: fertilize_entity.p,
              k: fertilize_entity.k,
              description: fertilize_entity.description,
              package_size: fertilize_entity.package_size,
              is_reference: fertilize_entity.is_reference,
              message: I18n.t('api.messages.fertilizes.updated_by_ai', name: fertilize_entity.name, default: '肥料「%{name}」を更新しました')
            }, status: :ok
          else
            Rails.logger.error "❌ [AI Fertilize] Failed to update: #{result.error}"
            render json: { error: result.error }, status: :unprocessable_entity
          end

        rescue => e
          Rails.logger.error "❌ [AI Fertilize] Error: #{e.message}"
          Rails.logger.error "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
          render json: { error: I18n.t('api.errors.fertilizes.fetch_failed_with_reason', message: e.message) }, status: :internal_server_error
        end
      end

      private

      # agrrから来るpackage_size（文字列、例: "25kg"）を数値（例: 25.0）に変換
      def parse_package_size(value)
        return nil if value.nil? || value.to_s.strip.empty?
        
        # 文字列から数値部分を抽出（"25kg" -> 25.0, "25.5kg" -> 25.5）
        numeric_value = value.to_s.gsub(/[^0-9.]/, '').to_f
        numeric_value == 0.0 && !value.to_s.match?(/\d/) ? nil : numeric_value
      end

      def normalize_fertilize_payload(info)
        data = info['fertilize']
        data = data.deep_dup if data.respond_to?(:deep_dup)

        unless data
          direct_keys = info.slice('name', 'description', 'package_size', 'n', 'p', 'k', 'npk')
          return nil if direct_keys.blank?

          data = direct_keys.compact
          if data['n'].nil? && data['npk'].present?
            npk_values = parse_npk_string(data.delete('npk'))
            data.merge!(npk_values)
          else
            data.delete('npk')
          end
        end

        data['package_size'] = parse_package_size(data['package_size'])
        data['n'] = normalize_nutrient_value(data['n'])
        data['p'] = normalize_nutrient_value(data['p'])
        data['k'] = normalize_nutrient_value(data['k'])

        data
      end

      def parse_npk_string(value)
        return {} unless value.present?

        numbers = value.to_s.split(/[-\/\\]/).map { |part| part.strip.presence }.compact
        n_value = numbers[0]&.to_f
        p_value = numbers[1]&.to_f
        k_value = numbers[2]&.to_f

        {
          'n' => normalize_nutrient_value(n_value),
          'p' => normalize_nutrient_value(p_value),
          'k' => normalize_nutrient_value(k_value)
        }
      end

      def normalize_nutrient_value(value)
        return nil if value.nil?
        numeric = value.to_f
        numeric.zero? ? nil : numeric
      end

      def set_fertilize
        @fertilize =
          begin
            FertilizePolicy.find_editable!(current_user, params[:id])
          rescue PolicyPermissionDenied, ActiveRecord::RecordNotFound
            nil
          end
      end

      def set_interactors
        gateway = Adapters::Fertilize::Gateways::FertilizeMemoryGateway.new
        @create_interactor = Domain::Fertilize::Interactors::FertilizeCreateInteractor.new(gateway)
        @update_interactor = Domain::Fertilize::Interactors::FertilizeUpdateInteractor.new(gateway)
      end

      def ai_gateway
        Rails.configuration.x.fertilize_ai_gateway || default_ai_gateway
      end

      def default_ai_gateway
        @default_ai_gateway ||= Adapters::Fertilize::Gateways::FertilizeCliGateway.new
      end
    end
  end
end

