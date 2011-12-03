adhearsion-asterisk
===========

adhearsion-asterisk is an Adhearsion Plugin providing Asterisk-specific dialplan methods, AMI access, and access to Asterisk configuration.

Features
--------

Dialplan methods

  * agi
  * execute
  * verbose
  * get_variable
  * set_variable
  * sip_add_header
  * sip_get_header
  * variable
  * meetme
  * voicemail
  * voicemail_main
  * queue
  * play
  * play!
  * play_time
  * play_numeric
  * play_soundfile

Asterisk configuration generators

  * agents.conf
  * queues.conf
  * voicemail.conf

### TODO

  * Asterisk dynamic features (aka. features.conf)

Requirements
------------

* Adhearsion 2.0+
* Asterisk 1.8+

Install
-------

Add `adhearsion-asterisk` to your Adhearsion app's Gemfile.

Examples
--------

### Dialplan


```ruby
vm {
  voicemail "8000"
}

echotest {
  play 'demo-echotest'
  execute 'Echo'
  play 'demo-echodone'
}

saytime {
  t = Time.now
  date = t.to_date
  date_format = 'ABdY'
  execute "SayUnixTime", t.to_i, date_format
  play_time date, :format => date_format
}

callqueue {
  case extension
  when 5001
    queue 'sales'
  when 5002
    queue 'support'
  end
}

salesagent {
  queue('sales').join!
}

supportagent {
  queue('support').join!
}
```

### Config generation

Stand-alone example

```ruby
require 'adhearsion/asterisk'
require 'adhearsion/asterisk/config_generator/voicemail'

config_generator = Adhearsion::Asterisk::ConfigGenerator::Voicemail.new
asterisk_config_file = "voicemail.conf"

File.open(asterisk_config_file, "w") do |file|
  file.write config_generator
end
```

agents.conf, and queue.conf can be done similarly.

Author
------

Original author: [Ben Langfeld](https://github.com/benlangfeld)

Contributors:
  * [Taylor Carpenter](https://github.com/taylor)

Links
-----
* [Source](https://github.com/adhearsion/adhearsion-asterisk)
* [Documentation](http://rdoc.info/github/adhearsion/adhearsion-asterisk/master/frames)
* [Bug Tracker](https://github.com/adhearsion/adhearsion-asterisk/issues)

Note on Patches/Pull Requests
-----------------------------

* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  * If you want to have your own version, that is fine but bump version in a commit by itself so I can ignore when I pull
* Send me a pull request. Bonus points for topic branches.

Copyright
---------

Copyright (c) 2011 Ben Langfeld. MIT licence (see LICENSE for details).
