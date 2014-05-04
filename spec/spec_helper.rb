require 'rubygems'

require 'simplecov'
SimpleCov.start do
  add_filter "/spec/"
end

require 'vmbox'

Dir[File.expand_path(File.join(File.dirname(__FILE__),'support','**','*.rb'))].each {|f| require f}
