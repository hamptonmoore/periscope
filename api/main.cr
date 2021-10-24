require "socket"
require "json"
require "router"
require "../shared/message.cr"
require "./http.cr"
require "log"

PORT = 1234
HOST = "0.0.0.0"

test_message = Message.new(1, MessageType::Introduction, IntroductionMessage.new("bos01.hammy.network", "Boston, USA", [Action.new("test", "Hello world", "Hello world action", %w(Host, IPAddress))]).to_json)
puts test_message.to_json

struct Host 
    include JSON::Serializable
    @[JSON::Field(ignore_serialize: true)]
    @socket : TCPSocket
    def initialize(@socket : TCPSocket, @hostname : String, @location : String, @actions : Array(Action))
    end 
end

Hosts = {} of String => Host

def handle_client(client)
    host = nil 
    while message = client.gets
        msg = Message.from_json(message)
        puts "[#{client}] #{msg.id}"
        if msg.type == MessageType::Introduction  
            intro = IntroductionMessage.from_json(msg.contents)
            puts "Host #{intro.hostname} has connected"
            Hosts[intro.hostname] = Host.new(client, intro.hostname, intro.location, intro.actions)
        end
    end
end

class WebServer
    include Router
  
    getter port

    def initialize(@port : Int32)
        
    end
    
    def draw_routes
        get "/" do |context, params|
            context.response.print "Hello router.cr!"
            context
        end
        get "/list-hosts" do |context, params|
            context.response.print Hosts.to_json
            context
        end
    end
    
    def run
        server = HTTP::Server.new(route_handler)
        server.bind_tcp port
        Log.info {"Starting Periscope HTTP API on port #{port}"}
        server.listen
    end
end
spawn do
    server = TCPServer.new(HOST, PORT)
    Log.info {"Starting Periscope TCP server on port #{PORT}"}
    while client = server.accept?
        spawn handle_client(client)
    end
end

spawn do
    web_server = WebServer.new(3000) 
    web_server.draw_routes
    web_server.run
end

sleep