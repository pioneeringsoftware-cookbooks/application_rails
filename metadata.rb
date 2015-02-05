name             'application_rails'
maintainer       'YOUR_NAME'
maintainer_email 'YOUR_EMAIL'
license          'All rights reserved'
description      'Installs/Configures application_rails'
long_description 'Installs/Configures application_rails'
version          '0.1.6'

%w(application_ruby confyaml git runit).each do |cb|
  depends cb
end
