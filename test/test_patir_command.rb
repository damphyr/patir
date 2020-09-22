# Copyright (c) 2007-2020 Vassilis Rizopoulos. All rights reserved.

$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require "minitest/autorun"
require 'patir/command.rb'

class MockCommandObject
  include Patir::Command
end

class MockCommandWarning
  include Patir::Command
  def run context=nil
    @status=:warning
    return :warning
  end
end

class MockCommandError
  include Patir::Command
  def run context=nil
    @status=:error
    return :error
  end
end

module Patir::Test
  ##
  # Test the Patir::Command module
  class Command < Minitest::Test
    ##
    # Verify that the module's default values are correctly set
    def test_default_values
      obj = MockCommandObject.new
      assert_equal('', obj.backtrace)
      assert_equal('', obj.error)
      assert_equal(0, obj.exec_time)
      refute(obj.executed?)
      assert_equal('', obj.name)
      assert_nil(obj.number)
      assert_equal('', obj.output)
      refute(obj.run?)
      assert_equal(:not_executed, obj.status)
      assert_nil(obj.strategy)
      refute(obj.success?)
    end

    ##
    # Verify that the Patir::Command#reset method correctly resets its fields
    def test_reset
      obj = MockCommandObject.new
      obj.backtrace = "Something\nbad\nhappened"
      obj.error = 'Ouch'
      obj.exec_time = 182
      obj.output = 'Some characters'
      obj.status = :some_state
      assert_equal("Something\nbad\nhappened", obj.backtrace)
      assert_equal('Ouch', obj.error)
      assert_equal(182, obj.exec_time)
      assert_equal('Some characters', obj.output)
      assert_equal(:some_state, obj.status)
      obj.reset
      assert_equal('', obj.backtrace)
      assert_equal('', obj.error)
      assert_equal(0, obj.exec_time)
      assert_equal('', obj.output)
      assert_equal(:not_executed, obj.status)
    end

    ##
    # Verify that the Patir::Command#run method correctly updates the status
    def test_run
      obj = MockCommandObject.new
      assert_equal(:not_executed, obj.status)
      obj.run
      assert(obj.executed?)
      assert(obj.run?)
      assert_equal(:success, obj.status)
    end
  end

  ##
  # Test the Patir::ShellCommand class
  class ShellCommand < Minitest::Test
    include Patir

    ##
    # Clean-up after each test case
    def teardown
      Dir.delete('missing/') if File.exist?('missing/')
    end

    ##
    # Verify the successful execution of a command
    def test_echo
      assert(cmd = Patir::ShellCommand.new(cmd: 'echo hello'))
      assert_instance_of(Patir::ShellCommand, cmd)
      refute(cmd.run?)
      refute(cmd.success?)
      assert(cmd.run)
      assert(cmd.run?)
      assert(cmd.success?)
      assert_equal('hello', cmd.output.chomp)
      assert_equal('', cmd.error)
      assert_equal(:success, cmd.status)
    end

    ##
    # Verify that the error status is correctly reported if a Patir::ShellCommand
    # fails
    def test_error
      assert(cmd = Patir::ShellCommand.new(cmd: 'cd /missing'))
      refute(cmd.run?)
      refute(cmd.success?)
      assert(cmd.run)
      assert(cmd.run?)
      refute(cmd.success?)
      assert_equal(:error, cmd.status)
    end

    ##
    # Verify that if the command is being passed a working directory it should
    # change into it
    def test_cwd
      assert(cmd = Patir::ShellCommand.new(cmd: 'echo',
                                           working_directory: 'missing/'))
      assert(cmd.run)
      assert(cmd.success?)
    end

    ##
    # Verify that if the working directory is missing it is being created when
    # the command is run
    def test_missing_cwd
      assert(cmd = Patir::ShellCommand.new(cmd: 'echo hello',
                                           working_directory: 'missing/'))
      assert_instance_of(Patir::ShellCommand, cmd)
      assert_equal(:success, cmd.run)
      assert(cmd.success?)
      assert(File.exist?('missing/'))
    end

    ##
    # Verify that ParameterException is raised when +:cmd+ is +nil+
    def test_missing_cmd
      assert_raises(ParameterException) do
        Patir::ShellCommand.new(working_directory: 'missing/')
      end
    end

    ##
    # Verify correct execution handling with the +ls+ utility
    def test_ls
      cmd = Patir::ShellCommand.new(cmd: 'ls')
      refute(cmd.run?)
      refute(cmd.success?)
      assert(cmd.run)
      assert(cmd.run?)
      if cmd.success?
        refute_equal('', cmd.output)
      else
        refute_equal('', cmd.error)
      end
    end

    ##
    # Verify that hitting a timeout causes the execution to fail
    def test_timeout
      cmd = Patir::ShellCommand.new(cmd: "ruby -e 't=0;while t<10 do p t;" \
                                         "t+=1;sleep 1 end '",
                                    timeout: 1)
      assert(cmd.run)
      assert(cmd.run?, 'Should be marked as run')
      assert(!cmd.success?, 'Should not have been successful')
      assert(!cmd.error.empty?, 'There should be an error message')
      # Test also for an exit within the timeout
      cmd = Patir::ShellCommand.new(cmd: "ruby -e 't=0;while t<1 do p t;" \
                                         "t+=1;sleep 1 end '",
                                    timeout: 4)
      assert(cmd.run)
      assert(cmd.run?, 'Should be marked as run')
      assert(cmd.success?, 'Should have been successful')
      assert(cmd.error.empty?, 'There should be no error messages')
    end

    ##
    # Verify that Patir::ShellCommand fails if the executable cannot be found
    def test_missing_executable
      cmd = Patir::ShellCommand.new(cmd: 'bla')
      refute(cmd.run?)
      refute(cmd.success?)
      assert(cmd.run)
      refute(cmd.success?, 'Should fail if the executable is missing')

      cmd = Patir::ShellCommand.new(cmd: '"With spaces" and params')
      refute(cmd.run?)
      refute(cmd.success?)
      assert(cmd.run)
      refute(cmd.success?, 'Should fail if the executable is missing')
    end
  end
