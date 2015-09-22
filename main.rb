require 'sinatra'
require 'json'
require 'mongo'
require 'uri'

get '/env' do
  ENV['VCAP_SERVICES']
end

get '/rack/env' do
  ENV['RACK_ENV']
end

get '/' do
  'hello from sinatra'
end

get '/crash' do
  Process.kill('KILL', Process.pid)
end

post '/service/mongo/:key' do
  client = load_mongo
  value = request.env['rack.input'].read
  if client[:data_values].find('_id' => params[:key]).to_a.empty?
    client[:data_values].insert_one( { '_id' => params[:key], 'data_value' => value } )
  else
    client[:data_values].find('_id' => params[:key]).replace_one( {'data_value' => value } )
  end
  value
end

get '/service/mongo/:key' do
  client = load_mongo
  client[:data_values].find('_id' => params[:key]).to_a.first['data_value']
end

not_found do
  'This is nowhere to be found.'
end

error do
  error = env['sinatra.error']
<<TEXT
#{error.inspect}

Backtrace:
  #{error.backtrace.join("\n  ")}
TEXT
end

def load_mongo
  mongodb_service = load_service('mongo')
  client = Mongo::Client.new(mongodb_service['uri'])
end

def load_service(service_name)
  services = JSON.parse(ENV['VCAP_SERVICES'])
  service = nil
  services.each do |k, v|
    v.each do |s|
      if s['name'].downcase.include? service_name.downcase
        service = s['credentials']
      end
    end
  end
  service
end
