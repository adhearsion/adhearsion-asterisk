# develop
  * Remove dependency on activesupport

# v1.5.0
  * Feature: Add `#say_characters`, which uses `SayDigits` to override adhearsion's built in SSML-generating method

# v1.4.0
  * Feature: Add `#goto`, which will pass a call to another context/extension/priority and disconnect from Adhearsion

# v1.3.1
  * Bugfix: Fixed `#execute` to concatenate multiple arguments correctly

# v1.3.0
  * Feature: Added explicit silence generation

# v1.2.1
  * Feature: added play_tone for DTMF in-call generation
  * Bugfix: "code is an undefined method" errors on executing AMI methods directly (issue #6)

# v1.2.0
  * Feature: Added helper to execute AMI actions easily

# v1.1.1
  * Fix error in header name for #agi_context

# v1.1.0
  * Adhearsion::Call now exposes the AGI context through #agi_context

# v1.0.0
  * Stable release

# v0.3.0 - 2012-03-29
  * Remove the monkey-patched version of `CallController#stream_file` since Punchblock now supports stopping output

# v0.2.0 - 2012-03-22
  * Update to work with Adhearsion 2.0.0.rc2
  * Remove overloaded `CallController#play` and `#play!` - we should use Adhearsion's core auto-detection

# v0.1.3 - 2012-01-30
  * Update to use Adhearsion's changed Plugin semantics (no more dialplan hooks)
  * Monkeypatch Adhearsion::CallController with Asterisk-specific overloads

# v0.1.2 - 2012-01-24
  * Fix a bug that prevented agi actions from completing properly due to accessing their completion reason incorrectly

# v0.1.1 - 2012-01-18
  * Depend on Adhearsion properly

# v0.1.0 - 2012-01-17
  * A whole bunch of new stuff

## Config Generators
  * Asterisk config generators moved from Adhearsion
  * Namespace cleanup

## Plugin Rename
  * ahn-asterisk to adhearsion-asterisk

# v0.0.1
  * First release!
