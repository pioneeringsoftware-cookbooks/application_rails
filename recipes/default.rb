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
include_recipe 'runit'

data_bag('application_rails').each do |name|
  item = data_bag_item('application_rails', name)
  application name do
    %i(repository deploy_key revision).each do |method|
      string = item[method.to_s]
      send(method, string) if string
    end
    path File.join(item['path'] || node['application_rails']['root'], name)
    env = node['rack_env'] || node['application_rails']['env']
    environment_name env
    db = node['application_rails']['database'].dup
    db.merge!(node['application_rails']['databases'][name] || {})
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

    if item['unicorn']
      owner 'root'
      group 'root'
      unicorn do
        options do
          rails_env env
        end
      end
    end

    # Connect any YAML (or JSON) configuration files to the application. Make
    # them available via symbolic links. The `application` cookbook's
    # limitations make two levels of linkage necessary. The first links the
    # files from `/etc/conf` to `shared` and the second links from `shared` to
    # `config`.
    node['confyaml']['files'].each do |key, value|
      base = File.basename(value['expand_path'])
      symlink_before_migrate.update(base => File.join('config', base))
    end
  end

  # Sym-link from `/etc/conf` to `shared`.
  node['confyaml']['files'].each do |key, value|
    path = value['expand_path']
    base = File.basename(path)
    link File.join(resources("application[#{name}]").path, 'shared', base) do
      to path
    end
  end
end
