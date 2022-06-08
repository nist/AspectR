require 'runit/testcase'
require 'runit/testsuite'
require 'runit/cui/testrunner'
require 'runit/topublic'
include RUNIT::ToPublic

require 'aspectr'
include AspectR

class Logger < Aspect
  def initialize(io = STDOUT)
    @io = io
  end
		 
  def _tick; "#{Time.now.strftime('%Y-%m-%d %X')}"; end

  def enter(method, object, exitstatus, *args)
    @io.puts "enter: #{_tick} #{object.class}##{method}: called with #{args.inspect}"
  end
    
  def exit(method, object, exitstatus, *args)
    @io.print "exit: #{_tick} #{object.class}##{method}: exited "
    if exitstatus.kind_of?(Array)
      @io.puts "normally returning #{exitstatus[0].inspect}"
    elsif exitstatus == true
      @io.puts "with exception '#{$!}'"
    else
      @io.puts "normally"
    end
  end

  def senter(method, object, exitstatus, *args)
    @io.puts "senter: #{_tick} Entering #{object.id}##{method}"
  end

  def sexit(method, object, exitstatus, *args)
    @io.puts "sexit: #{_tick} Exiting #{object.id}##{method}"
  end
end

class Counter < Aspect
  attr_reader :incrementer_cnt
  
  def initialize
    @counters = {}
  end

  def wrap(target, *methods)
    super(target, :inc, nil, *methods)
  end

  def unwrap(target, *methods)
    super(target, :inc, nil, *methods)
  end

  def [](object, method)
    method = method.id2name if method.kind_of?(Symbol)
    @counters[object][method]
  end

  private
  def inc(method, object, *args)
    begin
      @counters[object][method] += 1
    rescue NameError
      @counters[object] = {} unless @counters[object]
      @counters[object][method] = 1
    end
  end  
end

class Test
  attr_reader :tt

  def say(hello)
    return hello + " world"
  end
  
  def inspect; id.inspect; end
  
  def sayz(*args)
    raise NotImplementedError, "NYI!"
  end
end

class HistoryStdOut
  attr_reader :history
  def initialize
    @history = Array.new
  end
  def puts(str)
    if @last_was_print
      @history[-1] += str
    else
      @history.push str
    end
    @last_was_print = false
  end
  def print(str)
    @history.push str
    @last_was_print = true
  end
  def last; @history.last; end
end

class CodeWrapper < Aspect
  alias old_wrap wrap
  def wrap(target, *methods)
    wrap_with_code(target, "p 'pre'", "p 'post'", *methods)
  end
  def code_wrap(target, *methods)
    wrap_with_code(target,"CodeWrapper.enter","CodeWrapper.leave", *methods)
  end
  @@counter = 0
  def CodeWrapper.enter; @@counter += 1; end
  def CodeWrapper.leave; @@counter += 1; end
  def CodeWrapper.counter; @@counter; end
end

class T2; def m; end; end

