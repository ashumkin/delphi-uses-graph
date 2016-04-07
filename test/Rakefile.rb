# encoding: utf-8
# vim: set shiftwidth=2 tabstop=2 expandtab:

require 'rake'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << '..'
  #t.verbose = true
  t.ruby_opts |= ["-d"] if Rake::application.options.trace
end

