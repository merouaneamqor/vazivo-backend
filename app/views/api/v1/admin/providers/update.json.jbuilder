# frozen_string_literal: true

json.provider do
  json.merge! @provider.deep_stringify_keys
end
