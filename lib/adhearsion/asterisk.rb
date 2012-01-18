require 'adhearsion'
require 'active_support/dependencies/autoload'
require 'adhearsion/asterisk/version'
require 'adhearsion/asterisk/plugin'

module Adhearsion
  module Asterisk
    extend ActiveSupport::Autoload

    autoload :QueueProxy
  end
end
