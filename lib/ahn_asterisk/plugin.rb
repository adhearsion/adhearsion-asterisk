module AhnAsterisk
  class Plugin < Adhearsion::Plugin
    dialplan :agi do |name, *params|
      execute_component_and_await_completion Punchblock::Component::Asterisk::AGI::Command.new :name => name, :params => params
    end
  end
end
