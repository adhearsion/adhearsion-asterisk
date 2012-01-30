require 'adhearsion/asterisk/call_controller_methods'

module Adhearsion
  module Asterisk
    class Plugin < Adhearsion::Plugin
      init do
        ::Adhearsion::CallController.mixin ::Adhearsion::Asterisk::CallControllerMethods
      end

    end#class
  end#module
end#module
