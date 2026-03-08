# frozen_string_literal: true

# Mobility 1.x: plugins block; backend and locale_accessors match Category (en, fr, ar).
Mobility.configure do
  plugins do
    backend :column
    active_record
    reader
    writer
    locale_accessors [:en, :fr, :ar]
  end
end
