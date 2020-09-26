# Copyright (c) 2007-2020 Vassilis Rizopoulos. All rights reserved.

module Patir
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
      @steps << bstep
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
end
