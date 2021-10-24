require "router"

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
    end
    
    def run
        server = HTTP::Server.new(route_handler)
        server.bind_tcp port
        Log.info {"Starting Periscope HTTP API on port #{port}"}
        server.listen
    end
end