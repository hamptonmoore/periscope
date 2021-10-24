enum MessageType
    Introduction
    Command
    Reply
    KeepAlive
end

class Message 
    include JSON::Serializable
    getter id
    getter type
    getter contents
    def initialize(@id : Int64, @type : MessageType, @contents : String) 
    end
end

class IntroductionMessage
    include JSON::Serializable
    getter hostname
    getter location
    getter actions
    def initialize(@hostname : String, @location : String, @actions : Array(Action))
        
    end
end

struct Action
    include JSON::Serializable
    def initialize(@id : String, @name : String, @description : String, @arguments : Array(String)) end
end