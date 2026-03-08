# frozen_string_literal: true

class OpenRouterService
  API_URL = "https://openrouter.ai/api/v1/chat/completions"
  FREE_MODEL = "deepseek/deepseek-chat-v3-0324:free"

  def initialize
    @api_key = ENV["OPENROUTER_API_KEY"]
  end

  def generate_service_description(service_name, category_name, locale: :en)
    return nil unless @api_key.present?
    prompt = build_prompt(service_name, category_name, locale)
    generate_text(prompt)
  end

  def translate_text(text, from:, to:)
    return nil unless @api_key.present?
    return text if to.to_sym == from.to_sym
    from_lang = language_name(from)
    to_lang = language_name(to)
    prompt = translate_prompt(text, from: from_lang, to: to_lang)
    generate_text(prompt)
  end

  def generate_seo_description(service_name, category_name)
    return nil unless @api_key.present?
    prompt = seo_prompt(service_name, category_name)
    generate_text(prompt)
  end

  def generate_structured_content(service_name, category_name)
    return nil unless @api_key.present?
    prompt = structured_prompt(service_name, category_name)
    raw = generate_text(prompt)
    return nil if raw.blank?
    parsed = parse_json_from_response(raw)
    parsed if parsed.is_a?(Hash)
  end

  private

  def generate_text(prompt, max_tokens: 200, temperature: 0.6)
    response = HTTParty.post(
      API_URL,
      headers: {
        "Authorization" => "Bearer #{@api_key}",
        "Content-Type" => "application/json",
        "HTTP-Referer" => ENV["APP_URL"] || "https://vazivo.com",
        "X-Title" => "Vazivo"
      },
      body: {
        model: FREE_MODEL,
        messages: [{ role: "user", content: prompt }],
        max_tokens: max_tokens,
        temperature: temperature
      }.to_json
    )

    if response.success?
      response.dig("choices", 0, "message", "content")&.strip
    else
      Rails.logger.error("OpenRouter API error: #{response.body}")
      nil
    end
  rescue StandardError => e
    Rails.logger.error("OpenRouter service error: #{e.message}")
    nil
  end

  def parse_json_from_response(raw)
    # Strip markdown code blocks if present
    str = raw.strip
    str = Regexp.last_match(1) if str.match(/\A```(?:json)?\s*([\s\S]*?)```\z/m)
    JSON.parse(str)
  rescue JSON::ParserError
    nil
  end

  def language_name(locale)
    { en: "English", fr: "French", ar: "Arabic" }.fetch(locale.to_sym, locale.to_s)
  end

  def build_prompt(service_name, category_name, locale)
    case locale.to_sym
    when :fr
      <<~PROMPT
        Tu es un expert en marketing pour les services de bien-être, spa et barbier.

        Rédige exactement UNE description professionnelle.

        Service: "#{service_name}"
        Catégorie: "#{category_name}"

        Règles:
        - 2 à 3 phrases dans un seul paragraphe, rien d'autre
        - Ton premium et professionnel
        - Met en avant détente, bien-être et qualité
        - Pas d'emojis, pas de guillemets autour du nom du service
        - Pas d'options, pas de "Option 1/2", pas de puces, pas d'étiquettes
        - Ne pas commencer par le nom du service entre guillemets

        Réponds UNIQUEMENT par le texte de la description.
      PROMPT
    when :ar
      <<~PROMPT
        أنت خبير في كتابة المحتوى التسويقي لخدمات السبا والحلاقة والعناية الشخصية.

        اكتب وصفًا واحدًا احترافيًا فقط.

        الخدمة: "#{service_name}"
        الفئة: "#{category_name}"

        القواعد:
        - 2 إلى 3 جمل في فقرة واحدة فقط، بدون أي إضافات
        - أسلوب راقٍ ومهني
        - إبراز الاسترخاء والجودة والعناية
        - بدون إيموجي أو علامات اقتباس حول اسم الخدمة
        - لا خيارات ولا "الخيار 1/2" ولا نقاط ولا عناوين
        - لا تبدأ باسم الخدمة بين علامات اقتباس

        أجب بنص الوصف فقط، ولا شيء غيره.
      PROMPT
    else
      <<~PROMPT
        You are an expert marketing copywriter for spa, wellness, and barber services.

        Write exactly ONE professional service description.

        Service name: "#{service_name}"
        Category: "#{category_name}"

        Rules:
        - Output exactly 2–3 sentences in a single paragraph
        - Premium, professional tone
        - Highlight relaxation, quality, and client benefits
        - No emojis, no quotation marks around the service name
        - No options, no "Option 1/Option 2", no bullet points, no labels
        - Do not start with the service name in quotes

        Reply with ONLY the description text, nothing else.
      PROMPT
    end
  end

  def translate_prompt(text, from:, to:)
    <<~PROMPT
      You are a professional translator. Translate the following text from #{from} to #{to}.

      Rules:
      - Output ONLY the translated text
      - No preamble, no "Translation:", no quotation marks around the result
      - Keep the same meaning and professional tone
      - One paragraph or line only

      Text to translate:
      #{text}
    PROMPT
  end

  def seo_prompt(service_name, category_name)
    <<~PROMPT
      You are an SEO expert for beauty and wellness marketplaces. Write one short SEO description.

      Service: "#{service_name}"
      Category: "#{category_name}"

      Rules:
      - 40–60 words, one paragraph only
      - Include the service name naturally once
      - Focus on benefits and experience, professional tone
      - No emojis, no options, no bullet points

      Output ONLY the description text, nothing else.
    PROMPT
  end

  def structured_prompt(service_name, category_name)
    <<~PROMPT
      You are a marketplace copywriting expert. Generate structured marketing content.

      Service: "#{service_name}"
      Category: "#{category_name}"

      Return valid JSON only, in this exact format (no markdown, no code fence):
      {"short_description":"","tagline":"","benefits":[]}

      Rules:
      - short_description: exactly 2 sentences
      - tagline: 5-8 words
      - benefits: array of exactly 3 short strings
      - Professional spa/barber tone, no emojis
      - Output only the JSON object, nothing else
    PROMPT
  end
end
