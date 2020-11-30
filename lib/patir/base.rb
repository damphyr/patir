# Copyright (c) 2007-2020 Vassilis Rizopoulos. All rights reserved.

require 'logger'

#This is the base module of the Patir system. It contains some usefull helper methods used by all child projects.
module Patir
  #The Patir version used
  module Version
    MAJOR=0
    MINOR=9
    TINY=0
    STRING=[ MAJOR, MINOR, TINY ].join( "." )  	
  end
  #Error thrown usually in initialize methods when missing required parameters
  #from the initialization hash.
  class ParameterException<RuntimeError
  end
  
  class PatirLoggerFormatter<Logger::Formatter
    Format="[%s] %5s: %s\n"
    def initialize
      @datetime_format="%Y%m%d %H:%M:%S"
    end
    
    def call severity, time, progname, msg
      Format % [format_datetime(time), severity,
        msg2str(msg)]
    end
  end

  ##
  # Set up a default logger for usage by top-level scripts and library users
  #
  # This creates a default logger fit for the usage with and around Patir.
  #
  # +mode+ can be
  # * +:mute+ to set the level to +FATAL+
  # * +:silent+ to set the level to +WARN+
  # * +:debug+ to set the level to +DEBUG+. Debug is set also if $DEBUG is
  #   +true+
  #
  # The default log level is +INFO+.
  def self.setup_logger(filename = nil, mode = nil)
    logger = if filename
               Logger.new(filename)
             else
               Logger.new(STDOUT)
             end
    logger.level = Logger::INFO
    if [Logger::INFO, Logger::FATAL, Logger::WARN, Logger::DEBUG].member?(mode)
      logger.level = mode
    end
    logger.level = Logger::FATAL if mode == :mute
    logger.level = Logger::WARN if mode == :silent
    logger.level = Logger::DEBUG if mode == :debug || $DEBUG
    logger.formatter = PatirLoggerFormatter.new
    logger
  end
end
