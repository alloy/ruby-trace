$:.unshift File.expand_path('..', __FILE__)
require 'ruby-trace'
require 'x'
require 'y'

trace = RubyTrace::Trace.new
x = X.new

trace.trace do
  x.y
end

#require 'pp'
#pp trace.files

trace.pretty_print
trace.save_as_html('html')
