if Rails.env.development?
  env_path = Rails.root.join(".env")
  if env_path.file?
    env_path.each_line do |line|
      line = line.strip
      next if line.empty? || line.start_with?("#")

      key, value = line.split("=", 2)
      next if key.blank? || value.nil? || ENV.key?(key)

      ENV[key] = value
    end
  end
end

web_push = ActiveSupport::OrderedOptions.new
web_push.public_key = ENV["VAPID_PUBLIC_KEY"]
web_push.private_key = ENV["VAPID_PRIVATE_KEY"]
web_push.subject = ENV["VAPID_SUBJECT"].presence || "https://backend-humming-coral-8012.fly.dev"
Rails.application.config.x.web_push = web_push
