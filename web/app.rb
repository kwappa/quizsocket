# encoding: UTF-8
require 'bundler'
Bundler.setup
require 'sinatra'
require 'haml'

get '/' do
  redirect '/quiz.html'
end
