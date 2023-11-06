# Copyright (c) 2012-2021 Vassilis Rizopoulos. All rights reserved.

# frozen_string_literal: true

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), "..", "lib")

require "minitest/autorun"
require "patir/command"

##
# Mock object intended for testing the Patir::Command class
class MockCommandObject
  include Patir::Command
end

class MockCommandWarning
  include Patir::Command
  def run(_context = nil)
    @status = :warning
    return :warning
  end
end

class MockCommandError
  include Patir::Command
  def run(_context = nil)
    @status = :error
    return :error
  end
end

##
# Verify functionality of the Patir::Command class
class TestCommand < Minitest::Test
  ##
  # Verify that all members are initialized correctly
  def test_initializations
    obj = MockCommandObject.new

    assert_equal("", obj.backtrace)
    assert_equal("", obj.error)
    refute(obj.executed?)
    assert_equal(0, obj.exec_time)
    assert_equal("", obj.name)
    assert_nil(obj.number)
    assert_equal("", obj.output)
    refute(obj.run?)
    assert_equal(:not_executed, obj.status)
    assert_nil(obj.strategy)
    refute(obj.success?)
  end

  ##
  # Verify that Patir::Command#reset resets internal state as expected
  def test_reset
    obj = MockCommandObject.new

    # Change values which shall be reset
    obj.error = "Something bad happened exactly here"
    assert_equal("Something bad happened exactly here", obj.error)
    obj.exec_time = 382
    assert_equal(382, obj.exec_time)
    obj.output = "Hello World!"
    assert_equal("Hello World!", obj.output)
    obj.status = :some_new_state
    assert_equal(:some_new_state, obj.status)

    # Call reset on the object
    obj.reset

    # Verify expected state
    assert_equal("", obj.backtrace)
    assert_equal("", obj.error)
    assert_equal(0, obj.exec_time)
    assert_equal("", obj.output)
    assert_equal(:not_executed, obj.status)
  end

  ##
  # Verify that Patir::Command#run changes state as expected
  def test_run
    obj = MockCommandObject.new
    refute(obj.executed?)
    refute(obj.run?)
    assert_equal(:not_executed, obj.status)
    refute(obj.success?)

    # Run once
    assert_equal(:success, obj.run)

    # Verify expected changed state
    assert(obj.executed?)
    assert(obj.run?)
    assert_equal(:success, obj.status)
    assert(obj.success?)
  end
end

