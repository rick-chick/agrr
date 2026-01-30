require 'yaml'
require 'json'
require 'fileutils'

def deep_merge!(target, source)
  source.each do |key, value|
    if value.is_a?(Hash) && target[key].is_a?(Hash)
      deep_merge!(target[key], value)
    else
      target[key] = value
    end
  end
  target
end

def sync_locales
  locales_dir = File.expand_path('../config/locales', __dir__)
  output_dir = File.expand_path('../frontend/src/assets/i18n', __dir__)
  
  FileUtils.mkdir_p(output_dir)
  
  merged_data = {
    'ja' => {},
    'en' => {},
    'in' => {}
  }
  
  # Mapping from file suffix to merged key
  locale_map = {
    'ja' => 'ja',
    'en' => 'en',
    'us' => 'en',
    'in' => 'in'
  }
  
  Dir.glob(File.join(locales_dir, '**/*.yml')).each do |file|
    # Determine locale from filename (e.g. ja.yml, crops.ja.yml)
    filename = File.basename(file)
    parts = filename.split('.')
    
    # Simple ja.yml or crops.ja.yml
    locale_key = if parts.length == 2
                   parts[0]
                 else
                   parts[-2]
                 end
    
    target_locale = locale_map[locale_key]
    next unless target_locale
    
    begin
      data = YAML.load_file(file)
      if data && data.is_a?(Hash)
        # Rails YAML files start with the locale key (e.g. ja:, en:, us:)
        # We want to merge the content UNDER that key
        actual_content = data[data.keys.first]
        deep_merge!(merged_data[target_locale], actual_content) if actual_content
      end
    rescue => e
      puts "Error parsing #{file}: #{e.message}"
    end
  end
  
  merged_data.each do |locale, data|
    output_path = File.join(output_dir, "#{locale}.json")
    File.write(output_path, JSON.pretty_generate(data))
    puts "Synced #{locale}.json"
  end
end

sync_locales
