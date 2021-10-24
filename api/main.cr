require "socket"
require "json"
require "router"
require "../shared/message.cr"
require "log"

class Config
    include JSON::Serializable
    getter http_port
    getter http_host
    getter tcp_port
    getter tcp_host

    def initialize(@http_port : Int32, @http_host : String, @tcp_port : Int32, @tcp_host : String)
        
    end 
end

config = Config.new(3000, "0.0.0.0", 1234, "0.0.0.0") 

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
        puts "[#{client}] #{msg.type} #{msg.contents}"
        if msg.type == MessageType::KeepAlive
            client.puts Message.new(msg.id, MessageType::KeepAlive, "").to_json
        end
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
    getter host

    def initialize(@host : String, @port : Int32)
        
    end
    
    def draw_routes
        get "/" do |context, params|
            context.response.print "Hello from Periscope!"
            context
        end
        get "/list-hosts" do |context, params|
            context.response.print Hosts.to_json
            context
        end
    end
    
    def run
        server = HTTP::Server.new(route_handler)
        server.bind_tcp host, port
        Log.info {"Starting Periscope HTTP API on port #{port}"}
        server.listen
    end
end
spawn do
    server = TCPServer.new(config.tcp_host, config.tcp_port)
    Log.info {"Starting Periscope TCP server on port #{config.tcp_port}"}
    while client = server.accept?
        spawn handle_client(client)
    end
end

spawn do
    web_server = WebServer.new(config.http_host, config.http_port) 
    web_server.draw_routes
    web_server.run
end

sleep