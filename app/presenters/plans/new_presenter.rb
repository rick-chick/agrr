# frozen_string_literal: true

module Plans
  class NewPresenter
    def initialize(current_user:)
      @current_user = current_user
    end

    def farms
      @farms ||= @current_user.farms.user_owned.to_a
    end

    def default_plan_name
      I18n.t('plans.default_plan_name')
    end
  end
end


