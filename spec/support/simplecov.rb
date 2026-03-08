# frozen_string_literal: true

if ENV["COVERAGE"]
  require "simplecov"
  require "simplecov-json"

  SimpleCov.start "rails" do
    add_filter "/spec/"
    add_filter "/config/"
    add_filter "/vendor/"
    add_filter "/db/"

    add_group "Controllers", "app/controllers"
    add_group "Models", "app/models"
    add_group "Services", "app/services"
    add_group "Serializers", "app/serializers"
    add_group "Policies", "app/policies"
    add_group "Presenters", "app/presenters"
    add_group "Jobs", "app/jobs"
    add_group "Mailers", "app/mailers"

    minimum_coverage 80
    minimum_coverage_by_file 70

    formatter SimpleCov::Formatter::MultiFormatter.new([
                                                         SimpleCov::Formatter::HTMLFormatter,
                                                         SimpleCov::Formatter::JSONFormatter,
                                                       ])
  end
end