class TestAspectR < RUNIT::TestCase
  # Just so that we can use previously written tests. Clean up when there is
  # time!
  @@logger = Logger.new(@@hso = HistoryStdOut.new)
  @@counter = Counter.new
  @@t, @@u = Test.new, Test.new

  def setup
  end

  def test_01_wrap
    @@counter.wrap(Test, :say) # Wrap counter on Test#say
    assert_equals("hello world", @@t.say("hello"))
    assert_equals("hello world", @@u.say("hello"))
    assert_equals(1, @@counter[@@t, :say])
    assert_equals(1, @@counter[@@u, :say])
    @@t.say("my")
    assert_equals(2, @@counter[@@t, :say])
    assert_equals(1, @@counter[@@u, :say])
  end

  def test_02_class_wrapping
    @@logger.wrap(Test, :enter, :exit, /sa/)
    @@t.say("t: hello")
    assert_match(@@hso.history[-2], /enter.*Test#say: called with \[.*\]/)
    assert_match(@@hso.history[-1], /exit.*Test#say: exited/)
    @@u.say("u: hello")
    assert_match(@@hso.history[-2], /enter.*Test#say: called with \[.*\]/)
    assert_match(@@hso.history[-1], /exit.*Test#say: exited/)
  end

  def test_03_singleton_wrapping
    @@logger.wrap(@@t, :senter, :sexit, :say)
    @@t.say("t: hello")
    assert_match(@@hso.history[-4], /senter/)
    assert_match(@@hso.history[-3], /enter/)
    assert_match(@@hso.history[-2], /exit/)
    assert_match(@@hso.history[-1], /sexit/)
    @@u.say("u: hello")
    assert_match(@@hso.history[-2], /enter/)
    assert_match(@@hso.history[-1], /exit/)
  end

  def test_04_unwrapping
    @@logger.unwrap(Test, :enter, :exit, /sa/)
    @@t.say("t: hello") # senter and sexit should still be there...
    assert_match(@@hso.history[-2], /senter/)
    assert_match(@@hso.history[-1], /sexit/)
    l = @@hso.history.length
    @@u.say("u: hello")
    assert_equals(l, @@hso.history.length) # Nothing printed!
  end

  def test_05_dynamically_changing_advice
    Logger.class_eval <<-'EOC'
      def senter(*args)
	@io.puts "senter version 2.0"
      end
    EOC
    @@t.say("t: hello")
    assert_match(@@hso.history[-2], /senter version 2\.0/)
  end

  def test_06_partial_unwrap
    @@logger.unwrap(@@t, :senter, nil, :say)
    l = @@hso.history.length
    @@t.say("t: hello") # Should use sexit but not senter
    assert_equals(l+1, @@hso.history.length)
    assert_match(@@hso.history[-1], /sexit/)
  end

  def test_07_exception_in_method
    @@logger.wrap(@@t, nil, :exit, :sayz)
    l = @@hso.history.length
    begin
      @@t.sayz 1
    rescue Exception; end
    assert_equals(l+1, @@hso.history.length)
    assert_match(@@hso.history[-1], /exit/)
  end

  def test_08_counter
    assert_equals(7, @@counter[@@t, :say])
    @@counter.unwrap(Test, :say) 
    @@t.say("t: hello")
    assert_equals(7, @@counter[@@t, :say])
  end

  def test_09_transparency
    assert_equals(1, Test.instance_method(:say).arity)
    assert_equals(-1, Test.instance_method(:sayz).arity)

    @@counter.wrap(Test, :tt)
    assert_equals(0, Test.instance_method(:tt).arity)
  end

  def test_10_special_methods
    @@logger.wrap(Array, :enter, nil, :[], :[]=, :initialize)
    a = Array.new(2)
    assert_match(@@hso.history.last, /enter/); l = @@hso.history.length
    a[1]
    assert_equals(l+1, @@hso.history.length)
    assert_match(@@hso.history.last, /enter/); l = @@hso.history.length
    a[1] = 10
    assert_equals(l+1, @@hso.history.length)
    assert_match(@@hso.history.last, /enter/); l = @@hso.history.length
    @@logger.unwrap(Array, :[], :[]=, :initialize)
  end

  def test_11_code_wrapping  
    assert_equals(0, CodeWrapper.counter)
    CodeWrapper.new.code_wrap(T2, :m)
    T2.new.m
    assert_equals(2, CodeWrapper.counter)
  end
end

# Run if we were directly called
if $0 == __FILE__
  testrunner = RUNIT::CUI::TestRunner.new
  if ARGV.size == 0
    suite = TestAspectR.suite
  else
    suite = RUNIT::TestSuite.new
    ARGV.each do |testmethod|
      suite.add_test(TestAspectR.new(testmethod))
    end
  end
  testrunner.run(suite)
end

class T3; def m; end; def m2; end; end

def time(n = 100_000, &block)
  start = Process.times.utime
  n.times{block.call}
  Process.times.utime - start
end

def test_overhead
  puts "\nOverhead"
  t = T3.new
  puts "Time for unwrapped: #{tuw = time(50_000) {t.m}}"
  CodeWrapper.new.code_wrap(T3, :m)
  puts "Time for code-wrapped: #{tw = time(50_000) {t.m}}"
  puts "A slowdown of #{tw/tuw}"
end
