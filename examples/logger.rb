# Example of how ApsectR can be used: method call logging (tracing)
require 'aspectr' 
include AspectR 

class Logger < Aspect
  def tick; "#{Time.now.strftime('%Y-%m-%d %X')}"; end 

  def log_enter(method, object, exitstatus, *args) 
    $stderr.puts "#{tick} #{self.class}##{method}: args = #{args.inspect}" 
  end 

  def log_exit(method, object, exitstatus, *args) 
    $stderr.print "#{tick} #{self.class}##{method}: exited " 
    if exitstatus.kind_of?(Array) 
      $stderr.puts "normally returning #{exitstatus[0].inspect}" 
    elsif exitstatus == true 
      $stderr.puts "with exception '#{$!}'" 
    else 
      $stderr.puts "normally" 
    end 
  end 
end 

if $0 == __FILE__
  class SomeClass 
    def some_method 
      sleep 1
      puts "Hello!" 
      [:t, "sd"] 
    end

    def some_other_method(*args) 
      raise NotImplementedError 
    end 
  end 

  Logger.new.wrap(SomeClass, :log_enter, :log_exit, /some/) 
  SomeClass.new.some_method 
  begin 
    SomeClass.new.some_other_method(1, true) 
  rescue Exception 
  end
end

