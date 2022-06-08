require 'runit/testcase'
require 'runit/testsuite'
require 'runit/cui/testrunner'

$testcases = []
prev_dir = Dir.pwd
module RUNIT
  class TestCase
    def TestCase.inherited(subclass)
      $testcases.push subclass
    end
  end
end
Dir["tests/utest*_*.rb"].each {|f| require f}
Dir["tests/test*_*.rb"].each {|f| require f}
Dir["tests/atest*_*.rb"].each {|f| require f}
Dir["tests/*test*_*.rb"].each {|f| require f}

if $0 == __FILE__
  testrunner = RUNIT::CUI::TestRunner.new
  suite = RUNIT::TestSuite.new
  $testcases.each {|tc| suite.add_test(tc.suite)}
  testrunner.run(suite)
end
