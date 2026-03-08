# frozen_string_literal: true

class ReviewPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    user.present? && user.customer?
  end

  def update?
    user.present? && owner?
  end

  def destroy?
    user.present? && (owner? || admin?)
  end

  def owner?
    record.user_id == user&.id
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
