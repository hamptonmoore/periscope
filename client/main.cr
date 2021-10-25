require "socket"
require "json"
require "log"
require "../shared/message.cr"

test_message = Message.new(1, MessageType::Introduction, IntroductionMessage.new("bos01.hammy.network", "Boston, USA", [Action.new("test", "Hello world", "Hello world action", %w(Host IPAddress))]).to_json)

while true
    client_active = Channel(Nil).new
    Log.info{"Connecting to server 1234..."} 
    begin
        client = TCPSocket.new("localhost", 1234)
        spawn do 
            while (response = client.gets) && !client.closed?
                msg = Message.from_json(response)
                if msg.type != MessageType::KeepAlive
                    Log.info {"[Server] #{msg.type} #{msg.contents}"}
                end
                
                if msg.type == MessageType::Action
                    action = ActionMessage.from_json(msg.contents)
                    puts action.to_json
                end
            end
        end

        spawn do
            last_keepalive = Time.local
            while !client.closed?
                begin
                    client.puts Message.new(5, MessageType::KeepAlive, "").to_json 
                rescue
                    client.close
                    client_active.send(nil)
                    next
                end
                
                sleep 10
            end
        end

        client.puts test_message.to_json

        client_active.receive
        Log.warn{"Lost connection to server! Trying again in 5 seconds"}
        sleep 5
    rescue
        Log.warn{"Server offline, Trying again in 5 seconds"}
        sleep 5
        next
    end
end