# frozen_string_literal: true

class User < ApplicationRecord
  include Discard::Model

  devise :database_authenticatable, :validatable, :recoverable

  # Associations
  has_many :businesses, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_many :bookings_as_staff, class_name: "Booking", foreign_key: "staff_id", dependent: :nullify
  has_many :reviews, dependent: :destroy
  has_many :business_staff, dependent: :destroy
  has_many :staff_businesses, through: :business_staff, source: :business
  has_many :staff_availabilities, dependent: :destroy
  has_many :staff_unavailabilities, dependent: :destroy
  has_many :staff_services, foreign_key: :staff_id, dependent: :destroy
  has_many :services_as_staff, through: :staff_services, source: :service

  # Attachments
  mount_uploader :avatar, ImageUploader

  ALLOWED_ADMIN_ROLES = ["superadmin", "support", "moderator", "finance", "technical_admin"].freeze

  # Validations (Devise :validatable covers email and password; we keep app-specific ones)
  validates :first_name, presence: true, length: { maximum: 100 }
  validates :last_name, length: { maximum: 100 }, allow_blank: true
  validates :role, inclusion: { in: ["customer", "provider", "admin"] }
  validates :admin_role, inclusion: { in: ALLOWED_ADMIN_ROLES }, allow_nil: true
  validates :phone, format: { with: /\A\+?[\d\s-]+\z/, allow_blank: true }
  validates :locale, inclusion: { in: ["en", "fr", "ar"] }, allow_nil: true
  validates :provider_status, inclusion: { in: ["confirmed", "not_confirmed"] }, allow_nil: true

  # Callbacks
  before_save :downcase_email
  before_save :sync_name_from_first_last

  # Enums
  enum :role, { customer: "customer", provider: "provider", admin: "admin" }, prefix: true

  # Scopes
  scope :active, -> { kept }
  scope :providers, -> { where(role: :provider) }
  scope :customers, -> { where(role: :customer) }
  scope :admins, -> { where(role: :admin) }
  scope :superadmins, -> { where(admin_role: "superadmin") }
  scope :support, -> { where(admin_role: "support") }
  scope :moderator, -> { where(admin_role: "moderator") }
  scope :finance, -> { where(admin_role: "finance") }
  scope :technical_admin, -> { where(admin_role: "technical_admin") }

  # Role helpers
  def admin?
    role_admin?
  end

  def provider?
    role_provider?
  end

  def customer?
    role_customer?
  end

  def can_manage_business?(business)
    admin? || business.user_id == id || business_staff.exists?(business_id: business.id)
  end

  # Check if user is staff member of a business
  def staff_of?(business)
    business_staff.exists?(business_id: business.id)
  end

  # Get user's role at a specific business
  def role_at(business)
    business_staff.find_by(business_id: business.id)&.role
  end

  # Staff: can access admin panel (role=admin and admin_role in allowed list, or legacy admin with nil admin_role)
  def can_access_admin?
    return false unless role_admin?

    admin_role.present? ? ALLOWED_ADMIN_ROLES.include?(admin_role) : true
  end

  def staff?
    can_access_admin?
  end

  def provider_confirmed?
    return true if role_admin? # Admins bypass
    return true unless role_provider?

    provider_status == "confirmed"
  end

  # Premium: provider with at least one business that has premium (for dashboard access)
  def premium?
    return true if role_admin? # Admins bypass

    role_provider? && businesses.any?(&:premium?)
  end

  alias provider_premium? premium?

  # Full name from first + last (name column kept in sync for backward compatibility)
  def name
    [first_name, last_name].compact.join(" ").strip.presence || read_attribute(:name)
  end

  def name=(value)
    parts = value.to_s.strip.split(/\s+/, 2)
    self.first_name = parts[0].presence || first_name
    self.last_name = parts[1].presence
    write_attribute(:name, [first_name, last_name].compact.join(" ").strip)
  end

  private

  def downcase_email
    self.email = email.downcase if email.present?
  end

  def sync_name_from_first_last
    return if first_name.blank?

    write_attribute(:name, [first_name, last_name].compact.join(" ").strip)
  end
end
