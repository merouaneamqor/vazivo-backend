# frozen_string_literal: true

class TranslateServiceJob < ApplicationJob
  queue_as :default

  def perform(service_id)
    service = Service.find_by(id: service_id)
    return unless service

    ai_service = OpenRouterService.new
    name_en = service.read_attribute(:name_en)

    # Translate to French
    name_fr = ai_service.translate_text(name_en, from: :en, to: :fr)
    service.update_column(:name_fr, name_fr) if name_fr.present?

    # Translate to Arabic
    name_ar = ai_service.translate_text(name_en, from: :en, to: :ar)
    service.update_column(:name_ar, name_ar) if name_ar.present?
  end
end
