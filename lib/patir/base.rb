# Copyright (c) 2007-2020 Vassilis Rizopoulos. All rights reserved.

require 'logger'
#This is the base module of the Patir system. It contains some usefull helper methods used by all child projects.
module Patir
  ##
  # Exception which is thrown by children of Patir::Command if the Hash used for
  # initialization misses required arguments
  class ParameterException < RuntimeError
  end

  ##
  # Extend the default log message formatter to define an own format
  class PatirLoggerFormatter < Logger::Formatter
    ##
    # The format of the created log messages
    FORMAT = "[%s] %5s: %s\n".freeze

    ##
    # Create a new instance defining the internally held log format
    def initialize
      @datetime_format = '%Y%m%d %H:%M:%S'
    end

    ##
    # Create a formatted log message from the passed data
    def call(severity, time, _progname, msg)
      format(FORMAT, format_datetime(time), severity, msg2str(msg))
    end
  end

  ##
  # Version information of Patir
  module Version
    ##
    # The major version of Patir
    MAJOR = 0
    ##
    # The minor version of Patir
    MINOR = 9
    ##
    # The tiny version of Patir
    TINY = 0
    ##
    # The full version of Patir as a String
    STRING = [MAJOR, MINOR, TINY].join('.').freeze
  end

  #Just making Logger usage easier
  #
  #This is for use on top level scripts.
  #
  #It creates a logger just as we want it.
  #
  #mode can be
  # :mute to set the level to FATAL
  # :silent to set the level to WARN
  # :debug to set the level to DEBUG. Debug is set also if $DEBUG is true.
  #The default logger level is INFO
  def self.setup_logger(filename=nil,mode=nil)
    if filename
      logger=Logger.new(filename) 
    else
      logger=Logger.new(STDOUT)
    end
    logger.level=Logger::INFO
    logger.level=mode if [Logger::INFO,Logger::FATAL,Logger::WARN,Logger::DEBUG].member?(mode)
    logger.level=Logger::FATAL if mode==:mute
    logger.level=Logger::WARN if mode==:silent
    logger.level=Logger::DEBUG if mode==:debug || $DEBUG
    logger.formatter=PatirLoggerFormatter.new
    #logger.datetime_format="%Y%m%d %H:%M:%S"
    return logger
  end
end
