## What's New in 2.0

* Archiving tasks hotkey is now `cmd-shift-a`
* Can convert non-task lines to tasks
* Optimized performance in larger files
* Improved behind-the-scenes code
* Colors improved (also tested in light themes)
* Works with line wrapping
* Status bar shows progress
* See more in the [changelog](https://github.com/irrationalistic/atom-tasks/blob/master/CHANGELOG.md)

# Tasks Package

![example](https://raw.githubusercontent.com/irrationalistic/atom-tasks/master/images/tasks_example.png)

Special formatting for .todo and .taskpaper files. Allows you to easily add, complete, and archive your tasks.

Adjust the settings to match your ideal style. Change all the markers to '-' to match taskpaper.

Any line that ends with `:` will be considered a header (like `My Things:`)

Add tags to tasks by starting them with an `@`, such as `@important` or setting a value like `@due(tuesday)`.

This uses utf characters, so it is still valid as a plain text document.

You can also set a custom date/time format in the settings. These can be converted in an existing document using the Tasks: Update Timestamp Format.

Based off the awesome sublime text plugin https://github.com/aziz/PlainTasks

## Hotkeys

### Mac
* **cmd-enter:** add a new todo item below the current
* **cmd-shift-enter:** add a new todo item above the current
* **cmd-d:** toggle completion of the task
* **cmd-shift-a:** move all completed tasks to the archive section
* **ctrl-c:** cancel the selected tasks
* **ctrl-s:** add/update timestamp for current task

### PC, Linux
* **ctrl-enter:** add a new todo item below the current
* **ctrl-shift-enter:** add a new todo item above the current
* **ctrl-d:** toggle completion of the task
* **ctrl-shift-a:** move all completed tasks to the archive section
* **alt-c:** cancel the selected tasks
* **ctrl-shift-s:** add/update timestamp for current task

### Other Methods
* **Convert to Task:** Converts a non-task line to a task
* **Update Timestamps:** Attempt to convert cancelled and done tag timestamps to match the settings format
