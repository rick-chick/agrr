# frozen_string_literal: true

class UserResourceLimitValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return unless record.user
    
    # Get the model name and limit from options
    model_class = options[:model_name] || record.class
    max_count = options[:max_count] || 4
    
    # Handle both class and string
    model_class = model_class.constantize if model_class.is_a?(String)
    association_name = model_class.name.underscore.pluralize.to_sym
    
    # Don't validate for reference records
    if record.respond_to?(:is_reference) && record.is_reference
      return
    end
    
    # Get the association scope
    association = record.user.association(association_name)
    scope = association.klass.where(user: record.user)
    
    # Don't count the current record if it's being updated
    scope = scope.where.not(id: record.id) if record.persisted?
    
    existing_count = scope.count
    
    if existing_count >= max_count
      model_name = I18n.t("activerecord.models.#{model_class.name.underscore}.one", default: model_class.name)
      record.errors.add(
        :base, 
        "作成できる#{model_name}は#{max_count}件までです"
      )
    end
  end
end
