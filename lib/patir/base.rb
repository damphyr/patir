# Copyright (c) 2007-2012 Vassilis Rizopoulos. All rights reserved.

# frozen_string_literal: true

require "logger"

##
# The base module of the Patir gem
#
# This module contains a collection of classes, methods and modules useful for
# other projects, the most relevant ones being:
#
# * Command - mix-in for any class representing an executable command
#   * RubyCommand - class to execute a Ruby code snippet as a command
#   * ShellCommand - class to execute shell commands in a platform independent
#     manner
# * CommandSequence - class holding and allowing the sequential execution of
#   series of commands
# * Configurator - class allowing to write configuration files as Ruby code and
#   load/parse them conveniently
# * Version - version information of this gem
module Patir
  ##
  # Version information of the Patir gem
  module Version
    ##
    # The major version of the Patir gem
    MAJOR = 0
    ##
    # The minor version of the Patir gem
    MINOR = 9
    ##
    # The tiny version of the Patir gem
    TINY = 0
    ##
    # The version information of the Patir gem as a string
    STRING = [MAJOR, MINOR, TINY].join(".")
  end

  ##
  # Exception which is being raised if methods lack required arguments
  #
  # Currently this is thrown by ShellCommand only. It's thrown in case the
  # +params+ hash passed to the initialize method of ShellCommand lacks a +:cmd+
  # key.
  class ParameterException < RuntimeError
  end

  ##
  # Modified version of the default log message formatter of Ruby
  class PatirLoggerFormatter < Logger::Formatter
    ##
    # Format string defining the format of the created log messages
    FORMAT = "[%s] %5s: %s\n"

    ##
    # Initialize a new PatirLoggerFormatter instance
    def initialize
      super

      @datetime_format = "%Y%m%d %H:%M:%S"
    end

    ##
    # Create and return a log message representing the passed in arguments
    #
    # * +severity+ - a value representing the severity of the to be logged
    #   message
    # * +time+ - an instance of the Time class giving the time of the log
    #   message
    # * +progname+ - _unused_
    # * +msg+ - the actual message to be logged
    def call(severity, time, _progname, msg)
      format(FORMAT, format_datetime(time), severity, msg2str(msg))
    end
  end

  ##
  # Convenience method for quickly setting up a logger
  #
  # This method allows setting up a logger with sane defaults with a one-liner
  # and returns the new instance.
  #
  # * +filename+ - a string representing of the path to the file which the log
  #   shall be written to or an +IO+ object. If +nil+ the log is written to
  #   +stdout+.
  # * +mode+ - sets the log level and defaults to +Logger::INFO+ if +nil+. If
  #   $DEBUG is set +Logger::DEBUG+ is forced in any case. Otherwise the
  #   following arguments are valid:
  #   * any of the +Logger::Severity+ values
  #   * +:debug+ - to set the log level to +Logger::DEBUG+
  #   * +:mute+ - to set the log level to +Logger::FATAL+
  #   * +:silent+ - to set the log level to +Logger::WARN+
  def self.setup_logger(filename = nil, mode = nil)
    if filename
      logger = Logger.new(filename)
    else
      logger = Logger.new($stdout)
    end
    logger.level = Logger::INFO
    logger.level = mode if [Logger::DEBUG, Logger::FATAL, Logger::INFO, Logger::UNKNOWN, Logger::WARN].member?(mode)
    logger.level = Logger::FATAL if mode == :mute
    logger.level = Logger::WARN if mode == :silent
    logger.level = Logger::DEBUG if mode == :debug || $DEBUG
    logger.formatter = PatirLoggerFormatter.new
    return logger
  end
end
