# -*- coding: utf-8 -*-

require 'rubygems'
require 'sinatra/base'
require 'yaml'
require 'json'

class Pileup < Sinatra::Base
  @@config = nil

  configure do
    set :config, File.join(settings.root, 'config.yml')
    set :hooks_dir, File.join(settings.root, 'hooks')
  end

  helpers do
    def exec(filename, options = {})
      env = options[:env] || {}
      args = options[:args] || []

      options.delete(:env)
      options.delete(:args)

      pid = spawn(env, filename, *args, options)

      Thread.new do
        result = Process.waitpid2 pid
        yield result if block_given?
      end

      pid
    end

    def resolve(name)
      config['aliases'].has_key?(name) ? config['aliases'][name] : name
    end

    def build_env(payload)
      {
        'REPOSITORY_NAME' => payload['repository']['name'],
        'REPOSITORY_URL' => payload['repository']['url'],
        'REPOSITORY_OWNER_NAME' => payload['repository']['owner']['name']
      }
    rescue
      {}
    end
  end

  def config
    @@config ||= YAML.load_file(settings.config)
  end

  def config_clear_cache
    @@config = nil
  end

  def on_complete(result, payload)
    # なんかあれば..
  end

  before do
    content_type :text
  end

  post '/' do
    halt 400 if params[:payload].nil?
    
    config_clear_cache

    begin
      payload = JSON.parse(params[:payload])
      repository_name = payload['repository']['name']
      filename = File.join(settings.hooks_dir, resolve(repository_name))

      if File.exists?(filename) && File.executable?(filename)
        exec filename, :env => build_env(payload) do |result|
          on_complete result, payload
        end
      end

      'ok'
    rescue
      500
    end
  end

  not_found do
    'not found'
  end

  error 400 do
    'bad request'
  end

  error 500 do
    'internal server error'
  end

  error do
    'internal server error'
  end
end