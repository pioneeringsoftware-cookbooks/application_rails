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

# https://tickets.opscode.com/browse/COOK-4039
gem_package 'rake' do
  action :install
  options('--force')
end

data_bag('application_rails').each do |name|
  item = data_bag_item('application_rails', name)
  application name do
    %w(repository deploy_key revision).each do |method|
      string = item[method] || node[method]
      send(method.to_sym, string) if string
    end
    path File.join(item['path'] || node['application_rails']['root'], name)
    env = node['rack_env'] || node['application_rails']['env']
    environment_name env
    db = node['application_rails']['database'].dup
    db.merge!(node['application_rails']['databases'][name] || {})

    # Note that the default database name derives from the Chef environment
    # name, the application name plus the Rack environment name, all delimited
    # by underscores. Chef environment names may include dashes. Database names
    # (e.g. for PostgreSQL) may not include dashes. Substitute dashes for
    # underscores.
    db['database'] ||= "#{node.chef_environment.gsub('-', '_')}_#{name}_#{env}"

    if node['postgresql'] && (password_hash = node['postgresql']['password'])
      username, password = password_hash.first
      db['username'] ||= username
      db['password'] ||= password
    end

    rails do
      gems %w(bundler)
      database do
        %w(adapter host database username password encoding).each do |method|
          arg = db[method]
          send(method.to_sym, arg) if arg
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
        bundler true
        restart_command do
          init_script = File.join('etc', 'init.d', name)
          execute "#{init_script} hup" do
            user 'root'
            only_if { File.exist?(init_script) }
          end
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

  directory File.join(resources("application[#{name}]").path, 'current', 'tmp', 'pids') do
    recursive true
  end
end
