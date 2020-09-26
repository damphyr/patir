# Copyright (c) 2007-2020 Vassilis Rizopoulos. All rights reserved.

require_relative '../lib/patir/commandsequence'

module Patir::Test
  class CommandSequence < Minitest::Test
    include Patir

    def setup
      @echo = Patir::ShellCommand.new(cmd: 'echo hello')
      @error = MockCommandError.new
      @void = MockCommandObject.new
      @warning = MockCommandWarning.new
    end

    def test_normal
      seq = Patir::CommandSequence.new('test')
      assert(seq.steps.empty?)
      refute_nil(seq.run)
      refute(seq.state.success?)
      assert_equal(:warning, seq.state.status)
      assert(seq.add_step(@echo))
      assert(seq.add_step(@void))
      refute_nil(seq.run)
      assert(seq.state.success?)
    end

    def test_flunk_on_error
      seq = Patir::CommandSequence.new('test')
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
      # All three steps should have been run
      refute_equal(:not_executed, seq.state.step_state(0)[:status])
      refute_equal(:not_executed, seq.state.step_state(1)[:status])
      refute_equal(:not_executed, seq.state.step_state(2)[:status])
    end

    def test_fail_on_error
      seq = Patir::CommandSequence.new('test')
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
      # Only two steps should have been run
      refute_equal(:not_executed, seq.state.step_state(0)[:status])
      refute_equal(:not_executed, seq.state.step_state(1)[:status])
      assert_equal(:not_executed, seq.state.step_state(2)[:status])
    end

    def test_flunk_on_warning
      seq = Patir::CommandSequence.new('test')
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
      # All three steps should have been run
      refute_equal(:not_executed, seq.state.step_state(0)[:status])
      refute_equal(:not_executed, seq.state.step_state(1)[:status])
      refute_equal(:not_executed, seq.state.step_state(2)[:status])
    end

    def test_fail_on_warning
      seq = Patir::CommandSequence.new('test')
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
      # Only two steps should have been run
      refute_equal(:not_executed, seq.state.step_state(0)[:status])
      refute_equal(:not_executed, seq.state.step_state(1)[:status])
      assert_equal(:not_executed, seq.state.step_state(2)[:status])
    end
  end
end