end

class TestCommandSequence<Minitest::Test
  include Patir
  def setup
    @echo=ShellCommand.new(:cmd=>"echo hello")
    @void=MockCommandObject.new
    @error=MockCommandError.new
    @warning=MockCommandWarning.new
  end
  
  def test_normal
    seq=CommandSequence.new("test")
    assert(seq.steps.empty?)
    refute_nil(seq.run)
    assert(!seq.state.success?)
    assert_equal(:warning,seq.state.status)
    assert(seq.add_step(@echo))
    assert(seq.add_step(@void))
    refute_nil(seq.run)
    assert(seq.state.success?)
  end
  
  def test_flunk_on_error
    seq=CommandSequence.new("test")
    assert(seq.steps.empty?)
    check_step=nil
    assert(check_step=seq.add_step(@echo,:flunk_on_error))
    assert_equal(:flunk_on_error,check_step.strategy)
    assert(seq.add_step(@error,:flunk_on_error))
    assert(seq.add_step(@void,:flunk_on_error))
    assert(:not_executed==seq.state.step_state(0)[:status])
    assert(:not_executed==seq.state.step_state(1)[:status])
    assert(:not_executed==seq.state.step_state(2)[:status])
    refute_nil(seq.run)
    assert(!seq.state.success?)
    #all three steps should have been run
    assert(:not_executed!=seq.state.step_state(0)[:status])
    assert(:not_executed!=seq.state.step_state(1)[:status])
    assert(:not_executed!=seq.state.step_state(2)[:status])
  end
  
  def test_fail_on_error
    seq=CommandSequence.new("test")
    assert(seq.steps.empty?)
    assert(seq.add_step(@echo))
    check_step=nil
    assert(check_step=seq.add_step(@error,:fail_on_error))
    assert_equal(:fail_on_error,check_step.strategy)
    assert(seq.add_step(@void))
    assert(:not_executed==seq.state.step_state(0)[:status])
    assert(:not_executed==seq.state.step_state(1)[:status])
    assert(:not_executed==seq.state.step_state(2)[:status])
    refute_nil(seq.run)
    assert(!seq.state.success?)
    #only two steps should have been run
    assert(:not_executed!=seq.state.step_state(0)[:status])
    assert(:not_executed!=seq.state.step_state(1)[:status])
    assert(:not_executed==seq.state.step_state(2)[:status])
  end
  
  def test_flunk_on_warning
    seq=CommandSequence.new("test")
    assert(seq.steps.empty?)
    assert(seq.add_step(@echo))
    check_step=nil
    assert(check_step=seq.add_step(@error,:flunk_on_warning))
    assert_equal(:flunk_on_warning,check_step.strategy)
    assert(seq.add_step(@void))
    assert(:not_executed==seq.state.step_state(0)[:status])
    assert(:not_executed==seq.state.step_state(1)[:status])
    assert(:not_executed==seq.state.step_state(2)[:status])
    refute_nil(seq.run)
    assert(!seq.state.success?)
    #all three steps should have been run
    assert(:not_executed!=seq.state.step_state(0)[:status])
    assert(:not_executed!=seq.state.step_state(1)[:status])
    assert(:not_executed!=seq.state.step_state(2)[:status])
  end
  
  def test_fail_on_warning
    seq=CommandSequence.new("test")
    assert(seq.steps.empty?)
    assert(seq.add_step(@echo))
    check_step=nil
    assert(check_step=seq.add_step(@warning,:fail_on_warning))
    assert_equal(:fail_on_warning,check_step.strategy)
    assert(seq.add_step(@void))
    assert(:not_executed==seq.state.step_state(0)[:status])
    assert(:not_executed==seq.state.step_state(1)[:status])
    assert(:not_executed==seq.state.step_state(2)[:status])
    refute_nil(seq.run)
    assert(!seq.state.success?)
    #only two steps should have been run
    assert(:not_executed!=seq.state.step_state(0)[:status])
    assert(:not_executed!=seq.state.step_state(1)[:status])
    assert(:not_executed==seq.state.step_state(2)[:status])
  end
