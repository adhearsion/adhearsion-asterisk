Feature: Adhearsion demo controller generator
  As an Adhearsion developer
  In order to showcase operation on Asterisk
  I want to generate a demo controller

  Scenario: Generate a demo controller
    When I run `ahn create path/somewhere`
    And I cd to "path/somewhere"
    And I run `ahn generate adhearsion_asterisk:demo`
    Then the following directories should exist:
      | lib                               |
      | sounds                            |

    And the following files should exist:
      | lib/simon_game.rb                 |
      | sounds/good.gsm                   |
      | sounds/times.gsm                  |
      | sounds/wrong-try-again-smarty.gsm |

    And the file "lib/simon_game.rb" should contain "class SimonGame < Adhearsion::CallController"
