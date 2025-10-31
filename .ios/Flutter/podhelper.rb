require 'fileutils'
require 'json'

def flutter_root
  File.expand_path(File.join('..', '..'))
end

def flutter_parse_config
  json = File.read(File.join(flutter_root, '.flutter-plugins-dependencies'))
  JSON.parse(json)
end

def flutter_additional_ios_build_settings(target)
  target.build_configurations.each do |config|
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
  end
end
