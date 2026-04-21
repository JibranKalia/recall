require "recall/config"

# Apply checked-in defaults, then optional machine-local overrides.
%w[config/recall.rb config/recall.local.rb].each do |relative|
  path = Rails.root.join(relative)
  load path.to_s if File.exist?(path)
end

FileUtils.mkdir_p(Recall::Config.data_dir) unless Rails.env.test?
