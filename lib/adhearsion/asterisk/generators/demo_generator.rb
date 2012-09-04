module Adhearsion
  module Asterisk
    class DemoGenerator < ::Adhearsion::Generators::Generator
      def create_demo
        raise Exception, "Generator commands need to be run in an Adhearsion app directory" unless Adhearsion::ScriptAhnLoader.in_ahn_application?('.')
        self.destination_root = '.'
        template 'lib/simon_game.rb', "lib/simon_game.rb"
        directory 'sounds'
        puts "NOTES: You will need to have a route in config/adhearsion.rb that points to the new controller, such as:\n\troute 'default', SimonGame\nA newly generated application already contains the correct route."
      end

      def self.base_root
        File.dirname __FILE__
      end
    end
  end
end

