# Pundit Authorization

## Overview

This app uses **Pundit** for role-based authorization with plans to add **Rolify** for advanced role management.

### Current Implementation (Active)
- **Pundit**: Authorization policies ✅ IMPLEMENTED
- Role checks via User model (`admin?`, `provider?`, `customer?`)
- Policies for Business, Booking, Service, Review, User, Category

### Future Enhancement (Ready to Install)
- **Rolify**: DB-backed roles (global + resource-specific)
- Files ready in: `db/migrate/`, `app/models/role.rb`, `config/initializers/rolify.rb`

## Installation (Rolify - Optional)

```bash
bundle install
rails db:migrate
```

## Current Role System

### Global Roles (User model)
- `admin` - Platform administrators
- `provider` - Service providers  
- `customer` - Regular customers

### Admin Sub-Roles
- `superadmin` - Full platform access
- `support` - Customer support access
- `moderator` - Content moderation
- `finance` - Financial operations
- `technical_admin` - Technical operations

## Pundit Usage (Current)

### In Controllers
```ruby
# Authorize actions
authorize @business
authorize @business, :manage_staff?
authorize User

# Scope queries
businesses = policy_scope(Business)
```

### In Policies
```ruby
class BusinessPolicy < ApplicationPolicy
  def update?
    owner? || admin?
  end

  def manage_staff?
    owner? || admin? || user.role_at(record) == "manager"
  end

  def owner?
    record.user_id == user&.id
  end
end
```

### Check Roles
```ruby
user.admin?      # => true/false
user.provider?   # => true/false
user.customer?   # => true/false
user.can_access_admin?  # => true/false (for admin panel)
```

## Controllers Using Pundit

### Provider Namespace
- ✅ `BusinessesController` - Full Pundit authorization
- ✅ `ServicesController` - Existing authorization
- ✅ `BookingsController` - Existing authorization

### Admin Namespace  
- ✅ `UsersController` - Pundit authorization
- ✅ `CategoriesController` - Pundit authorization
- ✅ `BaseController` - Role check via `require_admin_role!`

### Customer Namespace
- ✅ `BookingsController` - Pundit authorization
- ✅ `ReviewsController` - Pundit authorization

## Best Practices

1. **Always authorize in controllers**
   ```ruby
   authorize @resource
   authorize @resource, :custom_action?
   ```

2. **Use policy scopes for queries**
   ```ruby
   businesses = policy_scope(Business)
   ```

3. **Keep policies simple**
   ```ruby
   def update?
     owner? || admin?
   end
   ```

4. **Handle unauthorized in ApplicationController**
   - Already configured: `rescue_from Pundit::NotAuthorizedError, with: :forbidden`

## Dynamic policies

Policies can depend on **runtime context** (request, params, time, feature flags) so rules are dynamic instead of static.

### How it works

- `ApplicationController#pundit_user` passes a hash including `user`, `impersonator`, and **policy context**: `request`, `params`, `time`.
- Override `policy_context` in any controller to add more (e.g. `feature_flags`, `tenant`):

```ruby
# In a controller
def policy_context
  super.merge(
    feature_flags: FeatureFlags.for_user(current_user),
    tenant: current_tenant
  )
end
```

- In policies, use `context`, `request`, `params`, and `current_time`:

```ruby
# In a policy
def cancel?
  return false if customer_owner? && !admin? &&
    record.start_time && (record.start_time - current_time) < 24.hours
  user.present? && (customer_owner? || business_owner? || admin?)
end
```

### What you can use

| In policy | Description |
|-----------|-------------|
| `context` | Full hash (request, params, time, or custom keys from `policy_context`) |
| `request` | Current request (nil when policy is used outside a controller, e.g. in a service) |
| `params` | Request params (indifferent access) |
| `current_time` | `context[:time]` or `Time.current` (safe in services) |

### Using policies from services

When you call a policy from a service (e.g. `BookingPolicy.new(@user, booking)`), only the user is passed, so `request` and `params` are nil. To pass time or other context:

```ruby
# Pass a context hash as first argument (must include :user)
BookingPolicy.new({ user: @user, time: Time.current }, booking).cancel?
```

## Example: Protected Controller Action

```ruby
def update
  @business = Business.find(params[:id])
  authorize @business  # Raises Pundit::NotAuthorizedError if not allowed
  
  if @business.update(business_params)
    render json: { business: BusinessPresenter.new(@business).as_json }
  else
    render json: { errors: @business.errors.full_messages }, status: :unprocessable_content
  end
end
```

## Future: Rolify Integration

When Rolify is installed, you'll be able to:

```ruby
# Assign resource-specific roles
user.add_role(:manager, business)
user.add_role(:staff, business)

# Check roles
user.has_role?(:manager, business)

# Query by role
User.with_role(:manager, business)
```
