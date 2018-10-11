#  Copyright (c) 2007-2012 Vassilis Rizopoulos. All rights reserved.
require 'observer'
require 'fileutils'
require 'systemu'
require 'patir/base'

module Patir
  #This module defines the interface for a Command object.
  #
  #It more or less serves the purpose of documenting the interface/contract expected 
  #by a class that executes commands and returns their output and exit status.
  #
  #There is also that bit of functionality that facilitates grouping multiple commands into command sequences
  #
  #The various methods initialize member variables with meaningful values where needed.
  #
  #Using the contract means implementing the Command#run method. This method should then set 
  #the output, exec_time and status values according to the implementation.
  #
  #Take a look at ShellCommand and RubyCommand for a couple of practical examples.
  #
  #It is a good idea to rescue all exceptions. You can then set error to return the exception message.
  module Command
    attr_writer :output, :name, :exec_time,:error,:status
    attr_accessor :number,:strategy
    #returns the commands alias/name
    def name
      #initialize nil values to something meaningful
      @name||=""
      return @name
    end
    #returns the output of the command
    def output
      #initialize nil values to something meaningful
      @output||=""
      return @output
    end
    #returns the error output for the command
    def error
      #initialize nil values to something meaningful
      @error||=""
      return @error
    end
    #returns the error output for the command
    def backtrace
      #initialize nil values to something meaningful
      @backtrace||=""
      return @backtrace
    end
    #returns the execution time (duration) for the command
    def exec_time
      #initialize nil values to something meaningful
      @exec_time||=0
      return @exec_time
    end
    #returns true if the command has finished succesfully
    def success?
      return true if self.status==:success
      return false
    end
    #returns true if the command has been executed
    def run?
      executed?
    end
    #executes the command and returns the status of the command.
    #
    #overwrite this method in classes that include Command
    def run context=nil
      @status=:success
      return self.status
    end
    #clears the status and output of the command.
    #
    #Call this if you want to pretend that it was never executed
    def reset
      @exec_time=0
      @output=""
      @error=""
      @status=:not_executed
    end
    #returns false if the command has not been run, alias for run?
    def executed?
      return false if self.status==:not_executed
      return true
    end
    #returns the command status.
    #
    #valid stati are
    # :not_executed when the command was not run
    # :success when the command has finished succesfully
    # :error when the command has an error
    # :warning when the command finished without errors, but there where warnings
    def status
      #initialize nil values to something meaningful
      @status||=:not_executed
      return @status
    end
  end

  #This class wraps the Command interface around https://github.com/ahoward/systemu 
  #
  #It allows for execution of any shell command on any platform.
  #
  #Accepted keys are
  # :cmd - the shell command to execute (required - ParameterException will be raised).
  # :working_directory - specify the working directory (default is '.')
  # :name - assign a name to the command (default is "").
  # :timeout - if the command runs longer than timeout, it will be interrupted and an error will be set.
  #
  #The timeout is set in seconds
  class ShellCommand
    include Command
    #The constructor will throw CommandError if :cmd is missing.
    #
    #CommandError will also be thrown if :working_directory does not exist.
    def initialize params
      @name=params[:name]
      @working_directory=params[:working_directory] || "."
      #we need a command line :)
      raise ParameterException,"No :command defined" unless params[:cmd]
      @command=params[:cmd]
      @status=:not_executed
      @timeout=params[:timeout]
      @error=""
      @output=""
    end

    #Executes the shell command and returns the status
    def run context=nil
      start_time=Time.now
      begin
        #create the working directory if it does not exist
        FileUtils::mkdir_p(@working_directory,:verbose=>false)
        #create the actual command, run it, grab stderr and stdout and set output,error, status and execution time
        if @timeout 
          exited=nil
          exitstatus=0
          status, @output, err = systemu(@command,:cwd=>@working_directory) do |cid|
              sleep @timeout
              @error<<"Command timed out after #{@timeout}s"
              exited=true
              exitstatus=23
              begin
                Process.kill 9,cid
              rescue => ex
                @error<<"Failure to kill timeout child process #{cid}: #{ex.message}"
              end
          end
          @error<<"\n#{err}" unless err.empty?
        else
          status, @output, @error = systemu(@command,:cwd=>@working_directory) 
          exitstatus = status.exitstatus
        end
        begin
          exited||= status.exited?
        rescue NotImplementedError
          #oh look, it's jruby
          exited=true
        end
        #lets get the status how we want it
        if exited
          if exitstatus ==0
            @status=:success
          else
            @status=:error
          end
        else
          @status=:warning
        end
      rescue
        #if it blows in systemu it will be nil
        @error<<"\n#{$!.message}"
        @error<<"\n#{$!.backtrace}" if $DEBUG
        @status=:error
      end
      #set the time it took us
      @exec_time=Time.now-start_time
      return @status
    end

    def to_s
      return "#{@name}: #{@command} in #{@working_directory}"
    end
  end

  #CommandSequence describes a set of commands to be executed in sequence.
  #
  #Each instance of CommandSequence contains a set of Patir::Command instances, which are the steps to perform.
  #
  #The steps are executed in the sequence they are added. A CommandSequence can terminate immediately on step failure or it can continue. It will still be marked as failed as long as a single step fails.
  #
  #Access to the CommandSequence status is achieved using the Observer pattern.
  #
  #The :sequence_status message contains the status of the sequence, an instance of the class CommandSequenceStatus.
  #
  #CommandSequence is designed to be reusable, so it does not correspond to a single sequence run, rather it corresponds to 
  #the currently active run. Calling reset, or run  will discard the old state and create a new sequence 'instance' and status.
  #
  #No threads are spawned by CommandSequence (that doesn't mean the commands cannot, but it is not advisable).
  class CommandSequence
    include Observable
    attr_reader :name,:state,:steps
    attr_reader :sequence_runner
    attr_reader :sequence_id

    def initialize name,sequence_runner=""
      @name=name
      @steps||=Array.new
      @sequence_runner=sequence_runner
      #intialize the status for the currently active build (not executed)
      reset
    end

    #sets the sequence runner attribute updating status
    def sequence_runner=name
      @sequence_runner=name
      @state.sequence_runner=name
    end

    #sets the sequence id attribute updating status
    def sequence_id=name
      @sequence_id=name
      @state.sequence_id=name
    end
    #Executes the CommandSequence.
    #
    #Will run all step instances in sequence observing the exit strategies on warning/failures
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
    #Adds a step to the CommandSequence using the given exit strategy.
    #
    #Steps are always added at the end of the build sequence. A step should quack like a Patir::Command.
    #
    #Valid exit strategies are 
    # :fail_on_error - CommandSequence terminates on failure of this step
    # :flunk_on_error - CommandSequence is flagged as failed but continues to the next step
    # :fail_on_warning - CommandSequence terminates on warnings in this step
    # :flunk_on_warning - CommandSequence is flagged as failed on warning in this step
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

    #Resets the status. This will set :not_executed status, 
    #and set the start and end times to nil.
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

    #Returns true if the sequence has finished executing
    def completed?  
      return @state.completed? 
    end

    def to_s
      "#{sequence_id}:#{:name} on #{@sequence_runner}, #{@steps.size} steps"
    end
    private
    #observer notification
    def notify *params
      changed
      notify_observers(*params)
    end
  end

  #CommandSequenceStatus represents the status of a CommandSequence, including the status of all the steps for this sequence.
  #
  #In order to extract the status from steps, classes should quack to the rythm of Command. CommandSequenceStatus does this, so you can nest Stati
  #
  #The status of an action sequence is :not_executed, :running, :success, :warning or :error and represents the overall status
  # :not_executed is set when all steps are :not_executed
  # :running is set while the sequence is running.
  #Upon completion or interruption one of :success, :error or :warning will be set.
  # :success is set when all steps are succesfull.
  # :warning is set when at least one step generates warnings and there are no failures.
  # :error is set when after execution at least one step has the :error status
  class CommandSequenceStatus
    attr_accessor :start_time,:stop_time,:sequence_runner,:sequence_name,:status,:step_states,:sequence_id,:strategy
    #You can pass an array of Commands to initialize CommandSequenceStatus
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
    def running?
      return true if :running==@status
      return false
    end
    #true is returned when all steps were succesfull.
    def success?
      return true if :success==@status
      return false
    end

    #A sequence is considered completed when:
    #
    #a step has errors and the :fail_on_error strategy is used
    #
    #a step has warnings and the :fail_on_warning strategy is used
    #
    #in all other cases if none of the steps has a :not_executed or :running status
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
    #A nil means there is no step with that number
    def step_state number
      s=@step_states[number] if @step_states[number]
      return s
    end
    #Adds a step to the state. The step state is inferred from the Command instance __step__
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
    #produces a brief text summary for this status
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
    def to_s
      "'#{sequence_id}':'#{@sequence_name}' on '#{@sequence_runner}' started at #{@start_time}.#{@step_states.size} steps"
    end
    def exec_time
      return @stop_time-@start_time if @stop_time
      return 0
    end
    def name
      return @sequence_name
    end  
    def number
      return @sequence_id
    end
    def output
      return self.summary
    end
    def error
      return ""
    end
    def executed?
      return true unless @status==:not_executed
      return false
    end
  end

  #This class allows you to wrap Ruby blocks and handle them like Command
  #
  #Provide a block to RubyCommand#new and you can execute the block using
  #RubyCommand#run
  #
  #The block receives the instance of RubyCommand so you can set the output and error output.
  #
  #If the block runs to the end the command is considered successful.
  #
  #Raising an exception in the block will set the command status to :error. 
  #
  #The exception message will be appended to the error output of the command
  #
  #== Examples
  #An example (using the excellent HighLine lib) of a CLI prompt as a RubyCommand
  # RubyCommand.new("prompt") do |cmd|  
  #   cmd.output=""
  #   cmd.error=""
  #   unless HighLine.agree("#{step.text}?")
  #     cmd.error="Why not?"
  #     raise "You did not agree" 
  #   end
  # end
  class RubyCommand
    include Patir::Command
    attr_reader :cmd,:working_directory,:context
    def initialize name,working_directory=nil,&block
      @name=name
      @working_directory=working_directory||"."
      if block_given?
        @cmd=block 
      else
        raise "You need to provide a block"
      end
    end
    #Runs the associated block
    def run context=nil
      @run=true
      @context=context
      @error=""
      @output=""
      @backtrace=""
      begin
        t1=Time.now
        Dir.chdir(@working_directory) do
          @cmd.call(self)
          @status=:success
        end
      rescue StandardError
        @error<<"\n#{$!.message}"
        @backtrace=$@
        @status=:error
      ensure
        @exec_time=Time.now-t1
      end
      @context=nil
      return @status
    end
  end
end