# frozen_string_literal: true

class ApplicationPolicy
  # pundit_user can be a User or a hash { user:, impersonator:, request:, params:, time: }; unwrap so policies always get the User
  def self.resolve_user(pundit_context)
    return pundit_context if pundit_context.respond_to?(:admin?)

    if pundit_context.is_a?(Hash)
      return pundit_context[:user] if pundit_context.key?(:user)
      return pundit_context["user"] if pundit_context.key?("user")
    end
    pundit_context
  end

  def initialize(pundit_context, record)
    @pundit_context = pundit_context
    @record = record
  end

  def user
    @user ||= self.class.resolve_user(@pundit_context)
  end

  attr_reader :record

  # Dynamic policy context: request, params, time, feature_flags, etc. Use in policies for runtime rules.
  def context
    return {} unless @pundit_context.is_a?(Hash)

    @context ||= @pundit_context.except(:user, "user", :impersonator, "impersonator").with_indifferent_access
  end

  def request
    context[:request]
  end

  def params
    context[:params] || {}
  end

  def current_time
    context[:time] || Time.current
  end

  def index?
    true
  end

  def show?
    true
  end

  def create?
    user.present?
  end

  def new?
    create?
  end

  def update?
    user.present? && (owner? || admin?)
  end

  def edit?
    update?
  end

  def destroy?
    user.present? && (owner? || admin?)
  end

  def admin?
    user&.admin?
  end

  def provider?
    user&.provider? || admin?
  end

  def customer?
    user&.customer?
  end

  def owner?
    false
  end

  class Scope
    def initialize(pundit_context, scope)
      @pundit_context = pundit_context
      @scope = scope
    end

    def user
      @user ||= ApplicationPolicy.resolve_user(@pundit_context)
    end

    def resolve
      scope.all
    end

    private

    attr_reader :scope
  end
end
