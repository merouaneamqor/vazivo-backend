# frozen_string_literal: true

namespace :db do
  desc "Terminate all active connections to the database and drop it"
  task drop_force: :environment do
    # Get current database name
    db_name = ActiveRecord::Base.connection.current_database
    puts "Terminating active connections to database: #{db_name}"

    # Get database config
    db_config = ActiveRecord::Base.connection_db_config
    config_hash = db_config.configuration_hash

    # Connect to postgres database (not the one we're dropping) to terminate connections
    postgres_config = config_hash.merge("database" => "postgres")

    ActiveRecord::Base.establish_connection(postgres_config)

    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      SELECT pg_terminate_backend(pg_stat_activity.pid)
      FROM pg_stat_activity
      WHERE pg_stat_activity.datname = '#{db_name}'
        AND pid <> pg_backend_pid();
    SQL

    puts "Connections terminated. Dropping database..."

    # Re-establish connection to original config for db:drop
    ActiveRecord::Base.establish_connection(config_hash)
    Rake::Task["db:drop"].invoke
  end
end
