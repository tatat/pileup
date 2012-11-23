# -*- coding: utf-8 -*-

require 'rubygems'
require 'sinatra/base'
require 'yaml'
require 'json'

class Pileup < Sinatra::Base

  configure do
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
      aliases = config['aliases']
      aliases.has_key?(name) ? aliases[name] : name
    end

    def config
      # 毎回読み込む
      YAML.load_file(File.join(settings.root, 'config.yml'))
    end
  end

  before do
    content_type :text
  end

  post '/' do
    halt 400 if params[:payload].nil?

    begin
      payload = JSON.parse(params[:payload])
      repository_name = payload['repository']['name']
      filename = File.join(settings.hooks_dir, resolve(repository_name))

      if File.exists?(filename) && File.executable?(filename)
        env = {
          'REPOSITORY_NAME' => payload['repository']['name'],
          'REPOSITORY_URL' => payload['repository']['url'],
          'REPOSITORY_OWNER_NAME' => payload['repository']['owner']['name']
        }

        exec filename, :env => env do |result|
          # なんかあれば..
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