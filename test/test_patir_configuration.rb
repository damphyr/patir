# Copyright (c) 2007-2020 Vassilis Rizopoulos. All rights reserved.

# frozen_string_literal: true

require 'minitest/autorun'

require_relative '../lib/patir/configuration'

##
# A wrapper for Logger just intended for the testing of Configurator
class TestLogger < Logger
end

module Patir::Test
  ##
  # Mock for a class derived from Configurator
  class MockConfiguratorDescendant < ::Patir::Configurator
    attr_accessor :another_number, :some_number, :some_string, :some_values
  end

  ##
  # Class for testing Patir::Configurator
  class Configurator < Minitest::Test
    ##
    # Prepare for testcase by changing into the directory containing the test
    #
    # This is needed so that the sample configurations which are specified
    # relative to the test cases are accessible by the tests.
    def setup
      @prev_dir = Dir.pwd
      Dir.chdir(File.dirname(__FILE__))
    end

    ##
    # Change back to the working directory before the #setup method
    def teardown
      Dir.chdir(@prev_dir)
    end

    ##
    # Verify that chained configurations are correctly loaded
    def test_chained_configuration_loading
      c = MockConfiguratorDescendant.new('samples/chain.cfg')
      assert_equal(4, c.another_number)
      assert_equal(5, c.some_number)
      assert_equal('ABC', c.some_string)
      assert_equal({ a: 28, b: 'Hi' }, c.some_values)
    end

    ##
    # Verify that a configuration is correctly loaded
    def test_configuration_loading
      c = MockConfiguratorDescendant.new('samples/valid.cfg')
      assert_equal(nil, c.another_number)
      assert_equal(5, c.some_number)
      assert_equal('ABC', c.some_string)
      assert_equal({ a: 28, b: 'Hi' }, c.some_values)
    end

    ##
    # Verify the initialization with a logger being passed
    def test_initialization_with_logger
      c = Patir::Configurator.new('samples/empty.cfg', TestLogger.new(STDOUT))
      assert_equal('samples/empty.cfg', c.config_file)
      assert_instance_of(TestLogger, c.logger)
      assert_equal(File.dirname(__FILE__) + '/samples', c.wd)
    end

    ##
    # Verify the initialization without a logger being passed
    def test_initialization_without_logger
      c = Patir::Configurator.new('samples/empty.cfg')
      assert_equal('samples/empty.cfg', c.config_file)
      assert_instance_of(Logger, c.logger)
      assert_equal(File.dirname(__FILE__) + '/samples', c.wd)
    end

    ##
    # Verify that exceptions of any type raised are passed on
    def test_raise_anything
      exc = assert_raises(Patir::ConfigurationException) do
        Patir::Configurator.new('samples/failed.cfg')
      end
      assert_equal('boohoo', exc.message)
    end

    ##
    # Verify that a ConfigurationException raised during loading is passed on
    def test_raise_configurationexception
      exc = assert_raises(Patir::ConfigurationException) do
        Patir::Configurator.new('samples/config_fail.cfg')
      end
      assert_equal('because I can', exc.message)
    end

    ##
    # Verify that ConfigurationException is raised on a NoMethodError
    def test_raise_nomethoderror
      exc = assert_raises(Patir::ConfigurationException) do
        Patir::Configurator.new('samples/failed_unknown.cfg')
      end
      assert_match(%r{Encountered an unknown directive in configuration file 'samples/failed_unknown.cfg':\nundefined method `foo=' for #<Patir::Configurator:0x\w+>}, exc.message)
    end

    ##
    # Verify that ConfigurationException is raised on a syntax error
    def test_raise_syntax_error
      exc = assert_raises(Patir::ConfigurationException) do
        Patir::Configurator.new('samples/syntax.cfg')
      end
      assert_equal("Syntax error in the configuration file 'samples/syntax.cfg'" \
                   ":\n#{File.expand_path('../lib/patir', __dir__)}" \
                   '/configuration.rb:135: syntax error,' \
                   " unexpected end-of-input, expecting '}'",
                   exc.message)
    end
  end
end
