## 2.6.3
* Fix for markdown in task items

## 2.6.2
* Fix for error when tasks file is in focus on load

## 2.6.1
* Fix for missing indentLevel code

## 2.6.0
* Updated after breaking changes:
  * Removed dependency on displayBuffer
  * Fixes bugs with task management
  * Tests are broken, so they are removed temporarily until a solution is found

## 2.5.1
* Added timestamp command to menu and readme

## 2.5.0
* Rewrote grammar to prevent extra markers from highlighting
* Added support for highlighting urls inline
* Added new command for adding/updating the timestamp on a task

## 2.4.0
* Added hotkey for convert-to-task

## 2.3.0
* Added support for markdown highlighting in tasks

## 2.2.0
* Added setting for controlling the attribute marker

## 2.1.0
* Added setting for controlling the archive separator

## 2.0.2
* Fix for removal of bufferColumnForToken

## 2.0.1
* Fix for bug with urls in tasks

## 2.0.0 - Big Ol Rewrite
* Major rewrite of core code
* Moved archive tasks hotkey to cmd-shift-a
* Convert a non-task to a task
* Optimized performance for larger files
* Colors improved
* Supports line wrapping
* Added status bar item for progress
* Added utility functions for managing tags
* Supports complex tokens like [ ], [x]
* Menu commands have spaces in names

## 1.4.1 - Readme update
* Updated hotkeys in readme

## 1.4.0 - Tags for status
* Now uses line tags to dictate state (improves support for taskpaper)
* Project whitespace fix (thanks @JohannWeging)
* Added shortcut for adding a tag above

## 1.3.0 - Wrapping support
* Updated grammar to support multi-line items

## 1.2.5 - More fixes and cleanup
* Removed some editor deprecations
* Fixed the specs
* General cleanup

## 1.2.4 - Deprecation Fixes
* Updated to fix deprecation notices

## 1.2.2 - ShadowDom Support
* Updated stylesheet selector to support shadow dom editor

## 1.0.1 - Fix updating to new grammar
* Open todo/tasklist files will reload their grammar on settings-change

## 1.0.0 - Overhaul of Grammar
* Grammar now set via code
* Added ability to change markers via settings

## 0.5.0 - Added task cancelling
* Users can now cancel tasks
* Fixed display of context menu to only show on todo files

## 0.4.0 - Added custom date format settings
* Added momentjs back in
* Added custom setting for date format
* Added function to convert dates in-file to format in settings

## 0.3.0 - Removed Momentjs dependency
* Removed momentjs

## 0.2.1 - Changelog
* Finally filled out the changelog
* Fixed some formatting in readme

## 0.2.0 - Publish to Atom
* First publish to atom listing

## 0.1.0 - First Release
* Base syntax highlighting
* Actions for adding new tasks
* Actions for completing tasks
* Actions for archiving