##
# Verify functionality of the Patir::ShellCommand class
class TestShellCommand < Minitest::Test
  ##
  # Clean-up actions after each test case
  def teardown
    Dir.delete("missing/") if File.exist?("missing/")
  end

  ##
  # Verify that a successfully executed command yields the expected results
  def test_echo
    assert(cmd = Patir::ShellCommand.new(:cmd => "echo hello"))
    refute(cmd.executed?)
    refute(cmd.run?)
    assert_equal(:not_executed, cmd.status)
    refute(cmd.success?)
    assert_equal(:success, cmd.run)
    assert_equal("", cmd.error)
    assert(cmd.executed?)
    assert_equal("hello\n", cmd.output)
    assert(cmd.run?)
    assert_equal(:success, cmd.status)
    assert(cmd.success?)
  end

  ##
  # Verify that a failed command execution yields the expected results
  def test_error
    assert(cmd = Patir::ShellCommand.new(:cmd => "cd /missing"))
    assert_equal(:error, cmd.run)
    assert(!cmd.error.empty?, "No error output")
    assert(cmd.executed?)
    assert_equal("", cmd.output)
    assert(cmd.run?)
    assert_equal(:error, cmd.status)
    refute(cmd.success?)
  end

  ##
  # Verify that a working directory is created if missing
  def test_cwd
    assert(cmd = Patir::ShellCommand.new(:cmd => "echo", :working_directory => "missing/"))
    assert_equal(:success, cmd.run)
    assert(cmd.success?)
    assert(File.exist?("missing/"))
  end

  ##
  # Verify that a Patir::ParameterException is thrown if no command is given
  def test_missing_cmd
    assert_raises(Patir::ParameterException) do
      Patir::ShellCommand.new(:working_directory => "missing/")
    end
  end

  ##
  # Verify that execution is possible for a little more "complex" program
  def test_ls
    cmd = Patir::ShellCommand.new(:cmd => "ls")
    assert(cmd.run)
    assert(cmd.run?)
    if cmd.success?
      refute_equal("", cmd.output)
    else
      refute_equal("", cmd.error)
    end
  end

  ##
  # Verify that commands are invocations are properly interrupted if the timeout
  # is exceeded
  def test_timeout
    cmd = Patir::ShellCommand.new(:cmd => "ruby -e 't=0;while t<10 do p t;t+=1;sleep 1 end '", :timeout => 1)
    assert(cmd.run)
    assert(cmd.run?, "Should be marked as run")
    assert(!cmd.success?, "Should not have been successful")
    assert(!cmd.error.empty?, "There should be an error message")
    # test also for an exit within the timeout
    cmd = Patir::ShellCommand.new(:cmd => "ruby -e 't=0;while t<1 do p t;t+=1;sleep 1 end '", :timeout => 4)
    assert(cmd.run)
    assert(cmd.run?, "Should be marked as run")
    assert(cmd.success?, "Should have been successful")
    assert(cmd.error.empty?, "There should be no error messages")
  end

  ##
  # Verify that errors are correctly reported if no callable executable is given
  def test_missing_executable
    cmd = Patir::ShellCommand.new(:cmd => "bla")
    assert_equal(:error, cmd.run)
    assert(cmd.run?)
    refute(cmd.success?)
    refute(cmd.success?, "Should fail if the executable is missing")

    cmd = Patir::ShellCommand.new(:cmd => '"With spaces" and params')
    assert_equal(:error, cmd.run)
    assert(cmd.run?)
    refute(cmd.success?)
    refute(cmd.success?, "Should fail if the executable is missing")
  end
end

class TestCommandSequence < Minitest::Test
  include Patir
  def setup
    @echo = ShellCommand.new(:cmd => "echo hello")
    @void = MockCommandObject.new
    @error = MockCommandError.new
    @warning = MockCommandWarning.new
  end

  def test_normal
    seq = CommandSequence.new("test")
    assert(seq.steps.empty?)
    refute_nil(seq.run)
    assert(!seq.state.success?)
    assert_equal(:warning, seq.state.status)
    assert(seq.add_step(@echo))
    assert(seq.add_step(@void))
    refute_nil(seq.run)
    assert(seq.state.success?)
  end

  def test_flunk_on_error
    seq = CommandSequence.new("test")
    assert(seq.steps.empty?)
    assert(check_step = seq.add_step(@echo, :flunk_on_error))
    assert_equal(:flunk_on_error, check_step.strategy)
    assert(seq.add_step(@error, :flunk_on_error))
    assert(seq.add_step(@void, :flunk_on_error))
    assert_equal(:not_executed, seq.state.step_state(0)[:status])
    assert_equal(:not_executed, seq.state.step_state(1)[:status])
    assert_equal(:not_executed, seq.state.step_state(2)[:status])
    refute_nil(seq.run)
    assert(!seq.state.success?)
    # all three steps should have been run
    refute_equal(:not_executed, seq.state.step_state(0)[:status])
    refute_equal(:not_executed, seq.state.step_state(1)[:status])
    refute_equal(:not_executed, seq.state.step_state(2)[:status])
  end

  def test_fail_on_error
    seq = CommandSequence.new("test")
    assert(seq.steps.empty?)
    assert(seq.add_step(@echo))
    assert(check_step = seq.add_step(@error, :fail_on_error))
    assert_equal(:fail_on_error, check_step.strategy)
    assert(seq.add_step(@void))
    assert_equal(:not_executed, seq.state.step_state(0)[:status])
    assert_equal(:not_executed, seq.state.step_state(1)[:status])
    assert_equal(:not_executed, seq.state.step_state(2)[:status])
    refute_nil(seq.run)
    assert(!seq.state.success?)
    # only two steps should have been run
    refute_equal(:not_executed, seq.state.step_state(0)[:status])
    refute_equal(:not_executed, seq.state.step_state(1)[:status])
    assert_equal(:not_executed, seq.state.step_state(2)[:status])
  end

  def test_flunk_on_warning
    seq = CommandSequence.new("test")
    assert(seq.steps.empty?)
    assert(seq.add_step(@echo))
    assert(check_step = seq.add_step(@error, :flunk_on_warning))
    assert_equal(:flunk_on_warning, check_step.strategy)
    assert(seq.add_step(@void))
    assert_equal(:not_executed, seq.state.step_state(0)[:status])
    assert_equal(:not_executed, seq.state.step_state(1)[:status])
    assert_equal(:not_executed, seq.state.step_state(2)[:status])
    refute_nil(seq.run)
    assert(!seq.state.success?)
    # all three steps should have been run
    refute_equal(:not_executed, seq.state.step_state(0)[:status])
    refute_equal(:not_executed, seq.state.step_state(1)[:status])
    refute_equal(:not_executed, seq.state.step_state(2)[:status])
  end

  def test_fail_on_warning
    seq = CommandSequence.new("test")
    assert(seq.steps.empty?)
    assert(seq.add_step(@echo))
    assert(check_step = seq.add_step(@warning, :fail_on_warning))
    assert_equal(:fail_on_warning, check_step.strategy)
    assert(seq.add_step(@void))
    assert_equal(:not_executed, seq.state.step_state(0)[:status])
    assert_equal(:not_executed, seq.state.step_state(1)[:status])
    assert_equal(:not_executed, seq.state.step_state(2)[:status])
    refute_nil(seq.run)
    assert(!seq.state.success?)
    # only two steps should have been run
    refute_equal(:not_executed, seq.state.step_state(0)[:status])
    refute_equal(:not_executed, seq.state.step_state(1)[:status])
    assert_equal(:not_executed, seq.state.step_state(2)[:status])
  end
