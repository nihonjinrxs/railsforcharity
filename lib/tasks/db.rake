namespace :db do
  desc "Refresh database, drop, create and migrate"
  task :refresh => [:development_environment_only, :drop, :create, :migrate, :import_skills]

  desc "Refresh database and prepare test database"
  task :test_refresh => [:drop, :create, :migrate, :import_skills, Rake::Task['test:prepare']]

  desc "Raise an error unless the Rails.env is development"
  task :development_environment_only do
    raise "Hey, development only, you monkey!" unless Rails.env.development?
  end

  desc "Importing skills data"
  task :import_skills do
    Rake::Task["data:import_skills"].execute
  end
end
