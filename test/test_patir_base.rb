$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'test/unit'
require 'patir/base.rb'

class TestBase<Test::Unit::TestCase
  TEMP_LOG="temp.log"
  def teardown
    #clean up 
    File.delete(TEMP_LOG) if File.exists?(TEMP_LOG)
  end
  
  #This is not actually testing anything meaningfull but can be expanded when we learn more about 
  #the logger
  def test_setup_logger
    logger=Patir.setup_logger
    assert_not_nil(logger)
    logger=Patir.setup_logger(nil,:silent)
    assert_not_nil(logger)
    logger=Patir.setup_logger("temp.log",:silent)
    assert_not_nil(logger)
    assert(File.exists?(TEMP_LOG), "Log file not created")
    logger.close
  end
  
end