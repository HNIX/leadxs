namespace :db do
  namespace :seed do
    desc "Seed just the source performance data"
    task source_performance: :environment do
      load Rails.root.join('db', 'seeds', 'source_performance_data.rb')
    end
  end
end