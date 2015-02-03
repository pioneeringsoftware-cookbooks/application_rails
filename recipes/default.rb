#
# Cookbook Name:: application_rails
# Recipe:: default
#
# Copyright (C) 2015 YOUR_NAME
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'confyaml'
include_recipe 'git'

data_bag('application_rails').each do |name|
  item = data_bag_item('application_rails', name)
  application name do
    repository item['repository']
    deploy_key item['deploy_key']
    revision item['revision'] if item['revision']
    path File.join(item['path'] || node['application_rails']['root'], name)
    env = node['rack_env'] || node['application_rails']['env']
    environment_name env
    db = node['application_rails']['databases'][name] || {}
    db['database'] ||= "#{node.chef_environment}_#{name}_#{env}"

    rails do
      gems %w(bundler)
      database do
        %i(adapter host database username password encoding).each do |method|
          arg = db[method.to_s]
          send(method, arg) if arg
        end
      end
    end

    node['confyaml']['files'].each do |key, value|
      base = File.basename(value['expand_path'])
      symlink_before_migrate.update(base => File.join('config', base))
    end
  end

  node['confyaml']['files'].each do |key, value|
    path = value['expand_path']
    base = File.basename(path)
    link File.join(resources("application[#{name}]").path, 'shared', base) do
      to path
    end
  end
end
