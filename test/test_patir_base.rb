# Copyright (c) 2007-2020 Vassilis Rizopoulos. All rights reserved.

$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require "minitest/autorun"
require 'patir/base.rb'

class TestBase<Minitest::Test
  TEMP_LOG="temp.log"
  def teardown
    #clean up 
    File.delete(TEMP_LOG) if File.exist?(TEMP_LOG)
  end
  
  #This is not actually testing anything meaningfull but can be expanded when we learn more about 
  #the logger
  def test_setup_logger
    logger=Patir.setup_logger
    refute_nil(logger)
    logger=Patir.setup_logger(nil,:silent)
    refute_nil(logger)
    logger=Patir.setup_logger("temp.log",:silent)
    refute_nil(logger)
    assert(File.exist?(TEMP_LOG), "Log file not created")
    logger.close
  end
  
end

##
# Test Patir::Version
class TestVersion < Minitest::Test
  ##
  # Verify that the version data is correctly set
  def test_version_data
    assert_equal(0, Patir::Version::MAJOR)
    assert_equal(9, Patir::Version::MINOR)
    assert_equal(0, Patir::Version::TINY)
    assert_equal('0.9.0', Patir::Version::STRING)
  end
end
