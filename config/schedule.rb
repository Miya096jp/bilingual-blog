env :PATH, ENV["PATH"]
set :environment, ENV["RAILS_ENV"] || "production"
set :output, "log/cron.log"

every 1.day, at: "3:00 am" do
  rake "storage:cleanup_unattached"
end

every :monday, at: "4:00 am" do
  rake "storage:stats"
end
