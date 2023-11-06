# Copyright (c) 2012-2021 Vassilis Rizopoulos. All rights reserved.

# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require_relative "../lib/patir/base"

##
# Verify the basic functionality contained directly in the Patir module
class TestBase < Minitest::Test
  ##
  # Path to a temporary file used for logging tests
  TEMP_LOG = "temp.log"
  private_constant(:TEMP_LOG)

  ##
  # Clean-up actions after completed test cases
  def teardown
    FileUtils.rm_rf(TEMP_LOG)
  end

  ##
  # Verify that the $DEBUG global is correctly handled on initialization
  def test_setup_logger_debug_global
    debug_prev = $DEBUG
    $DEBUG = false
    logger = Patir.setup_logger(nil, Logger::FATAL)
    assert_equal(Logger::FATAL, logger.level)
    $DEBUG = true
    logger = Patir.setup_logger(nil, Logger::FATAL)
    assert_equal(Logger::DEBUG, logger.level)
    $DEBUG = debug_prev
  end

  ##
  # Verify correct setup of the logger with default arguments
  def test_setup_logger_call_with_defaults
    logger = Patir.setup_logger
    assert_instance_of(Patir::PatirLoggerFormatter, logger.formatter)
    assert_equal(Logger::INFO, logger.level)
  end

  ##
  # Verify that the log output is being handled correctly
  def test_setup_logger_file_handling
    logger = Patir.setup_logger(nil)
    assert_instance_of(Logger, logger)
    refute(File.exist?(TEMP_LOG), "Log file created")
    logger = Patir.setup_logger("temp.log")
    assert_instance_of(Logger, logger)
    assert(File.exist?(TEMP_LOG), "Log file not created")
    logger.close
  end

  ##
  # Verify that loglevels are set correctly
  def test_setup_logger_loglevels
    params = [
      # Check default value
      { :arg => nil, :lvl => Logger::INFO },
      # Check all Logger::Severity values
      { :arg => Logger::DEBUG, :lvl => Logger::DEBUG },
      { :arg => Logger::ERROR, :lvl => Logger::ERROR },
      { :arg => Logger::FATAL, :lvl => Logger::FATAL },
      { :arg => Logger::INFO, :lvl => Logger::INFO },
      { :arg => Logger::UNKNOWN, :lvl => Logger::UNKNOWN },
      { :arg => Logger::WARN, :lvl => Logger::WARN },
      # Check the three handled symbols
      { :arg => :mute, :lvl => Logger::FATAL },
      { :arg => :silent, :lvl => Logger::WARN },
      { :arg => :debug, :lvl => Logger::DEBUG }
    ]
    params.each do |param|
      logger = Patir.setup_logger(nil, param[:arg])
      assert_equal(param[:lvl], logger.level)
    end
  end
end

##
# Verify functionality of the Patir::PatirLoggerFormatter class
class TestPatirLoggerFormatter < Minitest::Test
  ##
  # Check formatting with a few random message and severity combinations
  def test_formatting
    formatter = Patir::PatirLoggerFormatter.new

    # Try some Logger::Severity enumerators
    assert_match(/^\[\d{8} \d{2}:\d{2}:\d{2}\]     0: Some vain information\n$/,
                 formatter.call(Logger::DEBUG, Time.now, "IGNORED",
                                "Some vain information"))
    assert_match(/^\[\d{8} \d{2}:\d{2}:\d{2}\]     4: Some bad information\n$/,
                 formatter.call(Logger::FATAL, Time.now, "IGNORED",
                                "Some bad information"))
    assert_match(/^\[\d{8} \d{2}:\d{2}:\d{2}\]     1: Some information\n$/,
                 formatter.call(Logger::INFO, Time.now, "IGNORED",
                                "Some information"))

    # Try random integers (small and big)
    assert_match(/^\[\d{8} \d{2}:\d{2}:\d{2}\]   291: Ugh, what's this\?\n$/,
                 formatter.call(291, Time.now, "IGNORED",
                                "Ugh, what's this?"))
    assert_match(/^\[\d{8} \d{2}:\d{2}:\d{2}\] 2125916: Wow, that must be pretty important\n$/,
                 formatter.call(2125916, Time.now, "IGNORED",
                                "Wow, that must be pretty important"))
  end

  ##
  # Verify that new Patir::PatirLoggerFormatter instances are initialized
  # correctly
  def test_initialization
    formatter = Patir::PatirLoggerFormatter.new
    assert_equal("%Y%m%d %H:%M:%S", formatter.datetime_format)
  end
end

##
# Verify functionality of the Patir::Version module
class TestVersion < Minitest::Test
  ##
  # Verify that the version's string representation is created correctly
  def test_string_representation
    assert_equal("0.9.1", Patir::Version::STRING)
  end
end
