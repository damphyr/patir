# Copyright (c) 2007-2012 Vassilis Rizopoulos. All rights reserved.

require "English"
require 'observer'
require 'fileutils'
require 'systemu'
require 'patir/base'

module Patir
  ##
  # Module defining the interface for a Command object
  #
  # This module more or less serves the purpose of documenting the interface or
  # contract expected by classes that execute commands and return their output
  # and exit status.
  #
  # All methods initialize member variables with meaningful values if needed.
  #
  # Classes including Command should implement the #run method. Internally this
  # method should set the +exec_time+, +output+ and +status+ values accordingly.
  #
  # RubyCommand and ShellCommand can be used as practical examples.
  #
  # Generally exceptions should be rescued and @error be set accordingly.
  module Command
    ##
    # Output the command emitted signalling erroneous conditions
    attr_writer :error
    ##
    # Time the command took for execution
    attr_writer :exec_time
    ##
    # A short descriptive name for the command
    attr_writer :name
    ##
    # General output of the command
    attr_writer :output
    ##
    # Indicates the status of the instance representing the command
    #
    # Valid states are:
    # * +:not_executed+ - when the command was not run
    # * +:success+ - when the command has finished successfully
    # * +:error+ - when the command has an error
    # * +:warning+ - when the command finished without errors, but there where warnings
    attr_writer :status
    ##
    # Optional number (may be useful in sequences of commands)
    attr_accessor :number
    ##
    # Information on how a failure of the command shall be handled
    attr_accessor :strategy

    ##
    # Returns the command's alias name
    def name
      # Initialize nil values to something meaningful
      @name ||= ""
      return @name
    end

    ##
    # Returns the output of the command
    def output
      # Initialize nil values to something meaningful
      @output ||= ""
      return @output
    end

    ##
    # Returns the error output for the command
    def error
      # Initialize nil values to something meaningful
      @error ||= ""
      return @error
    end

    ##
    # Returns a backtrace for the command
    def backtrace
      # Initialize nil values to something meaningful
      @backtrace ||= ""
      return @backtrace
    end

    ##
    # Returns the execution time (duration) for the command
    def exec_time
      # Initialize nil values to something meaningful
      @exec_time ||= 0
      return @exec_time
    end

    ##
    # Returns true if the command has finished successfully
    def success?
      return true if status == :success

      return false
    end

    ##
    # Returns true if the command has been executed
    def run?
      executed?
    end

    ##
    # Execute the command and return the status of the command
    #
    # This method should be overridden by classes which include Command.
    def run(_context = nil)
      @status = :success
      return status
    end

    ##
    # Clear all internal state of the command
    #
    # This method should be called if the class shall be reset to a state as if
    # the command never got executed.
    def reset
      @backtrace = ""
      @exec_time = 0
      @output = ""
      @error = ""
      @status = :not_executed
    end

    ##
    # Returns false if the command has not been run
    #
    # This is an alias for #run?.
    def executed?
      return false if status == :not_executed

      return true
    end

    ##
    # Returns the command's status
    def status
      # Initialize nil values to something meaningful
      @status ||= :not_executed
      return @status
    end
  end

  ##
  # Class wrapping the Command interface around
  # systemu[https://github.com/ahoward/systemu]
  #
  # It allows the execution of any shell command on any platform.
  #
  # Accepted keys of +param+ are:
  # * +:cmd+ - the shell command to execute (required - a ParameterException
  #   will be raised if missing)
  # * +:name+ - a descriptive name for the command (defaults to an empty string)
  # * +:timeout+ - duration after which the execution of the command will be
  #   interrupted and an error status be set (no timeout if none given)
  # * +:working_directory+ - specifies the working directory (defaults to '.')
  class ShellCommand
    include Command

    ##
    # Initialize a new ShellCommand instance
    #
    # A ParameterException will be raised if the hash passed to +params+ does
    # not contain a +:cmd+ key. A CommandError will be raised if a passed
    # +:working_directory+ does not exist.
    def initialize(params)
      @name = params[:name]
      @working_directory = params[:working_directory] || "."

      # Passing a commandline through :cmd is mandatory
      raise ParameterException, "No :command defined" unless params[:cmd]

      @command = params[:cmd]
      @status = :not_executed
      @timeout = params[:timeout]
      @error = ""
      @output = ""
    end

    ##
    # Run the command passed to the initialize method
    #
    # The status of the instance is set to +:success+ only if the command
    # orderly completed execution and set an exit code of +0+.
    def run(_context = nil)
      start_time = Time.now
      begin
        # Create the working directory if it does not exist
        FileUtils.mkdir_p(@working_directory, :verbose => false)
        # Create the actual command, run it, grab stderr and stdout and set
        # output, error, status and execution time
        if @timeout
          exited = nil
          exitstatus = 0
          status, @output, err = systemu(@command, :cwd => @working_directory) do |cid|
            sleep @timeout
            @error << "Command timed out after #{@timeout}s"
            exited = true
            exitstatus = 23
            begin
              Process.kill(9, cid)
            rescue StandardError => e
              @error << "Failed to kill child process #{cid} after timeout: #{e.message}"
            end
          end
          @error << "\n#{err}" unless err.empty?
        else
          status, @output, @error = systemu(@command, :cwd => @working_directory)
          exitstatus = status.exitstatus
        end
        begin
          exited ||= status.exited?
        rescue NotImplementedError
          # Oh look, it's JRuby
          exited = true
        end
        # Extract and set the status
        if exited
          if exitstatus.zero?
            @status = :success
          else
            @status = :error
          end
        else
          @status = :warning
        end
      rescue StandardError
        # If it blows in systemu it will be nil
        @error << "\n#{$ERROR_INFO.message}"
        @error << "\n#{$ERROR_INFO.backtrace}" if $DEBUG
        @status = :error
      end
      # Compute and set the execution time
      @exec_time = Time.now - start_time
      return @status
    end

    ##
    # Return a textual description of the command instance
    #
    # The returned string will follow the following pattern:
    #
    #     <name>: <command> in <working_directory>
    def to_s
      return "#{@name}: #{@command} in #{@working_directory}"
    end
  end

  ##
  # Class for handling a set of commands to be executed in sequence
  #
  # Each instance of CommandSequence contains a set of Patir::Command instances
  # which are the steps that shall be performed.
  #
  # The steps are executed in the sequence in which they were added.
  #
  # Depending on a step's +strategy+ the sequence can terminate immediately upon
  # a step failure or continue. If it continues it will still be marked as
  # failed if a single step failed.
  #
  # The status of the CommandSequence can be accessed using the Observer
  # pattern. The +:sequence_status+ message contains the status of the sequence
  # represented by an instance of the CommandSequenceStatus class.
  #
  # CommandSequence is designed to be re-runnable. It does not correspond to
  # just a single sequence but more to the currently active run. Calling #reset
  # or #run on it will discard the state of previous runs and will create a new
  # "instance" and state.
  #
  # CommandSequence itself does not spawn any threads (commands still can do,
  # but this is generally not advisable).
  class CommandSequence
    include Observable

    ##
    # A descriptive name for the CommandSequence
    attr_reader :name
    ##
    # A numerical id of the CommandSequence
    attr_reader :sequence_id
    ##
    # Information (e.g. hostname) of the runner of the CommandSequence
    attr_reader :sequence_runner
    ##
    # A CommandSequenceStatus instance representing the state of the
    # CommandSequence (i.e. information about the success of the execution of
    # the sequence's steps)
    attr_reader :state
    ##
    # Array of all the steps which make up the CommandSequence instance
    attr_reader :steps

    ##
    # Initialize a new CommandSequence instance
    #
    # * +name+ - a descriptive name
    # * +sequence_runner+ - name of the runner executing the sequence
    def initialize name,sequence_runner=""
      @name=name
      @steps||=Array.new
      @sequence_runner=sequence_runner
      #intialize the status for the currently active build (not executed)
      reset
    end

    ##
    # Set the internal +sequence_runner+ attribute and update the internally
    # held CommandSequenceStatus instance
    def sequence_runner=name
      @sequence_runner=name
      @state.sequence_runner=name
    end

    ##
    # Set the internal +sequence_id+ attribute and update the internally held
    # CommandSequenceStatus instance
    def sequence_id=name
      @sequence_id=name
      @state.sequence_id=name
    end

    ##
    # Execute the CommandSequence
    #
    # This will run all step instances in the sequence observing the exit
    # strategies of each command on warnings or failures.
    def run context=nil
      #set the start time
      @state.start_time=Time.now
      #reset the stop time
      @state.stop_time=nil
      #we started running, lets tell the world
      @state.status=:running
      notify(:sequence_status=>@state)
      #we are optimistic
      running_status=:success
      #but not that much
      running_status=:warning if @steps.empty?
      #execute the steps in sequence
      @steps.each do |step|
        #the step is running, tell the world
        @state.step=step
        step.status=:running
        notify(:sequence_status=>@state)
        #run it, get the result and notify
        result=step.run(context)
        @state.step=step
        step.status=:running
        notify(:sequence_status=>@state)
        #evaluate the results' effect on execution status at the end
        case result
        when :success
          #everything is fine, continue
        when :error
          #this will be the final status
          running_status=:error
          #stop if we fail on error
          if :fail_on_error==step.strategy
            @state.status=:error
            break 
          end
        when :warning
          #a previous failure overrides a warning
          running_status=:warning unless :error==running_status
          #escalate this to a failure if the strategy says so
          running_status=:error if :flunk_on_warning==step.strategy
          #stop if we fail on warning
          if :fail_on_warning==step.strategy
            @state.status=:error
            break 
          end
        end
      end#each step
      #we finished
      @state.stop_time=Time.now
      @state.status=running_status
      notify(:sequence_status=>@state)
    end

    ##
    # Adds a step to the CommandSequence using the given exit strategy
    #
    # New steps are always added to the end of the sequence. A step should quack
    # like a Command.
    #
    # Valid exit strategies are:
    # * +:fail_on_error+ - CommandSequence terminates on a failure of the step
    # * +:flunk_on_error+ - CommandSequence is flagged as failed but continues
    #   with the next step
    # * +:fail_on_warning+ - CommandSequence terminates on warnings of the step
    # * +:flunk_on_warning+ - CommandSequence is flagged as failed on warning in
    #   this step but continues
    def add_step step,exit_strategy=:fail_on_error
      #duplicate the command
      bstep=step.dup
      #reset it
      bstep.reset
      #set the extended attributes
      bstep.number=@steps.size
      exit_strategy = :fail_on_error unless [:flunk_on_error,:fail_on_warning,:flunk_on_warning].include?(exit_strategy)
      bstep.strategy=exit_strategy
      #add it to the lot
      @steps<<bstep
      #add it to status as well
      @state.step=bstep
      notify(:sequence_status=>@state)
      return bstep
    end

    ##
    # Reset the status of the CommandSequence instance
    #
    # This will set the status to +:not_executed+, reset all added steps and set
    # the start and end times to +nil+.
    def reset
      #reset all the steps (stati and execution times)
      @steps.each{|step| step.reset}
      #reset the status
      @state=CommandSequenceStatus.new(@name)
      @steps.each{|step| @state.step=step}
      @state.start_time=Time.now
      @state.stop_time=nil
      @state.sequence_runner=@sequence_runner
      #tell the world
      notify(:sequence_status=>@state)
    end

    ##
    # Returns +true+ if the sequence finished its execution
    def completed?  
      return @state.completed? 
    end

    ##
    # Return a textual description of the CommandSequence instance
    #
    # The returned string will follow the following pattern:
    #
    #     <sequence_id>:<name> on <sequence_runner>, <step_qty> steps
    def to_s
      "#{sequence_id}:#{:name} on #{@sequence_runner}, #{@steps.size} steps"
    end

    private

    ##
    # Notify observers of changes
    def notify *params
      changed
      notify_observers(*params)
    end
  end

  ##
  # CommandSequenceStatus represents the status of a CommandSequence including
  # the status of all the steps of the sequence
  #
  # In order to extract the status from steps, classes should quack to the rythm
  # of Command. CommandSequenceStatus does this, so stati can be nested.
  #
  # The status of an action sequence can be one of the following and represents
  # the overall status:
  # * +:not_executed+ is set when all steps are +:not_executed+
  # * +:running+ is set while the sequence is running
  # Upon completion or interruption one of +:success+, +:error+ or +:warning+
  # will be set:
  # * +:success+ is set when all steps completed successfully
  # * +:warning+ is set when at least one step generates a warnings and there
  #   are no failures
  # * +:error+ is set when after execution at least one step has the +:error+
  #   status
  class CommandSequenceStatus
    ##
    # A numerical id of the CommandSequenceStatus
    attr_accessor :sequence_id
    ##
    # A descriptive name for the command sequence status representation
    attr_accessor :sequence_name
    ##
    # Information (e.g. hostname) of the runner of the CommandSequence
    attr_accessor :sequence_runner
    ##
    # The time when the CommandSequenceStatus instance was initialized
    attr_accessor :start_time
    ##
    # The overall status of the CommandSequence
    attr_accessor :status
    ##
    # Hash mapping a step's number to a collection of its attributes
    attr_accessor :step_states
    ##
    # The time when the execution stopped or was completed
    attr_accessor :stop_time
    ##
    # Information on how a failure of the command shall be handled
    attr_accessor :strategy

    ##
    # Initialize a new CommandSequenceStatus instance
    #
    # * +sequence_name+ - a descriptive name for the sequence
    # * +steps+ - optional list of steps which will be passed to #step= each
    def initialize sequence_name,steps=nil
      @sequence_name=sequence_name
      @sequence_runner=""
      @sequence_id=nil
      @step_states||=Hash.new
      #not run yet
      @status=:not_executed
      #translate the array of steps as we need it in number=>state form
      steps.each{|step| self.step=step } if steps
      @start_time=Time.now
    end

    ##
    # Returns +true+ if the represented sequence is currently being executed
    def running?
      return true if :running==@status
      return false
    end

    ##
    # Returns +true+ if all steps completed successfully
    def success?
      return true if :success==@status
      return false
    end

    ##
    # Checks if the represented sequence is completed
    #
    # It is considered completed if:
    # * a step has errors and the +:fail_on_error+ strategy is used
    # * a step has warnings and the +:fail_on_warning+ strategy is used
    # * in all other cases if none of the steps has a +:not_executed+ or
    #   +:running+ status
    def completed?
      #this saves us iterating once+1 when no execution took place
      return false if !self.executed?
      @step_states.each do |state|
        return true if state[1][:status]==:error && state[1][:strategy]==:fail_on_error
        return true if state[1][:status]==:warning && state[1][:strategy]==:fail_on_warning
      end
      @step_states.each{|state| return false if state[1][:status]==:not_executed || state[1][:status]==:running }
      return true
    end

    ##
    # Query the state of the step with a particular +number+
    #
    # If there is no step with such +number+, then +nil+ is returned.
    def step_state number
      s=@step_states[number] if @step_states[number]
      return s
    end

    ##
    # Add a step
    #
    # The internally held state is updated accordingly.
    def step=step
      @step_states[step.number]={:name=>step.name,
        :status=>step.status,
        :output=>step.output,
        :duration=>step.exec_time,
        :error=>step.error,
        :strategy=>step.strategy
      }
      #this way we don't have to compare all the step states we always get the worst last stable state
      #:not_executed<:success<:warning<:success
      unless @status==:running
        @previous_status=@status 
        case step.status
        when :running
          @status=:running
        when :warning
          @status=:warning unless @status==:error
          @status=:error if @previous_status==:error
        when :error
          @status=:error
        when :success
          @status=:success unless @status==:error || @status==:warning
          @status=:warning if @previous_status==:warning
          @status=:error if @previous_status==:error
        when :not_executed
          @status=@previous_status
        end
      end#unless running
    end

    ##
    # Produce a short text summary of this CommandSequenceStatus instance
    def summary
      sum=""
      sum<<"#{@sequence_id}:" if @sequence_id
      sum<<"#{@sequence_name}. " unless @sequence_name.empty?
      sum<<"Status - #{@status}" 
      if !@step_states.empty? && @status!=:not_executed
        sum<<". States #{@step_states.size}\nStep status summary:"
        sorter=Hash.new
        @step_states.each do |number,state|
          #sort them by number
          sorter[number]="\n\t#{number}:'#{state[:name]}' - #{state[:status]}"
        end
        1.upto(sorter.size) {|i| sum<<sorter[i] if sorter[i]}
      end 
      return sum
    end

    ##
    # Return a textual description of the CommandSequenceStatus instance
    #
    # The returned string will follow the following pattern:
    #
    #     '<sequence_id>':'<sequence_name>' on '<sequence_runner' started at <start_time>.<step_states.size> steps
    def to_s
      "'#{sequence_id}':'#{@sequence_name}' on '#{@sequence_runner}' started at #{@start_time}.#{@step_states.size} steps"
    end

    ##
    # Return the execution time if it can be computed or +0+ otherwise
    def exec_time
      return @stop_time-@start_time if @stop_time
      return 0
    end

    ##
    # Return the descriptive name
    def name
      return @sequence_name
    end

    ##
    # Return the internally held sequence id
    def number
      return @sequence_id
    end

    ##
    # Alias for the #summary method
    def output
      return self.summary
    end

    ##
    # _Unused_ - always returns an empty string
    def error
      return ""
    end

    ##
    # Returns +true+ if the represented sequence was or is being executed or
    # +false+ otherwise
    def executed?
      return true unless @status==:not_executed
      return false
    end
  end

  ##
  # Class allowing to wrap Ruby blocks and handle them like Command
  #
  # A block provided to RubyCommand#initialize can be executed through the #run
  # method.
  #
  # The block receives the instance of RubyCommand so you can set the output and
  # error output through its accessors.
  #
  # If the passed in block runs to the end the command is considered executed
  # successfully.
  #
  # If an exception is raised in the block the command status will be set to
  # +:error+.
  #
  # The exception's message will be appended to the error output of the command.
  #
  # == Example
  #
  # An example (using the excellent HighLine lib) of a CLI prompt as a
  # RubyCommand:
  #
  #     RubyCommand.new("prompt") do |cmd|
  #       cmd.output=""
  #       cmd.error=""
  #       unless HighLine.agree("#{step.text}?")
  #         cmd.error="Why not?"
  #         raise "You did not agree"
  #       end
  #     end
  class RubyCommand
    include Patir::Command

    ##
    # The block which shall be executed upon invocation of the #run method
    attr_reader :cmd
    ##
    # The context which is accessible by the block during execution (this is
    # only valid during execution of the block and can be used by the block to
    # access the context passed to the #run method)
    attr_reader :context
    ##
    # The working directory within which the block will be executed
    attr_reader :working_directory

    ##
    # Initialize a new RubyCommand instance
    #
    # * +name+ - a short descriptive name for the command
    # * +working_directory+ - path to the working directory in which the command
    #   shall be executed (defaults to the current directory if +nil+)
    # * +block+ - the block which shall be executed upon invocation of the #run
    #   method
    def initialize(name, working_directory = nil, &block)
      @name = name
      @working_directory = working_directory || "."

      raise "A block must be provided to RubyCommand upon initialization" unless block_given?

      @cmd = block
    end

    ##
    # Run the code block which got passed to the #initialize method
    #
    # This sets the internal @status variable according to the result of the
    # execution of the block.
    def run(context = nil)
      @context = context
      @error = ""
      @output = ""
      @backtrace = ""
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
      return @status
    end
  end
end
