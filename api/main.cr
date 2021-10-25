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
    getter socket
    def initialize(@socket : TCPSocket, @hostname : String, @location : String, @actions : Array(Action))
    end 
end

struct HTTPResponse
    include JSON::Serializable
    def initialize(@success : Bool, @response : String)
    end
end

Hosts = {} of String => Host
ActiveActions = {} of String => Channel(String)

def handle_client(client)
    host = nil 
    while message = client.gets
        msg = Message.from_json(message)
        if msg.type != MessageType::KeepAlive
            puts "[#{client}] #{msg.type} #{msg.contents}"
        end
        if msg.type == MessageType::KeepAlive
            client.puts Message.new(msg.id, MessageType::KeepAlive, "").to_json
        end
        if msg.type == MessageType::Introduction  
            intro = IntroductionMessage.from_json(msg.contents)
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
        post "/action/" do |context, _|
            params = {} of String => String
            HTTP::FormData.parse(context.request) do |part|
                params[part.name] = part.body.gets_to_end
            end
            if params.has_key?("lghost")
                lg_host = params["lghost"]
                if Hosts.has_key?(lg_host)
                    lg_host = Hosts[lg_host]
                    lg_host.socket.puts Message.new(1000, MessageType::Action, ActionMessage.new("ping", ["1.1.1.1"]).to_json()).to_json 
                else
                    respond_http(context.response, HTTPResponse.new(false, "Requested lghost does not exist"))
                end
            else
                respond_http(context.response, HTTPResponse.new(false, "Missing lghost"))
            end
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

def respond_http(res : HTTP::Server::Response, d : HTTPResponse)
    res.headers.add("Content-Type", "application/json")
    res.headers.add("Server", "Periscope")
    res.print d.to_json
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