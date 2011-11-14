require 'adhearsion'
require 'active_support/dependencies/autoload'
require 'ahn_asterisk/version'
require 'ahn_asterisk/plugin'

module AhnAsterisk
  extend ActiveSupport::Autoload

  autoload :QueueProxy
end
