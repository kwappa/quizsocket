# -*- coding: utf-8 -*-
require 'em-websocket'
module QuizSocket

  def jsonize msg, command = :debug
    JSON.generate({
                    :command => command,
                    :value   => msg,
                  })
  end

  class QuizServer
    def self.run
      self.new.run
    end

    def run
      @channel = EM::Channel.new
      def @channel.push_message msg, command = :debug
        self.push jsonize msg, command
      end
      EventMachine::WebSocket.start(:host => "0.0.0.0", :port => 4141, :debug => true) do |ws|
        @@game ||= Game.new @channel
        puts "server start"

        ws.onopen    { on_web_socket_open(ws) }
        ws.onclose   { on_web_socket_close(ws) }
        ws.onmessage { |msg| on_web_socket_message(ws, msg) }
        ws.onerror   { |err| on_web_socket_error(ws, err) }
      end
    end

    def on_web_socket_open ws
      sid = @channel.subscribe { |msg| ws.send msg }
      @channel.push_message "#{ws.object_id} is connected"
      ws.send self.jsonize "your name", :name
      @@game.add_player ws
    end

    def on_web_socket_close ws
      @@game.delete_player ws
      @channel.push_message "#{ws.object_id} disconnected."
    end

    def on_web_socket_message ws, msg
      @@game.client_answer ws, msg.to_i
    end

    def on_web_socket_error ws, err
    end

  end
end
