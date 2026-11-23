# smart_workspace_switcher.wezterm

A smart Wezterm workspace switcher inspired by [t-smart-tmux-session-manager](https://github.com/joshmedeski/t-smart-tmux-session-manager) and its successor [sesh](https://github.com/joshmedeski/sesh)

## Usage

💨 Level up your workflow by switching between workspaces ⚡ ***BLAZINGLY FAST*** ⚡ with 1️⃣ keypress, the power of fuzzy finding and zoxide! 💨

![Demo gif](https://github.com/MLFlexer/smart_workspace_switcher.wezterm/assets/75012728/a4f82fcf-5304-4891-a1e2-346767678dc6)

## Dependencies

* [zoxide](https://github.com/ajeetdsouza/zoxide), or any command that prints one project path per line (see [Using another project list](#using-another-project-list))

### Setup

1. Require the plugin:

    ```lua
    local wezterm = require("wezterm")
    local workspace_switcher = wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")
    ```

2. Apply the default keybinding to the config:

    ```lua
    workspace_switcher.apply_to_config(config)
    ```

Or create your own keybinding, see [Configuration - Keybinding](#Keybinding).

### Configuration:
#### Keybinding
To add a custom keybinding:

  ```lua
  config.keys = {
    -- ...
    -- your other keybindings
    {
      key = "s",
      mods = "LEADER",
      action = workspace_switcher.switch_workspace(),
    },
    {
      key = "S",
      mods = "LEADER",
      action = workspace_switcher.switch_to_prev_workspace(),
    }
  }
  ```

#### Changing the Default Workspace Name
You can set a default workspace name:

```lua
config.default_workspace = "~"
```

#### Additional Filtering

You can include `extra_args` in the call to `switch_workspace` to filter the results of the zoxide query further. The `extra_args` is just a string concatenated to the command like so: `zoxide query -l <extra_args>`. For example, to select projects from a predefined list in `~/.projects`, call the plugin like this:

  ```lua
  workspace_switcher.switch_workspace({ extra_args = " | rg -Fxf ~/.projects" })
  ```

#### Using another project list

By default the plugin lists projects with `zoxide query -l` and records a chosen project with `zoxide add`. To use another source, such as [zop](https://github.com/theherk/zop), set a list command and a visit command:

  ```lua
  workspace_switcher.list_command = "zop list --no-tilde"
  workspace_switcher.visit_command = "zop visit"
  ```

`list_command` is a shell command that prints one absolute path per line. It replaces `zoxide query -l`, and `extra_args` is not used with it. `visit_command` runs with the project path as its last, shell-quoted argument.

The visit is recorded when you create a workspace from a path, and when you switch to an existing workspace whose name is a path (`~/x` or `/x`). The cached list is dropped after each visit, because the ranking changed.

When `$SHELL` is fish, commands run with `--no-config`, which is faster and keeps config output out of the list.

GUI applications often start with a minimal `PATH`, so give the commands by absolute path.

#### Changing elements of the fuzzy finder

You can change the list of elements of the fuzzy finder by setting a new function for `get_choices` likes so:

```lua
local workspace_switcher = wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")
workspace_switcher.get_choices = function(opts)
  -- this will ONLY show the workspace elements, NOT the Zoxide results
  return workspace_switcher.choices.get_workspace_elements({})
end
```

By default the function uses the following functions to create a list:

```lua
workspace_switcher.choices.get_workspace_elements({ id: string, label: string }[])
workspace_switcher.choices.get_zoxide_elements({ id: string, label: string }[], {extra_args?: string, workspace_ids?: workspace_ids}?)
```

#### Updating the Right Status with the Path

To add the selected path to the right status bar, use the `smart_workspace_switcher.workspace_switcher.chosen` event emitted when choosing a workspace:

  ```lua
  wezterm.on("smart_workspace_switcher.workspace_switcher.chosen", function(window, workspace)
    local gui_win = window:gui_window()
    local base_path = string.gsub(workspace, "(.*[/\\])(.*)", "%2")
    gui_win:set_right_status(wezterm.format({
      { Foreground = { Color = "green" } },
      { Text = base_path .. "  " },
    }))
  end)

  wezterm.on("smart_workspace_switcher.workspace_switcher.created", function(window, workspace)
    local gui_win = window:gui_window()
    local base_path = string.gsub(workspace, "(.*[/\\])(.*)", "%2")
    gui_win:set_right_status(wezterm.format({
      { Foreground = { Color = "green" } },
      { Text = base_path .. "  " },
    }))
  end)
  ```

#### Events

The following events are available and can be used to trigger custom behavior:

* `smart_workspace_switcher.workspace_switcher.start` - Triggered when the fuzzy finder starts.
* `smart_workspace_switcher.workspace_switcher.canceled` - Triggered if no element is chosen.
* `smart_workspace_switcher.workspace_switcher.selected` - Triggered when an element is selected.
* `smart_workspace_switcher.workspace_switcher.created` - Triggered after creating and switching to a new workspace.
* `smart_workspace_switcher.workspace_switcher.chosen` - Triggered after switching to a workspace.
* `smart_workspace_switcher.workspace_switcher.switched_to_prev` - Triggered after switching to a previous workspace.

> [!NOTE]
> The `created` and `chosen` events emit [MuxWindow](https://wezfurlong.org/wezterm/config/lua/mux-window/) objects while the others emit [GuiWindow](https://wezfurlong.org/wezterm/config/lua/window/index.html) objects. 

Example usage:

  ```lua
  wezterm.on("smart_workspace_switcher.workspace_switcher.chosen", function(window, workspace)
    wezterm.log_info("THIS IS EMITTED FROM THE CALLBACK")
  end)
  ```

#### Workspace Formatter

Set a custom workspace formatter using the following example. For more information, see the [Wezterm formatting docs](https://wezfurlong.org/wezterm/config/lua/wezterm/format.html):

  ```lua
  workspace_switcher.workspace_formatter = function(label)
    return wezterm.format({
      { Attribute = { Italic = true } },
      { Foreground = { Color = "green" } },
      { Background = { Color = "black" } },
      { Text = "󱂬: " .. label },
    })
  end
  ```

#### Zoxide Path

To define a custom path to `zoxide`:

  ```lua
  workspace_switcher.zoxide_path = "/path/to/zoxide"
  ```

## Development

The tests run the plugin against a stub `wezterm`:

  ```sh
  lua test/run.lua
  ```
