# -*- ruby -*-
$:.unshift File.join(File.dirname(__FILE__),"lib")
require 'hoe'
require 'patir/base'

Hoe.spec('patir') do |prj|
  developer("Vassilis Rizopoulos", "vassilisrizopoulos@gmail.com")
  license "MIT"
  prj.version = Patir::Version::STRING
  prj.summary='patir (Project Automation Tools in Ruby) provides libraries for use in project automation tools'
  prj.urls={ 'home' => 'http://github.com/damphyr/patir' }
  prj.description=prj.paragraphs_of('README.md',1..4).join("\n\n")
  prj.local_rdoc_dir='doc/rdoc'
  prj.readme_file="README.md"
  prj.extra_deps<<["systemu", "~>2.6"]
end

# vim: syntax=Ruby
