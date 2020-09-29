# Copyright (c) 2007-2020 Vassilis Rizopoulos. All rights reserved.

# frozen_string_literal: false

require 'English'
require 'observer'
require 'fileutils'
require 'systemu'
require 'patir/base'

module Patir
  ##
  # A module defining the interface for a Command object
  #
  # This modul more or less serves the purpose of documenting the interface or
  # contract expected by a class that executes commands and returns their output
  # and exit status.
  #
  # It contains also a bit of functionality that facilitates grouping multiple
  # commands into command sequences
  #
  # The various methods initialize member variables with meaningful values where
  # needed.
  #
  # Using the contract means implementing the Command#run method. This method
  # should then set the +error+, +exec_time+, +output+ and +status+ values
  # according to the implementated command's execution result.
  #
  # RubyCommand and ShellCommand can be taken as practical examples.
  #
  # It is a good idea to rescue all exceptions. +error+ can then be set to
  # return the exception message.
  module Command
    ##
    # A backtrace of the command
    attr_writer :backtrace
    ##
    # Error output of the command
    attr_writer :error
    ##
    # The execution time (duration) of the command
    attr_writer :exec_time
    ##
    # The alias or name of the command
    attr_writer :name
    ##
    # Regular output of the command
    attr_writer :output
    ##
    # The status of the command
    attr_writer :status
    ##
    # The number of the command (could be used for groups of commands)
    attr_accessor :number
    ##
    # Strategy concerning the command (seems to be used to define exit
    # strategies)
    attr_accessor :strategy

    ##
    # Return a backtrace of the command if applicable
    def backtrace
      # Initialize a nil value to something meaningful
      @backtrace ||= ''
      @backtrace
    end

    ##
    # Return the error output of the command
    def error
      # Initialize a nil value to something meaningful
      @error ||= ''
      @error
    end

    ##
    # Return the execution time (duration) of the command
    def exec_time
      # Initialize a nil value to something meaningful
      @exec_time ||= 0
      @exec_time
    end

    ##
    # Return +false+ if the command has not been run, alias for #run?
    def executed?
      return false if status == :not_executed

      true
    end

    ##
    # Return the command's alias or name
    def name
      # Initialize a nil value to something meaningful
      @name ||= ''
      @name
    end

    ##
    # Return the output of the command
    def output
      # Initialize a nil value to something meaningful
      @output ||= ''
      @output
    end

    ##
    # Clear the backtrace, execution time, the outputs and the status of the
    # command
    #
    # This should be called if the execution of a task and its results shall be
    # forgotten.
    def reset
      @backtrace = ''
      @error = ''
      @exec_time = 0
      @output = ''
      @status = :not_executed
    end

    ##
    # Execute the command and returns its status
    #
    # Classes including Command should override this method
    def run(_context = nil)
      @status = :success
      status
    end

    ##
    # Return +true+ if the command has been executed
    def run?
      executed?
    end

    ##
    # Return the status of the Command instance
    #
    # Valid stati are
    # * +:not_executed+ when the command was not run
    # * +:success+ when the command has finished succesfully
    # * +:error+ when the command has an error
    # * +:warning+ when the command finished without errors but there where
    #   warnings
    def status
      # Initialize a nil value to something meaningful
      @status ||= :not_executed
      @status
    end

    ##
    # Return +true+ if the command has finished succesfully
    def success?
      return true if status == :success

      false
    end
  end

  ##
  # This class wraps the Command interface around https://github.com/ahoward/systemu
  #
  # It allows for execution of any shell command on any platform.
  class ShellCommand
    include Command

    ##
    # Initialize a new ShellCommand instance
    #
    # Accepted keys of the Hash passed for initialization are:
    # * +:cmd+ - the shell command to execute (required - ParameterException
    #   will be raised if missing)
    # * +:name+ - assign a name to the command (default is an empty String
    #   instance)
    # * +:timeout+ - if the command runs longer than timeout (given in seconds),
    #   it will be interrupted and an error will be set
    # * +:working_directory+ - specify the working directory (default is '.')
    def initialize(params)
      # A ShellCommand instance without a given commandline is useless
      raise ParameterException, 'No :cmd given' unless params[:cmd]

      @command = params[:cmd]
      @error = ''
      @name = params[:name]
      @output = ''
      @status = :not_executed
      @timeout = params[:timeout]
      @working_directory = params[:working_directory] || '.'
    end

    ##
    # Execute the given shell command and return the status
    def run(_context = nil)
      start_time = Time.now
      begin
        # Create the working directory if it does not exist yet
        FileUtils.mkdir_p(@working_directory, verbose: false)
        # Create the actual command, run it, grab stderr and stdout and set
        # output,error, status and execution time
        if @timeout
          exited = nil
          exit_status = 0
          status, @output, err = systemu(@command, cwd: @working_directory) do |cid|
            sleep @timeout
            @error << "Command timed out after #{@timeout}s"
            exited = true
            exit_status = 23
            begin
              Process.kill 9, cid
            rescue StandardError => e
              @error << "Failure to kill timeout child process #{cid}:" \
                        " #{e.message}"
            end
          end
          @error << "\n#{err}" unless err.empty?
        else
          status, @output, @error = systemu(@command, cwd: @working_directory)
          exit_status = status.exitstatus
        end
        begin
          exited ||= status.exited?
        rescue NotImplementedError
          # Oh look, it's JRuby
          exited = true
        end
        # Extract the status and set it
        @status = if exited
                    if exit_status.zero?
                      :success
                    else
                      :error
                              end
                  else
                    :warning
                  end
      rescue StandardError
        # If it blows in systemu it will be nil
        @error << "\n#{$ERROR_INFO.message}"
        @error << "\n#{$ERROR_INFO.backtrace}" if $DEBUG
        @status = :error
      end
      # Calculate the execution time
      @exec_time = Time.now - start_time
      @status
    end

    def to_s # :nodoc:
      "#{@name}: #{@command} in #{@working_directory}"
    end
  end

  ##
  # Class allowing to wrap Ruby blocks and treat them like a command
  #
  # A block provided to RubyCommand#new can be executed using RubyCommand#run
  #
  # The block receives the instance of RubyCommand so the output and error
  # output can be set within the block.
  #
  # If the block runs to the end the command is considered successful.
  #
  # If an exception is raised in the block this will set the command status to
  # +:error+. The exception message will be appended to the +error+ member of
  # the command instance.
  #
  # == Examples
  #
  # An example (using the excellent HighLine lib) of a CLI prompt as a
  # RubyCommand:
  #
  #     RubyCommand.new('prompt') do |cmd|
  #       cmd.error = ''
  #       cmd.output = ''
  #       unless HighLine.agree("#{step.text}?")
  #         cmd.error = 'Why not?'
  #         raise 'You did not agree'
  #       end
  #     end
  class RubyCommand
    include Patir::Command

    ##
    # This holds the block being passed to the initialization method
    attr_reader :cmd
    ##
    # The context of an execution (is reset to +nil+ when execution is finished)
    attr_reader :context
    ##
    # The working directory within the block is being executed
    attr_reader :working_directory

    ##
    # Create a RubyCommand instance with a particular +name+, an optional
    # +working_directory+ and a +block+ that will be executed by it
    def initialize(name, working_directory = nil, &block)
      @name = name
      @working_directory = working_directory || '.'
      raise 'You need to provide a block' unless block_given?

      @cmd = block
    end

    ##
    # Run the block passed on initialization
    def run(context = nil)
      @backtrace = ''
      @context = context
      @error = ''
      @output = ''
      begin
        t1 = Time.now
        Dir.chdir(@working_directory) do
          @cmd.call(self)
          @status = :success
        end
      rescue StandardError
        @error << "\n#{$ERROR_INFO.message}"
        @backtrace = $ERROR_POSITION
        @status = :error
      ensure
        @exec_time = Time.now - t1
      end
      @context = nil
      @status
    end
  end
end
