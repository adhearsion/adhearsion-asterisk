module AhnAsterisk
  class Plugin < Adhearsion::Plugin
    dialplan :agi do |name, *params|
      component = Punchblock::Component::Asterisk::AGI::Command.new :name => name, :params => params
      execute_component_and_await_completion component
      complete_reason = component.complete_event.resource.reason
      [:code, :result, :data].map { |p| complete_reason.send p }
    end
  end
end
