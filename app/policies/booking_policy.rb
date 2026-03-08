# frozen_string_literal: true

class BookingPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present? && (customer_owner? || business_owner? || admin?)
  end

  def create?
    # Allow guest booking (unauthenticated) or authenticated user
    true
  end

  def update?
    user.present? && (business_owner? || admin?)
  end

  def destroy?
    user.present? && (customer_owner? || business_owner? || admin?)
  end

  def cancel?
    user.present? && (customer_owner? || business_owner? || admin?)
    # Dynamic rule example (context.current_time): e.g. forbid customer cancel < 24h before start:
    # return false if customer_owner? && !admin? && record.start_time && (record.start_time - current_time) < 24.hours
  end

  def confirm?
    user.present? && (business_owner? || admin?)
  end

  def complete?
    user.present? && (business_owner? || admin?)
  end

  def customer_owner?
    user.present? && record.user_id == user.id
  end

  def business_owner?
    record.business&.user_id == user&.id
  end

  class Scope < Scope
    def resolve
      return scope.none if user.blank?

      if user.admin?
        scope.all
      elsif user.provider?
        scope.joins(:business).where(businesses: { user_id: user.id })
          .or(scope.where(user_id: user.id))
      else
        scope.where(user_id: user.id)
      end
    end
  end
end
