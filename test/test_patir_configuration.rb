$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'test/unit'

require 'patir/configuration'
module Patir
  class TestConfigurator<Test::Unit::TestCase
    def setup
      @prev_dir=Dir.pwd
      Dir.chdir(File.dirname(__FILE__))
    end
    def teardown
      Dir.chdir(@prev_dir)
    end
    def test_configuration
      c=Patir::Configurator.new("samples/empty.cfg")
      assert_equal(c.configuration,c)
      
      c=Patir::Configurator.new("samples/chain.cfg")
      assert_equal(c.configuration,c)
    end
    def test_raise_configuration
      assert_raise(Patir::ConfigurationException) { Patir::Configurator.new("samples/failed.cfg")}
      assert_raise(Patir::ConfigurationException) { Patir::Configurator.new("samples/failed_unknown.cfg")}
      assert_raise(Patir::ConfigurationException) { Patir::Configurator.new("samples/syntax.cfg")}
      assert_raise(Patir::ConfigurationException) { Patir::Configurator.new("samples/config_fail.cfg")}
    end
  end
end