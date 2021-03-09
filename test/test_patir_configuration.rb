# Copyright (c) 2012-2021 Vassilis Rizopoulos. All rights reserved.

# frozen_string_literal: true

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), "..", "lib")

require "minitest/autorun"

require "patir/configuration"

module Patir
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
    # Verify that configuration files can be parsed
    def test_configuration
      c = Patir::Configurator.new("samples/empty.cfg")
      assert_equal(c.configuration, c)

      c = Patir::Configurator.new("samples/chain.cfg")
      assert_equal(c.configuration, c)
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
