require 'adhearsion/asterisk/call_controller_methods'
require "adhearsion/asterisk/generators/demo_generator"

module Adhearsion
  module Asterisk
    class Plugin < Adhearsion::Plugin
      init do
        ::Adhearsion::CallController.mixin ::Adhearsion::Asterisk::CallControllerMethods
      end

      generators :"adhearsion_asterisk:demo" => ::Adhearsion::Asterisk::DemoGenerator
    end#class
  end#module
end#module
