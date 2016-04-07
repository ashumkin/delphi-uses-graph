# encoding: utf-8
# vim: set shiftwidth=2 tabstop=2 expandtab:

require File.expand_path('../../delphi-uses-graph.rb', __FILE__)

require 'test/unit'

class TestWalker < Test::Unit::TestCase
  def setup
    @opts = Delphi::Uses::Graph::Options.new(['-P', File.expand_path('../resources/testproject.dpr', __FILE__)])
    @walker = Delphi::Uses::Graph::UnitWalker.new
  end

  def test_every_unit
    @walker.run(@opts.project)
    assert_equal 'testproject -- {unit1 unit2 formunit3 unit4 interface_only_unit unit5 unit6}', @walker.dependencies['testproject'].to_s
    assert_equal 'unit1 -- {unit2 formunit3}', @walker.dependencies['unit1'].to_s
    assert_equal 'unit2 -- {unit1 formunit3}', @walker.dependencies['unit2'].to_s
    assert_equal 'formunit3 -- {unit1 unit4}', @walker.dependencies['formunit3'].to_s
    assert_equal 'unit4 -- {unit2}', @walker.dependencies['unit4'].to_s
    assert_equal 'unit5 -- ', @walker.dependencies['unit5'].to_s
    assert_equal 'unit6 -- ', @walker.dependencies['unit6'].to_s
  end

  def test_dot
    @walker.run(@opts.project)
    dot = "graph {
    testproject -- {unit1 unit2 formunit3 unit4 interface_only_unit unit5 unit6};
    unit1 -- {unit2 formunit3};
    unit2 -- {unit1 formunit3};
    formunit3 -- {unit1 unit4};
    unit4 -- {unit2};
}"
    assert_equal dot, @walker.dot
  end
end
