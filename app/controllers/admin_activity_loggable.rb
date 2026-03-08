# frozen_string_literal: true

module AdminActivityLoggable
  extend ActiveSupport::Concern

  # Log an admin action. details can be a Hash (e.g. { message: "..." }) or a string.
  # For :update actions, pass the saved resource as update_resource: record to include
  # which attributes changed in the details (global behavior for all update logs).
  def log_admin_action(action, resource_type, resource_id = nil, details: {}, update_resource: nil)
    return unless current_user.present?

    final_details = normalize_details(details, action, resource_type, resource_id, update_resource)
    AdminActivityLog.create!(
      admin_user_id: current_user.id,
      action: action.to_s,
      resource_type: resource_type.to_s,
      resource_id: resource_id.to_s.presence,
      details: final_details
    )
  rescue StandardError => e
    Rails.logger.warn("[AdminActivityLog] Failed to log: #{e.message}")
  end

  private

  def normalize_details(details, action, resource_type, resource_id, update_resource)
    base = details.is_a?(Hash) ? details : { message: details.to_s }
    return base unless action.to_s == "update" && update_resource.present?

    previous_changes = update_resource.respond_to?(:previous_changes) ? update_resource.previous_changes : {}
    changed = (previous_changes || {}).except("updated_at")
    return base if changed.blank?

    keys = changed.keys.map { |k| k.to_s.humanize.downcase }
    resource_label = resource_type.to_s.singularize
    id_part = resource_id.present? ? " ##{resource_id}" : ""
    base.merge(message: "Updated #{resource_label}#{id_part}: #{keys.join(', ')}", changed: keys)
  end
end
