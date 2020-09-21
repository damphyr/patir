# Copyright (c) 2007-2020 Vassilis Rizopoulos. All rights reserved.

# frozen_string_literal: true

require 'English'

require_relative 'base'

module Patir
  ##
  # Exception which is being thrown if an error occurs while loading a
  # configuration from a file
  class ConfigurationException < RuntimeError
  end

  ##
  # Configurator is the base class for all the Patir configuration classes.
  #
  # The idea behind the Configurator is that a developer creates a module that
  # contains all the configuration directives as methods.
  #
  # From Configurator a class can then be derived which includes the module with
  # the individual directives.
  #
  # Configurator loads the configuration file and evals it with itself as
  # context (variable configuration), so the directives become methods in the
  # configuration file:
  #
  #     configuration.directive = 'some value'
  #     configuration.other_directive = { key: 'way to group values',other_key: 'abc' }
  #
  # The Configurator instance then contains all the configuration data.
  #
  # The Configurator#configuration method is provided as a post-processing step.
  # It should be overridden to return the configuration data in the desired
  # format and perform any validation steps (single element validation steps
  # should be done in the directives module).
  #
  # == Example
  #
  #     module SimpleConfiguration
  #       def name=(tool_name)
  #         raise Patir::ConfigurationException, \
  #               'Inappropriate language not allowed' if tool_name == '@#!&@&$}'
  #         @name = tool_name
  #       end
  #     end
  #     
  #     class SimpleConfigurator
  #       include SimpleConfiguration
  #       
  #       def configuration
  #         return @name
  #       end
  #     end
  #
  # The configuration file would then be:
  #
  #     configuration.name = 'really polite name'
  #
  # To use it this would be sufficent:
  #
  #     cfg = SimpleConfigurator.new('config.cfg').configuration
  class Configurator
    ##
    # The configuration file from which the Configurator loads its configuration
    attr_reader :config_file
    ##
    # The logger which is being utilized by the Configurator
    attr_reader :logger
    ##
    # The working directory used for parsing the configuration file
    #
    # The directory in which the configuration file to be loaded is in will be
    # used as current working directory. This is relevant for the interpretation
    # of relative paths within configuration files.
    attr_reader :wd

    ##
    # Initialize a new Configurator instance by parsing the given file and
    # and eventually logging with the specified logger
    def initialize(config_file, logger = nil)
      @logger = logger
      @logger ||= Patir.setup_logger
      @config_file = config_file
      load_configuration(@config_file)
    end

    ##
    # Return +self+
    #
    # This should be overridden by the actual implementations. Its purpose is to
    # return the configuration in the desired format and conduct validation.
    def configuration
      self
    end

    ##
    # Load the configuration from a file
    #
    # Configuration files can be chained together as given by the following
    # example.
    #
    # == Example
    #
    # If there exists a configuration file +general.cfg+ that contains generic
    # directives and several others with more specific information then these
    # can include the general one in the following way:
    #
    #     configuration.load_from_file('first.cfg')
    def load_from_file(filename)
      fnm = File.exist?(filename) ? filename : File.join(@wd, filename)
      load_configuration(fnm)
    end

    private

    ##
    # Conduct the actual loading of the configuration file
    #
    # This deducts working directory of the Configurator instance as the
    # directory the given file referred by +filename+ is located in. After
    # changing into this working directory the configuration file is being
    # evaluated.
    def load_configuration(filename)
      cfg_txt = File.read(filename)
      @wd = File.expand_path(File.dirname(filename))
      configuration = self
      # Add the deducted working directory to the required lookup path to allow
      # require statements in the configuration files
      $LOAD_PATH.unshift File.join(@wd)
      # Evaluate in the deducted working directory to enable relative paths in
      # the configuration files
      Dir.chdir(@wd) { eval(cfg_txt, binding) }
      @logger&.info("Configuration loaded from #{filename}")
    rescue ConfigurationException
      # Pass the exception on and do not wrap it again
      raise
    rescue SyntaxError
      # Just wrap the exception for differentiation
      @logger&.debug($ERROR_INFO)
      raise ConfigurationException.new, \
            "Syntax error in the configuration file '#{filename}':\n#{$ERROR_INFO.message}"
    rescue NoMethodError
      @logger&.debug($ERROR_INFO)
      raise ConfigurationException.new, \
            "Encountered an unknown directive in configuration file '#{filename}':\n#{$ERROR_INFO.message}"
    rescue
      @logger&.debug($ERROR_INFO)
      # Just wrap the exception for differentiation
      raise ConfigurationException.new, $ERROR_INFO.message.to_s
    end
  end
end
