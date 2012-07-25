$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'test/unit'
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

class TestCommand<Test::Unit::TestCase
  #tests the default values set by the module
  def test_module
    obj=MockCommandObject.new
    assert_equal("",obj.name)
    assert_equal(:not_executed,obj.status)
    assert(!obj.run?)
    assert_nothing_raised{obj.run}
    assert(obj.run?)
    assert_equal(:success,obj.status)
    assert_equal("",obj.output)
    assert_equal("",obj.error)
    assert_equal(0,obj.exec_time)
    assert_nothing_raised{obj.reset}
    assert_equal(:not_executed,obj.status)
  end
end

class TestShellCommand<Test::Unit::TestCase
  include Patir
  def teardown
    Dir.delete("missing/") if File.exists?("missing/")
  end
  #test the expected behaviour of a succesfull command
  def test_echo
    cmd=nil
    assert_nothing_raised(){cmd=ShellCommand.new(:cmd=>"echo hello")}
    assert_not_nil(cmd)
    assert(!cmd.run?)
    assert(!cmd.success?)
    assert_nothing_raised(){cmd.run}
    assert(cmd.run?)
    assert(cmd.success?)
    assert_equal("hello\n",cmd.output)
    assert_equal("",cmd.error)
    assert_equal(:success,cmd.status)
  end
  #test that error status is reported correctly, by testing a command that fails.
  def test_error
    cmd=nil
    assert_nothing_raised(){cmd=ShellCommand.new(:cmd=>"cd /missing")}
    assert(!cmd.run?)
    assert(!cmd.success?)
    assert_nothing_raised(){cmd.run}
    assert(cmd.run?)
    assert(!cmd.success?)
    assert_equal(:error,cmd.status)
  end
  #when passed a wroking directory, the command should change into that directory
  def test_cwd
    cmd=nil
    assert_nothing_raised(){cmd=ShellCommand.new(:cmd=>"echo", :working_directory=>"missing/")}
    assert_nothing_raised(){cmd.run}
    assert(cmd.success?)
  end
  
  #when the working directory is missing, it should be created when the command is run
  def test_missing_cwd
    cmd=nil
    assert_nothing_raised(){cmd=ShellCommand.new(:cmd=>"echo hello", :working_directory=>"missing/")}
    assert_not_nil(cmd)
    assert_equal(:success,cmd.run)
    assert(cmd.success?)
    assert(File.exists?("missing/"))
  end
  #an exception should be thrown when :cmd is nil
  def test_missing_cmd
    assert_raise(ParameterException){cmd=ShellCommand.new(:working_directory=>"missing/")}
  end
  #an exception should be thrown when no parameters are passed
  def test_missing_params
    assert_raise(ParameterException){cmd=ShellCommand.new()}
  end
  #test with another program
  def test_ls
    cmd=ShellCommand.new(:cmd=>"ls")
    assert(!cmd.run?)
    assert(!cmd.success?)
    assert_nothing_raised(){cmd.run}
    assert(cmd.run?)
    if cmd.success?
      assert_not_equal("", cmd.output)
    else
      assert_not_equal("", cmd.error)
    end
  end
end