end

##
# Verify functionality of the Patir::RubyCommand class
class TestRubyCommand < Minitest::Test
  ##
  # Verify that new instances of RubyCommand are created correctly
  def test_default_initialize
    cmd = Patir::RubyCommand.new("A command") { sleep 1 }
    assert_nil(cmd.context)
    assert_equal("A command", cmd.name)
    assert_equal(".", cmd.working_directory)
  end

  ##
  # Verify that new instances with all parameters of RubyCommand are created
  # correctly
  def test_initialize
    cmd = Patir::RubyCommand.new("Another command", "path/to/some/dir") do
      sleep 1
    end
    assert_nil(cmd.context)
    assert_equal("Another command", cmd.name)
    assert_equal("path/to/some/dir", cmd.working_directory)
  end

  ##
  # Verify that an exception is thrown if no block is passed on initialization
  def test_initialization_failure
    assert_raises(
      RuntimeError, "A block must be provided to RubyCommand upon initialization"
    ) do
      Patir::RubyCommand.new("A third command")
    end
  end

  ##
  # Verify that a valid block invocation is handled as expected
  def test_normal_execution
    cmd = Patir::RubyCommand.new("Successful command") { sleep 1 }

    # Check execution and success state before
    refute(cmd.executed?)
    refute(cmd.run?)
    assert_equal(:not_executed, cmd.status)
    refute(cmd.success?)

    # Run command
    assert_equal(:success, cmd.run)

    # Check execution and success state after
    assert(cmd.executed?)
    assert(cmd.run?)
    assert(cmd.success?, "RubyCommand run unsuccessfuly.")
    assert_equal(:success, cmd.status)
    assert_in_delta(1.0, cmd.exec_time, 0.1)
  end

  ##
  # Verify that errors during block invocation are handled properly
  def test_erroneous_execution
    cmd = Patir::RubyCommand.new("Failing command") { raise "Error" }

    # Run command
    assert_equal(:error, cmd.run)

    # Verify state of the instance
    refute(cmd.backtrace.empty?)
    assert_equal("\nError", cmd.error)
    assert(cmd.executed?)
    assert(cmd.run?)
    assert_equal(:error, cmd.status)
    refute(cmd.success?, "Successful?!")
  end

  ##
  # Verify that a context is being handled and passed correctly
  def test_context_handling
    context = "complex"

    # Run command
    cmd = Patir::RubyCommand.new("Context test") { |c| c.output = c.context }

    # Verify successful execution and correct output
    assert_equal(:success, cmd.run(context))
    assert_equal(context, cmd.output)
    assert(cmd.success?, "Not successful.")

    # Run with different context and verify successful exec and correct output
    assert_equal(:success, cmd.run("other context"))
    assert_equal("other context", cmd.output)
    assert_equal(:success, cmd.status)
    assert(cmd.success?, "Not successful.")
  end
