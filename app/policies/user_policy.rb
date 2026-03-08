# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def index?
    admin?
  end

  def show?
    admin? || owner?
  end

  def create?
    admin?
  end

  def update?
    admin? || owner?
  end

  def destroy?
    admin?
  end

  def impersonate?
    admin?
  end

  def owner?
    record.id == user&.id
  end

  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.where(id: user.id)
      end
    end
  end
end
