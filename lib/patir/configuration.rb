#  Copyright (c) 2007-2010 Vassilis Rizopoulos. All rights reserved.

require 'patir/base'
module Patir
  #This exception is thrown when encountering a configuration error
  class ConfigurationException<RuntimeError
  end
  
  #Configurator is the base class for all the Patir configuration classes.
  # 
  #The idea behind the configurator is that the developer creates a module that contains as methods
  #all the configuration directives.
  #He then derives a class from Configurator and includes the directives module. 
  #The Configurator loads the configuration file and evals it with itself as context (variable configuration), so the directives become methods in the configuration file:
  # configuration.directive="some value"
  # configuration.other_directive={:key=>"way to group values together",:other_key=>"omg"}
  #
  #The Configurator instance contains all the configuration data.
  #Configurator#configuration method is provided as a post-processing step. It should be overriden to return the configuration data in the desired format and perform any overall validation steps (single element validation steps should be done in the directives module).
  #==Example
  # module SimpleConfiguration
  #   def name= tool_name
  #     raise Patir::ConfigurationException,"Inappropriate language not allowed" if tool_name=="@#!&@&$}"
  #     @name=tool_name
  #   end
  # end
  #   
  # class SimpleConfigurator
  #   include SimpleConfiguration
  #     
  #   def configuration
  #     return @name
  #   end
  # end
  #The configuration file would then be 
  # configuration.name="really polite name"
  #To use it you would do
  # cfg=SimpleConfigurator.new("config.cfg").configuration
  class Configurator
    attr_reader :logger,:config_file,:wd
    def initialize config_file,logger=nil
      @logger=logger
      @logger||=Patir.setup_logger
      @config_file=config_file
      load_configuration(@config_file)
    end
    
    #Returns self. This should be overriden in the actual implementations
    def configuration
      return self
    end
    
    #Loads the configuration from a file
    #
    #Use this to chain configuration files together
    #==Example
    #Say you have on configuration file "first.cfg" that contains all the generic directives and several others that change only one or two things. 
    #
    #You can 'include' the first.cfg file in the other configurations with
    # configuration.load_from_file("first.cfg")
    def load_from_file filename
      fnm = File.exists?(filename) ? filename : File.join(@wd,filename)
      load_configuration(fnm)
    end
    private
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