end

##
# Verify functionality of the Patir::CommandSequenceStatus class
class TestCommandSequenceStatus < Minitest::Test
  ##
  # Verify that new instances are initialized correctly
  def test_initialize
    st = Patir::CommandSequenceStatus.new("Test Sequence Name")

    # Variables
    assert_nil(st.sequence_id)
    assert_equal("Test Sequence Name", st.sequence_name)
    assert_equal("", st.sequence_runner)
    assert_in_delta(Time.now, st.start_time)
    assert_equal(:not_executed, st.status)
    assert_instance_of(Hash, st.step_states)

    # Methods
    refute(st.completed?)
    assert_equal(0, st.exec_time)
    refute(st.executed?)
    refute(st.running?)
    assert_equal(:not_executed, st.status)
    assert_nil(st.step_state(3))
    refute(st.success?)
  end

  ##
  # Verify correct response of the running? method
  def test_running
    st = Patir::CommandSequenceStatus.new("Test Sequence Name")
    refute(st.running?)
    st.status = :running
    assert(st.running?)
  end

  ##
  # Verify that steps are added correctly
  def test_step_addition
    st = Patir::CommandSequenceStatus.new("Step Add Sequence")
    assert_equal(:not_executed, st.status)
    step = MockCommandObject.new
    step.exec_time = 94.22
    step.error = "Oh oh, this shouldn't be"
    step.name = "Test Step Name"
    step.output = "Some step output"
    step.status = :success
    step.strategy = :fail_always
    st.step = step
    assert_equal(:success, st.status)
    step.status = :running
    st.step = step
    assert_equal(:running, st.status)
  end

  def test_step_equal
    st = Patir::CommandSequenceStatus.new("sequence")
    step1 = MockCommandObject.new
    step2 = MockCommandWarning.new
    step3 = MockCommandError.new
    step1.run
    step1.number = 1
    step2.run
    step2.number = 2
    step3.run
    step3.number = 3
    st.step = step1
    assert_equal(:success, st.status)
    assert_equal(step1.status, st.step_state(1)[:status])
    st.step = step2
    assert_equal(:warning, st.status)
    st.step = step3
    assert_equal(:error, st.status)
    step2.number = 1
    st.step = step2
    assert_equal(step2.status, st.step_state(1)[:status])
    assert_equal(:error, st.status)
    st.step = step1
    assert_equal(:error, st.status)
    refute_nil(st.summary)
  end

  def test_completed?
    st = Patir::CommandSequenceStatus.new("sequence")
    step1 = MockCommandObject.new
    step1.number = 1
    step2 = MockCommandWarning.new
    step2.number = 2
    step3 = MockCommandError.new
    step3.number = 3
    step4 = MockCommandObject.new
    step4.number = 4
    st.step = step1
    st.step = step2
    st.step = step3
    st.step = step4
    assert(!st.completed?, "should not be complete.")
    step1.run
    st.step = step1
    assert(!st.completed?, "should not be complete.")
    step2.run
    st.step = step2
    assert(!st.completed?, "should not be complete.")
    step2.strategy = :fail_on_warning
    st.step = step2
    assert(st.completed?, "should be complete.")
    step2.strategy = nil
    st.step = step2
    assert(!st.completed?, "should not be complete.")
    step3.run
    step3.strategy = :fail_on_error
    st.step = step3
    assert(st.completed?, "should be complete.")
    step3.strategy = nil
    st.step = step3
    assert(!st.completed?, "should not be complete.")
    step4.run
    st.step = step4
    assert(st.completed?, "should be complete.")
    refute_nil(st.summary)
  end

  ##
  # Verify correct response of the success? method
  def test_success
    st = Patir::CommandSequenceStatus.new("Test Sequence Name")
    refute(st.success?)
    st.status = :success
    assert(st.success?)
  end
end
