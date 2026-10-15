# perf44 (temporary): measure core-only against the same checkout and database.
if ENV['PERF44_PLUGINS_DIRECTORY'].present?
  config.redmine_plugins_directory = ENV['PERF44_PLUGINS_DIRECTORY']
end
# perf44 (temporary): a cache store per measured server so runs cannot warm each other's cache.
if ENV['PERF44_CACHE_DIR'].present?
  config.cache_store = :file_store, ENV['PERF44_CACHE_DIR']
end
