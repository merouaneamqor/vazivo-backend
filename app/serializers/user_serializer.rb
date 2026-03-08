# frozen_string_literal: true

class UserSerializer < ActiveModel::Serializer
  include StorageUrlConcern

  attributes :id, :name, :first_name, :last_name, :email, :phone, :role, :locale, :created_at

  attribute :provider_status, if: :provider?
  attribute :premium, if: :provider?
  attribute :admin_role, if: :admin_role?

  def provider?
    object.role == "provider"
  end

  def premium
    object.premium?
  end

  attribute :avatar_url, if: :avatar_attached?

  def admin_role?
    object.admin_role.present?
  end

  def avatar_url
    return object.avatar_url if object.respond_to?(:avatar_url) && object.avatar_url.present?
    return object.avatar.url if object.avatar.present?

    nil
  end

  def avatar_attached?
    (object.respond_to?(:avatar_url) && object.avatar_url.present?) || object.avatar.present?
  end
end
