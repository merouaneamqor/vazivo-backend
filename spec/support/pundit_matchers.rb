# frozen_string_literal: true

# Custom Pundit matchers for RSpec
# Usage:
#   expect(policy).to permit_action(:show)
#   expect(policy).to forbid_action(:destroy)
#   expect(policy).to permit_actions(:show, :update)
#   expect(policy).to forbid_actions(:destroy, :create)

RSpec::Matchers.define :permit_action do |action|
  match do |policy|
    policy.public_send("#{action}?")
  end

  failure_message do |policy|
    "Expected #{policy.class} to permit #{action} for #{policy.user&.role || 'nil user'}, but it didn't"
  end

  failure_message_when_negated do |policy|
    "Expected #{policy.class} to forbid #{action} for #{policy.user&.role || 'nil user'}, but it permitted"
  end
end

RSpec::Matchers.define :forbid_action do |action|
  match do |policy|
    !policy.public_send("#{action}?")
  end

  failure_message do |policy|
    "Expected #{policy.class} to forbid #{action} for #{policy.user&.role || 'nil user'}, but it permitted"
  end

  failure_message_when_negated do |policy|
    "Expected #{policy.class} to permit #{action} for #{policy.user&.role || 'nil user'}, but it didn't"
  end
end

RSpec::Matchers.define :permit_actions do |*actions|
  match do |policy|
    actions.all? { |action| policy.public_send("#{action}?") }
  end

  failure_message do |policy|
    forbidden = actions.reject { |action| policy.public_send("#{action}?") }
    "Expected #{policy.class} to permit #{actions.join(', ')} for #{policy.user&.role || 'nil user'}, but #{forbidden.join(', ')} were forbidden"
  end
end

RSpec::Matchers.define :forbid_actions do |*actions|
  match do |policy|
    actions.none? { |action| policy.public_send("#{action}?") }
  end

  failure_message do |policy|
    permitted = actions.select { |action| policy.public_send("#{action}?") }
    "Expected #{policy.class} to forbid #{actions.join(', ')} for #{policy.user&.role || 'nil user'}, but #{permitted.join(', ')} were permitted"
  end
end
