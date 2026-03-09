# frozen_string_literal: true

# Best cleanup workflow: run code-quality tools in order to reveal
# dead models, unused helpers, unused service classes, unused controllers.
#
# Usage:
#   bundle exec rake code_quality:cleanup
#
# Or run steps individually:
#   bundle exec rake code_quality:debride
#   bundle exec rake code_quality:rails_best_practices
#   bundle exec rake code_quality:rubycritic
#   bundle exec rake code_quality:rubocop
#
# In Docker:
#   docker compose run --no-deps api bundle exec rake code_quality:cleanup
#
namespace :code_quality do
  desc "Run debride on app/ (finds potentially dead code)"
  task debride: :environment do
    sh "bundle exec debride app/", verbose: false
  end

  desc "Run rails_best_practices on the project"
  task rails_best_practices: :environment do
    sh "bundle exec rails_best_practices .", verbose: false
  end

  desc "Run rubycritic (complexity, duplication, smells; report in tmp/rubycritic)"
  task rubycritic: :environment do
    sh "bundle exec rubycritic .", verbose: false
  end

  desc "Run rubocop"
  task rubocop: :environment do
    sh "bundle exec rubocop", verbose: false
  end

  desc "Run full cleanup workflow: debride → rails_best_practices → rubycritic → rubocop"
  task cleanup: :environment do
    [
      ["Debride (dead/unused code in app/)", "bundle exec debride app/"],
      ["Rails Best Practices", "bundle exec rails_best_practices ."],
      ["RubyCritic", "bundle exec rubycritic ."],
      ["RuboCop", "bundle exec rubocop"]
    ].each_with_index do |(name, cmd), i|
      puts "\n=== #{i + 1}/4 #{name} ===\n"
      system(cmd)
      puts "--- exit #{$CHILD_STATUS.exitstatus} ---" unless $CHILD_STATUS.success?
    end
  end
end
