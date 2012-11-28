# -*- ruby -*-
$:.unshift File.join(File.dirname(__FILE__),"lib")
require 'hoe'
require 'patir/base'

Hoe.plugins.delete :compiler

Hoe.spec('patir') do
  self.version = Patir::Version::STRING
  self.rubyforge_name = 'patir'
  self.author = "Vassilis Rizopoulos"
  self.email = "vassilisrizopoulos@gmail.com"
  self.summary = 'patir (Project Automation Tools in Ruby) provides libraries for use in project automation tools'
  self.description = paragraphs_of('README.md', 1..4).join("\n\n")
  self.urls = ["http://patir.rubyforge.org","http://github.com/damphyr/patir"]
  self.changes = paragraphs_of('History.txt', 0..1).join("\n\n")
  extra_deps<<['systemu',"~>2.5"]
end

# vim: syntax=Ruby
