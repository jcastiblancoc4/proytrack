# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Proytrack** is a Rails 7.1 project management application for tracking projects, expenses, and collaborations. It uses **MongoDB** (via Mongoid) as the database and includes user authentication via Devise. The app is deployed to a production server using GitHub Actions.

## Technology Stack

- **Ruby**: 3.3.0
- **Rails**: 7.1.5+
- **Database**: MongoDB (Mongoid ODM)
- **Authentication**: Devise
- **Frontend**: Tailwind CSS, Importmap
- **Server**: Puma
- **Money**: money-rails (default currency: COP - Colombian Pesos)

## Development Commands

### Server & Console
```bash
# Start development server
bin/rails server
# or
bundle exec puma -C config/puma.rb

# Rails console
bin/rails console

# MongoDB console
bin/mongo_console
```

### Asset Management
```bash
# Watch and rebuild Tailwind CSS during development
bin/rails tailwindcss:watch

# Build Tailwind CSS for production
bin/rails tailwindcss:build
```

### Database
```bash
# MongoDB doesn't use migrations like ActiveRecord
# Instead, run Mongoid-specific tasks if needed
bin/rails db:mongoid:create_indexes

# Drop database (use with caution)
bin/rails db:mongoid:drop
```

### Dependencies
```bash
# Install gems
bundle install

# Update gems
bundle update
```

## Architecture & Data Model

### Core Models

The application uses **Mongoid** (MongoDB ODM) instead of ActiveRecord. Key differences:
- No migrations for schema changes
- Use `include Mongoid::Document` instead of inheriting from ApplicationRecord
- Relationships use `belongs_to`, `has_many`, but no `has_many :through` (must implement manually)
- Embedded documents are supported but not used in this app

**User** (Devise authentication)
- Has many projects (owned)
- Has many shared_projects (projects shared with them)
- Has many shared_by_me_projects (projects they've shared with others)
- Method: `shared_with_me_projects` - returns projects shared with this user

**Project** (Core entity)
- Fields: `name`, `project_identifier`, `purchase_order`, `quoted_value` (Money), `locality`
- Belongs to: `user` (owner)
- Has many: `expenses`, `shared_projects`
- Enums (via simple_enum):
  - `payment_status`: pending (0), paid (1)
  - `execution_status`: pending (0), running (1), stop (2), cancelled (3), ended (4)
- Auto-generates `project_identifier` on create: format `PROY-YYYY-NNN` (e.g., PROY-2025-001)
- Access control methods:
  - `can_access?(user)` - owner or shared user can access
  - `can_edit?(user)` - only owner can edit
  - `shared_with?(user)` - check if shared with specific user
  - `shared_with_users` - returns User collection of all users project is shared with

**Expense**
- Fields: `description`, `amount` (Money), `expense_date`
- Belongs to: `project`
- Enum: `expense_type`: payroll (0), hardware (1), fuel (2)

**SharedProject** (Join model for project sharing)
- Belongs to: `project`, `user`, `shared_by` (User who shared it)
- Validations prevent sharing with self or owner
- Unique constraint on `user_id` scoped to `project_id`

### Controllers & Authorization

- All controllers require authentication (`before_action :authenticate_user!`)
- **ProjectsController**: Implements manual authorization checks using model methods (`can_access?`, `can_edit?`)
- **SharedProjectsController**: Handles project sharing between users
- No authorization gem (CanCanCan, Pundit) is used - authorization is handled in models and controllers

### Routes

```ruby
root "home#index"
devise_for :users

resources :projects, only: [:show, :new, :create, :edit, :update, :destroy] do
  resources :expenses, except: [:show]
  resources :shared_projects, only: [:create, :destroy]
end

resources :shared_projects, only: [:index]
```

## Key Patterns & Conventions

1. **MongoDB Usage**: This app uses Mongoid, not ActiveRecord. When creating new models:
   - Include `Mongoid::Document` and `Mongoid::Timestamps`
   - Define fields with `field :name, type: Type`
   - No database migrations needed

2. **Money Fields**: Use `Money` type for currency fields (default: COP)
   ```ruby
   field :amount, type: Money, default: Money.new(0, 'COP')
   ```

3. **Enums**: Use `simple_enum` gem with Mongoid support
   ```ruby
   include SimpleEnum::Mongoid
   as_enum :status, { pending: 0, active: 1 }, field: { type: Integer, default: 0 }
   ```

4. **Project Identifier Generation**: Auto-generated via `before_validation` callback on create
   - Format: `PROY-YYYY-001` (year + sequential number)
   - Scoped per user
   - Case-insensitive uniqueness validation

5. **Authorization Pattern**: Custom methods in models (`can_access?`, `can_edit?`) called from controllers

6. **Spanish UI**: All user-facing messages, validations, and flash messages are in Spanish

## Deployment

The app auto-deploys to production server (178.156.195.249) on pushes to `main` branch via GitHub Actions.

Deployment steps (automated in `.github/workflows/deploy.yml`):
```bash
git pull origin main
bundle install --deployment --without development test
RAILS_ENV=production rails db:migrate
RAILS_ENV=production rails assets:precompile
sudo systemctl restart puma
sudo systemctl restart nginx
```

### Environment Configuration

- Development/Test: MongoDB Atlas (cloud)
- Production: Local MongoDB (127.0.0.1:27017)
- Environment variables managed via `.env` (dotenv-rails)

## Testing

No test framework is currently configured. When adding tests, consider:
- RSpec or Minitest
- Factory pattern for Mongoid documents
- MongoDB test database configuration
