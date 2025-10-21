Rails.application.config.generators do |generator|
  # Generate migrations with UUID primary keys
  generator.orm :active_record, primary_key_type: :uuid
end
