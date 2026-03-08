# frozen_string_literal: true

json.providers @providers do |provider|
  json.merge! provider.deep_stringify_keys
end

json.meta do
  json.merge! @meta.deep_stringify_keys
end
