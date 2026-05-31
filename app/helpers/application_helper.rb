# frozen_string_literal: true

module ApplicationHelper
  # JavaScriptから参照するi18nメッセージをdata属性として返す
  def js_i18n_data
    {}
  end

  def js_i18n_templates
    {}
  end

  # Rails locale を research 用パスに変換する
  # 日本語コンテンツは /research/ 直下にあるため、us のみ /research/en/ を返す
  # 'us' -> '/research/en/', それ以外 -> '/research/'
  def research_path_for(locale)
    locale.to_s == "us" ? "/research/en/" : "/research/"
  end

  # サイトマップ用: research ページの xhtml:link rel="alternate" 候補を返す
  # 各言語のファイルが存在する場合のみ含める。hreflang は BCP 47（ja, en, in はヒンディー用の内部キー）
  # ja/in は /research/ 直下、英語は /research/en/ 配下（URL パスは従来どおり）
  def research_alternate_urls(research_page_path, base_url)
    path = research_page_path.to_s.delete_prefix("research/").delete_prefix("/")
    content_path = path.sub(/\A(ja|en|in)\//, "") # 既に lang 付きパスなら除去

    alternates = []
    # ja, in: /research/ 直下のファイルを参照
    %w[ja in].each do |hreflang|
      candidate = "research/#{content_path}"
      alternates << { hreflang: hreflang, href: "#{base_url}/#{candidate}" } if File.exist?(Rails.root.join("public", candidate))
    end
    # us(en): /research/en/ 配下のファイルを参照
    en_candidate = "research/en/#{content_path}"
    alternates << { hreflang: "en", href: "#{base_url}/#{en_candidate}" } if File.exist?(Rails.root.join("public", en_candidate))

    alternates
  end

  # 現在のページが指定されたパスと一致するか判定
  def current_page?(path)
    request.path == path || request.path.start_with?("#{path}/")
  end

  # ナビゲーションリンクのクラスを返す（現在地の強調用）
  def nav_link_class(path, base_class = "nav-link")
    classes = [ base_class ]
    classes << "nav-link-active" if current_page?(path)
    classes.join(" ")
  end

  # ドロップダウンアイテムのクラスを返す（現在地の強調用）
  def nav_dropdown_item_class(path, base_class = "nav-dropdown-item")
    classes = [ base_class ]
    classes << "nav-dropdown-item-active" if current_page?(path)
    classes.join(" ")
  end

  # ============================================
  # UI/UX統一: スタイルシート読み込み順序の統一
  # ============================================

  # コアデザインシステムのスタイルシートを読み込む（必須・最初に読み込む）
  def render_core_stylesheets
    capture do
      concat stylesheet_link_tag("core/variables", "data-turbo-track": "reload")
      concat stylesheet_link_tag("core/reset", "data-turbo-track": "reload")
    end
  end

  # ユーティリティクラスのスタイルシートを読み込む
  def render_utility_stylesheets
    stylesheet_link_tag("utilities", "data-turbo-track": "reload")
  end

  # 共通コンポーネントのスタイルシートを読み込む
  # デフォルトコンポーネントリストは統一性のため、application.html.erbで使用される全コンポーネントを含む
  def render_component_stylesheets(components: nil)
    default_components = [
      "components/buttons",
      "components/forms",
      "components/navbar",
      "components/cards",
      "components/layouts",
      "components/footer",
      "components/undo_toast",
      "components/cookie_consent"
    ]

    components_to_load = components || default_components

    capture do
      components_to_load.each do |component|
        concat stylesheet_link_tag(component, "data-turbo-track": "reload")
      end
    end
  end

  # 機能固有のスタイルシートを読み込む
  def render_feature_stylesheets(features: [])
    return "" if features.empty?

    capture do
      features.each do |feature|
        concat stylesheet_link_tag(feature, "data-turbo-track": "reload")
      end
    end
  end

  # 共通JavaScriptを読み込む
  def render_common_javascripts(include_shared_systems: true)
    capture do
      concat javascript_include_tag("application", "data-turbo-track": "reload", type: "module")
      concat javascript_include_tag("i18n_helper", "data-turbo-track": "reload", defer: true)

      if include_shared_systems
        concat javascript_include_tag("shared/notification_system", "data-turbo-track": "reload", defer: true)
        concat javascript_include_tag("shared/dialog_system", "data-turbo-track": "reload", defer: true)
        concat javascript_include_tag("shared/loading_system", "data-turbo-track": "reload", defer: true)
      end
    end
  end

  def spa_private_plan_url(plan_id)
    "#{spa_frontend_origin}/plans/#{plan_id}"
  end

  def spa_private_plan_optimizing_url(plan_id)
    "#{spa_private_plan_url(plan_id)}/optimizing"
  end

  def spa_private_plan_select_crop_path
    "#{spa_frontend_origin}/plans/select-crop"
  end

  def spa_private_plan_new_path
    "#{spa_frontend_origin}/plans/new"
  end

  def spa_private_plans_path
    "#{spa_frontend_origin}/plans"
  end

  def spa_public_plans_new_path
    "#{spa_frontend_origin}/public-plans/new"
  end

  def spa_frontend_origin
    Adapters::Auth::SpaAuthRedirect.default_origin
  end

  def spa_masters_farms_path
    "#{spa_frontend_origin}/farms"
  end

  def spa_masters_crops_path
    "#{spa_frontend_origin}/crops"
  end

  def spa_masters_fertilizes_path
    "#{spa_frontend_origin}/fertilizes"
  end

  def spa_masters_pesticides_path
    "#{spa_frontend_origin}/pesticides"
  end

  def spa_masters_pests_path
    "#{spa_frontend_origin}/pests"
  end

  def spa_masters_agricultural_tasks_path
    "#{spa_frontend_origin}/agricultural_tasks"
  end

  def spa_masters_interaction_rules_path
    "#{spa_frontend_origin}/interaction_rules"
  end

  def spa_api_keys_path
    "#{spa_frontend_origin}/api-keys"
  end
end
