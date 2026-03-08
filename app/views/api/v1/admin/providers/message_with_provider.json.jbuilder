# frozen_string_literal: true

json.message @message if @message.present?
json.provider do
  json.merge! @provider.deep_stringify_keys
end