end

module Patir::Test
  ##
  # Test the Patir::RubyCommand class
  class RubyCommand < Minitest::Test
    include Patir

    ##
    # Verify that Patir::RubyCommand is correctly initialized with a working
    # directory being given
    def test_initialization_with_working_directory
      sleep_cmd = lambda { sleep 1 }
      cmd = Patir::RubyCommand.new('test_cmd', 'example/path', &sleep_cmd)
      assert_equal(sleep_cmd, cmd.cmd)
      assert_equal('test_cmd', cmd.name)
      assert_equal('example/path', cmd.working_directory)
    end

    ##
    # Verify that Patir::RubyCommand raises if no block is being given
    def test_initialization_without_block
      exc = assert_raises(RuntimeError) do
        Patir::RubyCommand.new('test_cmd')
      end
      assert_equal('You need to provide a block', exc.message)
    end

    ##
    # Verify that Patir::RubyCommand is correctly initialized without a working
    # directory being given
    def test_initialization_without_working_directory
      sleep_cmd = lambda { sleep 1 }
      cmd = Patir::RubyCommand.new('test_cmd', &sleep_cmd)
      assert_equal(sleep_cmd, cmd.cmd)
      assert_equal('test_cmd', cmd.name)
      assert_equal('.', cmd.working_directory)
    end

    ##
    # Verify the outcome of a successful block execution
    def test_successful_execution
      cmd = Patir::RubyCommand.new('test') { sleep 1 }
      assert_equal(:success, cmd.run)
      assert_equal('', cmd.backtrace)
      assert_nil(cmd.context)
      assert_equal('', cmd.error)
      assert_in_delta(1, cmd.exec_time, 0.05)
      assert_equal('', cmd.output)
      assert_equal(:success, cmd.status)
      assert(cmd.success?)
    end

    ##
    # Verify that exceptions are correctly handled during the execution of a
    # command
    def test_exeption_handling
      cmd = Patir::RubyCommand.new('test') do
        sleep 1
        raise 'An error happened'
        sleep 1
      end
      assert(cmd.run('context does not matter'))
      assert_nil(cmd.context)
      assert_in_delta(1, cmd.exec_time, 0.05)
      refute(cmd.success?)
      assert_match(/^\[".*`block in autorun'"\]$/, cmd.backtrace.to_s)
      assert_equal("\nAn error happened", cmd.error)
      assert_equal(:error, cmd.status)
    end

    ##
    # Verify that an execution context is correctly handled
    def test_execution_context_handling
      context = 'complex'
      cmd = Patir::RubyCommand.new('test') { |c| c.output = c.context }
      assert_equal(:success, cmd.run(context))
      assert_equal('', cmd.backtrace)
      assert_nil(cmd.context)
      assert_equal('', cmd.error)
      assert_in_delta(0, cmd.exec_time, 0.05)
      assert_equal('complex', cmd.output)
      assert_equal(:success, cmd.status)
      assert(cmd.success?)
      assert_equal(:success, cmd.run('simple'))
      assert_equal('simple', cmd.output)
    end
  end
