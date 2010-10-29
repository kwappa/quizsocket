# -*- coding: utf-8 -*-
require 'bundler'
Bundler.setup
APP_ROOT = File.dirname(File.dirname(File.expand_path(__FILE__)))
$: << APP_ROOT

Dir.glob(File.join(APP_ROOT, 'app', '*.rb')) { |rb| require rb }
include QuizSocket
