# Copyright (c) 2012-2021 Vassilis Rizopoulos. All rights reserved.

# frozen_string_literal: true

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), "..", "lib")

require "minitest/autorun"

require "patir/configuration"

module Patir
  ##
  # Mock extension class of Configurator for testing its functionality
  class MockConfigurator < Patir::Configurator
    attr_accessor :a_number, :a_string, :another_string
  end

  ##
  # Verify functionality of the Configurator class
  class TestConfigurator < Minitest::Test
    ##
    # Setup tasks conducted before testcase executions
    def setup
      @prev_dir = Dir.pwd
      Dir.chdir(File.dirname(__FILE__))
    end

    ##
    # Clean-up tasks conducted after testcase executions
    def teardown
      Dir.chdir(@prev_dir)
    end

    ##
    # Verify that new instances of Configurator are created correctly
    def test_initialize
      conf = Patir::Configurator.new("samples/empty.cfg")
      assert_equal("samples/empty.cfg", conf.config_file)
      assert_kind_of(Logger, conf.logger)
      assert_equal(File.join(Dir.pwd, "samples"), conf.wd)
    end

    ##
    # Verify that configuration files can be parsed
    def test_configuration
      c = Patir::Configurator.new("samples/empty.cfg")
      assert_equal(c.configuration, c)

      c = Patir::Configurator.new("samples/chain.cfg")
      assert_equal(c.configuration, c)
    end

    ##
    # Verify that config files are read and values properly retained
    def test_configuration_loading
      conf = MockConfigurator.new("samples/empty.cfg")

      conf.load_from_file("samples/chain_some_config.cfg")
      assert_equal(5, conf.a_number)
      assert_equal("Hello!", conf.a_string)
      conf.load_from_file("samples/another_config.cfg")
      assert_equal(28, conf.a_number)
      assert_equal("Hello!", conf.a_string)
      assert_equal("Hello World!", conf.another_string)
    end

    ##
    # Verify that exceptions are raised on invalid configurations
    def test_raise_configuration
      assert_raises(Patir::ConfigurationException) do
        Patir::Configurator.new("samples/failed.cfg")
      end
      assert_raises(Patir::ConfigurationException) do
        Patir::Configurator.new("samples/failed_unknown.cfg")
      end
      assert_raises(Patir::ConfigurationException) do
        Patir::Configurator.new("samples/syntax.cfg")
      end
      assert_raises(Patir::ConfigurationException) do
        Patir::Configurator.new("samples/config_fail.cfg")
      end
    end
  end
end
