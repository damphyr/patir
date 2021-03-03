# Copyright (c) 2007-2012 Vassilis Rizopoulos. All rights reserved.

require 'patir/base'

module Patir
  ##
  # Exception which is being thrown upon errors while loading a configuration
  # file
  #
  # This may be caused e.g. by an invalid syntax of the configuration file or
  # unknown configuration directives within it.
  class ConfigurationException<RuntimeError
  end
  
  ##
  # Configurator is intended as a base class for classes handling configuration
  # files
  # 
  # The idea behind the Configurator class is that the developer creates a
  # module that contains methods for all the configuration directives. Then a
  # class can be derived from Configurator which includes the module with the
  # directives.
  #
  # The Configurator loads the configuration file and evals it with itself as
  # context (variable configuration), so the directives become methods in the
  # configuration file:
  #
  #     configuration.directive = "some value"
  #     configuration.other_directive = { :key => "way to group values together",
  #                                       :other_key=>"omg" }
  #
  # The Configurator instance then contains all the configuration data.
  #
  # The #configuration method is provided as a post-processing step. It should
  # be overridden to return the configuration data in the desired format and
  # perform any overall validation steps (single element validation steps should
  # be done in the methods of the directives module).
  #
  # == Example
  #
  #     module SimpleConfiguration
  #       def name=(tool_name)
  #         raise Patir::ConfigurationException, \
  #               "Inappropriate language not allowed" if tool_name == "@#!&@&$}"
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
  #     configuration.name = "really polite name"
  #
  # It could then be used like:
  #
  #     cfg = SimpleConfigurator.new("config.cfg").configuration
  class Configurator
    ##
    # The main configuration file from which configuration loading started
    attr_reader :config_file
    ##
    # An optional logger writing information about loaded files and errors if
    # set
    attr_reader :logger
    ##
    # The current working directory the Configurator instance is currently
    # loading from
    attr_reader :wd

    ##
    # Initialize a new Configurator instance
    #
    # * +config_file+ - the main (i.e root) configuration file which shall be
    #   loaded
    # * +logger+ - an optional logger which will log informational and debug
    #   information if given
    def initialize config_file,logger=nil
      @logger=logger
      @logger||=Patir.setup_logger
      @config_file=config_file
      load_configuration(@config_file)
    end
    
    ##
    # Returns self
    #
    # This can and/or should be overriden in the actual implementations (e.g. to
    # conduct verification)
    def configuration
      return self
    end
    
    ##
    # Loads the configuration from a file
    #
    # This method can be used to chain configuration files together.
    #
    # == Example
    #
    # If there is a configuration file +first.cfg+ that contains generic
    # directives and there are several specific ones adjusting minor options.
    # These specific files could "include" the general one in the following way:
    #
    #     configuration.load_from_file("first.cfg")
    def load_from_file filename
      fnm = File.exist?(filename) ? filename : File.join(@wd,filename)
      load_configuration(fnm)
    end

    private

    ##
    # Load the given configuration file
    #
    # This reads the entire file, changes the current working directory to the
    # directory containing the file (to make relative references to other
    # configuration files work) and then evaluates the file with the instance
    # itself as context.
    def load_configuration filename
      begin 
        cfg_txt=File.read(filename)
        @wd=File.expand_path(File.dirname(filename))
        configuration=self
        #add the path to the require lookup path to allow require statements in the configuration files
        $:.unshift File.join(@wd)
        #evaluate in the working directory to enable relative paths in configuration
        Dir.chdir(@wd){eval(cfg_txt,binding())}
        @logger.info("Configuration loaded from #{filename}") if @logger
      rescue ConfigurationException
        #pass it on, do not wrap again
        raise
      rescue SyntaxError
        #Just wrap the exception so we can differentiate
        @logger.debug($!)
        raise ConfigurationException.new,"Syntax error in the configuration file '#{filename}':\n#{$!.message}"
      rescue NoMethodError
        @logger.debug($!)
        raise ConfigurationException.new,"Encountered an unknown directive in configuration file '#{filename}':\n#{$!.message}"
      rescue 
        @logger.debug($!)
        #Just wrap the exception so we can differentiate
        raise ConfigurationException.new,"#{$!.message}"
      end
    end
  end
end