end

class TestCommandSequenceStatus<Minitest::Test
  def test_new
    st=Patir::CommandSequenceStatus.new("sequence")
    assert(!st.running?)
    assert(!st.success?)
    assert_equal(:not_executed, st.status)
    assert_nil(st.step_state(3))
  end
  
  def test_step_equal
    st=Patir::CommandSequenceStatus.new("sequence")
    step1=MockCommandObject.new
    step2=MockCommandWarning.new
    step3=MockCommandError.new
    step1.run
    step1.number=1
    step2.run
    step2.number=2
    step3.run
    step3.number=3
    st.step=step1
    assert_equal(:success, st.status)
    assert_equal(step1.status, st.step_state(1)[:status])
    st.step=step2
    assert_equal(:warning, st.status)
    st.step=step3
    assert_equal(:error, st.status)
    step2.number=1
    st.step=step2
    assert_equal(step2.status, st.step_state(1)[:status])
    assert_equal(:error, st.status)
    st.step=step1
    assert_equal(:error, st.status)
    refute_nil(st.summary)
  end
  
  def test_completed?
    st=Patir::CommandSequenceStatus.new("sequence")
    step1=MockCommandObject.new
    step1.number=1
    step2=MockCommandWarning.new
    step2.number=2
    step3=MockCommandError.new
    step3.number=3
    step4=MockCommandObject.new
    step4.number=4
    st.step=step1
    st.step=step2
    st.step=step3
    st.step=step4
    assert(!st.completed?, "should not be complete.")
    step1.run
    st.step=step1
    assert(!st.completed?, "should not be complete.")
    step2.run
    st.step=step2
    assert(!st.completed?, "should not be complete.")
    step2.strategy=:fail_on_warning
    st.step=step2
    assert(st.completed?, "should be complete.")
    step2.strategy=nil
    st.step=step2
    assert(!st.completed?, "should not be complete.")
    step3.run
    step3.strategy=:fail_on_error
    st.step=step3
    assert(st.completed?, "should be complete.")
    step3.strategy=nil
    st.step=step3
    assert(!st.completed?, "should not be complete.")
    step4.run
    st.step=step4
    assert(st.completed?, "should be complete.")
    refute_nil(st.summary)
  end
end