class TestCommandSequence<Test::Unit::TestCase
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
    assert_nothing_raised{seq.run}
    assert(!seq.state.success?)
    assert_equal(:warning,seq.state.status)
    assert_nothing_raised{seq.add_step(@echo)}
    assert_nothing_raised{seq.add_step(@void)}
    assert_nothing_raised{seq.run}
    assert(seq.state.success?)
  end
  
  def test_flunk_on_error
    seq=CommandSequence.new("test")
    assert(seq.steps.empty?)
    check_step=nil
    assert_nothing_raised{check_step=seq.add_step(@echo,:flunk_on_error)}
    assert_equal(:flunk_on_error,check_step.strategy)
    assert_nothing_raised{seq.add_step(@error,:flunk_on_error)}
    assert_nothing_raised{seq.add_step(@void,:flunk_on_error)}
    assert(:not_executed==seq.state.step_state(0)[:status])
    assert(:not_executed==seq.state.step_state(1)[:status])
    assert(:not_executed==seq.state.step_state(2)[:status])
    assert_nothing_raised{seq.run}
    assert(!seq.state.success?)
    #all three steps should have been run
    assert(:not_executed!=seq.state.step_state(0)[:status])
    assert(:not_executed!=seq.state.step_state(1)[:status])
    assert(:not_executed!=seq.state.step_state(2)[:status])
  end
  
  def test_fail_on_error
    seq=CommandSequence.new("test")
    assert(seq.steps.empty?)
    assert_nothing_raised{seq.add_step(@echo)}
    check_step=nil
    assert_nothing_raised{check_step=seq.add_step(@error,:fail_on_error)}
    assert_equal(:fail_on_error,check_step.strategy)
    assert_nothing_raised{seq.add_step(@void)}
    assert(:not_executed==seq.state.step_state(0)[:status])
    assert(:not_executed==seq.state.step_state(1)[:status])
    assert(:not_executed==seq.state.step_state(2)[:status])
    assert_nothing_raised{seq.run}
    assert(!seq.state.success?)
    #only two steps should have been run
    assert(:not_executed!=seq.state.step_state(0)[:status])
    assert(:not_executed!=seq.state.step_state(1)[:status])
    assert(:not_executed==seq.state.step_state(2)[:status])
  end
  
  def test_flunk_on_warning
    seq=CommandSequence.new("test")
    assert(seq.steps.empty?)
    assert_nothing_raised{seq.add_step(@echo)}
    check_step=nil
    assert_nothing_raised{check_step=seq.add_step(@error,:flunk_on_warning)}
    assert_equal(:flunk_on_warning,check_step.strategy)
    assert_nothing_raised{seq.add_step(@void)}
    assert(:not_executed==seq.state.step_state(0)[:status])
    assert(:not_executed==seq.state.step_state(1)[:status])
    assert(:not_executed==seq.state.step_state(2)[:status])
    assert_nothing_raised{seq.run}
    assert(!seq.state.success?)
    #all three steps should have been run
    assert(:not_executed!=seq.state.step_state(0)[:status])
    assert(:not_executed!=seq.state.step_state(1)[:status])
    assert(:not_executed!=seq.state.step_state(2)[:status])
  end
  
  def test_fail_on_warning
    seq=CommandSequence.new("test")
    assert(seq.steps.empty?)
    assert_nothing_raised{seq.add_step(@echo)}
    check_step=nil
    assert_nothing_raised{check_step=seq.add_step(@warning,:fail_on_warning)}
    assert_equal(:fail_on_warning,check_step.strategy)
    assert_nothing_raised{seq.add_step(@void)}
    assert(:not_executed==seq.state.step_state(0)[:status])
    assert(:not_executed==seq.state.step_state(1)[:status])
    assert(:not_executed==seq.state.step_state(2)[:status])
    assert_nothing_raised{seq.run}
    assert(!seq.state.success?)
    #only two steps should have been run
    assert(:not_executed!=seq.state.step_state(0)[:status])
    assert(:not_executed!=seq.state.step_state(1)[:status])
    assert(:not_executed==seq.state.step_state(2)[:status])
  end
end

class TestRubyCommand<Test::Unit::TestCase
  include Patir
  def test_normal_ruby
    cmd=RubyCommand.new("test"){sleep 1}
    assert_nothing_raised() { cmd.run}
    assert(cmd.success?, "Not successful.")
    assert_equal(:success, cmd.status)
  end
  def test_error_ruby
    cmd=RubyCommand.new("test"){raise "Error"}
    assert_nothing_raised() { cmd.run}
    assert(!cmd.success?, "Successful?!")
    assert_equal(:error, cmd.status)
  end
  def test_context
    context="complex"
    cmd=RubyCommand.new("test"){|c| c.output=c.context}
    assert_nothing_raised() { cmd.run(context)}
    assert(cmd.success?, "Not successful.")
    assert_equal(context, cmd.output)
    assert_nothing_raised() { cmd.run("other")}
    assert_equal("other", cmd.output)
    assert_equal(:success, cmd.status)
  end
end

class TestCommandSequenceStatus<Test::Unit::TestCase
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
    assert_nothing_raised() {  puts st.summary }
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
    assert_nothing_raised() {  puts st.summary }
  end
end