# frozen_string_literal: true

module Plans
  class NewPresenter
    def initialize(current_user:)
      @current_user = current_user
    end

    def current_year
      @current_year ||= Date.current.year
    end

    def available_years
      @available_years ||= ((current_year - 1)..(current_year + 1)).to_a
    end

    def farms
      @farms ||= @current_user.farms.user_owned.to_a
    end

    def default_plan_name
      I18n.t('plans.default_plan_name')
    end
  end
end


