# Solid Queue configuration
# SQLite-based job queue for Rails 8

# Only configure if Solid Queue is being used
if defined?(SolidQueue)
  SolidQueue.on_thread_error = ->(exception) { Rails.error.report(exception) }
end



