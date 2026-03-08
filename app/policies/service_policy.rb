# frozen_string_literal: true

class ServicePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    user.present? && BusinessPolicy.new(user, record.business).owner?
  end

  def update?
    user.present? && (owner? || admin?)
  end

  def destroy?
    user.present? && (owner? || admin?)
  end

  def availability?
    true
  end

  def owner?
    actual_user = user.is_a?(Hash) ? user[:user] : user
    record.business&.user_id == actual_user&.id
  end

  class Scope < Scope
    def resolve
      scope.kept.joins(:business).merge(Business.kept)
    end
  end
end
