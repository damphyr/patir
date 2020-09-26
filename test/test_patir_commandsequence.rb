# Copyright (c) 2007-2020 Vassilis Rizopoulos. All rights reserved.

# frozen_string_literal: true

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

  class CommandSequenceStatus < Minitest::Test
    def test_new
      st = Patir::CommandSequenceStatus.new('sequence')
      refute(st.running?)
      refute(st.success?)
      assert_equal(:not_executed, st.status)
      assert_nil(st.step_state(3))
    end

    def test_step_equal
      st = Patir::CommandSequenceStatus.new('sequence')
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
      st = Patir::CommandSequenceStatus.new('sequence')
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
      refute(st.completed?, 'should not be complete.')
      step1.run
      st.step = step1
      refute(st.completed?, 'should not be complete.')
      step2.run
      st.step = step2
      refute(st.completed?, 'should not be complete.')
      step2.strategy = :fail_on_warning
      st.step = step2
      assert(st.completed?, 'should be complete.')
      step2.strategy = nil
      st.step = step2
      refute(st.completed?, 'should not be complete.')
      step3.run
      step3.strategy = :fail_on_error
      st.step = step3
      assert(st.completed?, 'should be complete.')
      step3.strategy = nil
      st.step = step3
      refute(st.completed?, 'should not be complete.')
      step4.run
      st.step = step4
      assert(st.completed?, 'should be complete.')
      refute_nil(st.summary)
    end
  end
end
