module AhnAsterisk
  class Plugin < Adhearsion::Plugin
    dialplan :agi do |name, *params|
      :foo
    end
  end
end
