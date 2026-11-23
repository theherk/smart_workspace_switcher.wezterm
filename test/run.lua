-- Runs the plugin against a stub `wezterm`. Usage: lua test/run.lua (from the repo root).
local calls = {}
local stdout = ""
local actions = {}
local workspaces = { "default" }
local current = "default"

local function perform(_, action) actions[#actions + 1] = action end
package.loaded["wezterm"] = {
	target_triple = "aarch64-apple-darwin",
	home_dir = "/home/me",
	action = setmetatable({}, { __index = function(_, k) return function(v) return { k, v } end end }),
	mux = { get_workspace_names = function() return workspaces end, all_windows = function() return { { get_workspace = function() return current end } } end },
	on = function() end,
	emit = function() end,
	format = function(items) return items[#items].Text end,
	action_callback = function(f) return f end,
	log_error = function() end,
	split_by_newlines = function(s)
		local out = {}
		for line in s:gmatch("[^\n]+") do out[#out + 1] = line end
		return out
	end,
	shell_quote_arg = function(a) return "'" .. a:gsub("'", "'\\''") .. "'" end,
	run_child_process = function(args)
		calls[#calls + 1] = args[#args]
		return true, stdout, ""
	end,
}

local pub = dofile("plugin/init.lua")
local failures = 0
local function check(name, cond)
	if not cond then failures = failures + 1 end
	print((cond and "ok   " or "FAIL ") .. name)
end

-- default: zoxide
stdout = "/home/me/a\n/home/me/b\n"
local choices = pub.get_choices({}, 0)
check("default lists with zoxide query -l", calls[#calls]:find("zoxide query %-l") ~= nil)
check("labels use ~", choices[#choices].label == "~/b" or choices[#choices - 1].label == "~/a")

-- list_command replaces zoxide
pub.list_command = "zop list --no-tilde"
calls = {}
pub.get_choices({}, 0)
check("list_command is used", calls[1] == "zop list --no-tilde")
check("zoxide is not called", not calls[1]:find("zoxide"))

-- extra_args is ignored when list_command is set
calls = {}
pub.get_choices({ extra_args = "| rg x" }, 0)
check("extra_args does not leak into list_command", calls[1] == "zop list --no-tilde")

-- choices drop paths that already are workspaces, matched by label
workspaces = { "default", "~/a" }
stdout = "/home/me/a\n/home/me/b\n"
local labels = {}
for _, c in ipairs(pub.get_choices({}, 0)) do labels[#labels + 1] = c.id end
check("an open workspace is not offered twice", select(2, table.concat(labels, ","):gsub("/home/me/a", "")) == 0)
check("other projects still are", table.concat(labels, ","):find("/home/me/b") ~= nil)

-- cache serves a second call, and a visit invalidates it
workspaces = { "default" }
pub.list_command = "zop list --no-tilde"
calls = {}
pub.get_choices({}, 300)
pub.get_choices({}, 300)
check("a cached list is reused", #calls == 1)
pub.visit_command = "zop visit"
-- zoxide_chosen is local; reach it through switch_workspace's selector callback
local selector
local window = {
	perform_action = function(_, action)
		if type(action) == "table" and action[1] == "InputSelector" then selector = action[2] end
		if type(action) == "table" and action[1] == "SwitchToWorkspace" then current = action[2].name end
	end,
	active_workspace = function() return current end,
}
pub.switch_workspace({}, 300)(window, {})
calls = {}
selector.action(window, {}, "/home/me/b", "~/b")
check("choosing a project records the visit", calls[#calls]:find("^zop visit '/home/me/b'") ~= nil)
check("the path is shell quoted", calls[#calls] == "zop visit '/home/me/b'")
calls = {}
pub.get_choices({}, 300)
check("a visit invalidates the cached list", #calls == 1)

-- choosing an existing path-named workspace also records the visit
workspaces = { "default", "~/c" }
calls = {}
selector.action(window, {}, "~/c", "~/c")
check("switching to an open workspace records the visit", calls[#calls] == "zop visit '/home/me/c'")
calls = {}
selector.action(window, {}, "default", "default")
check("a non-path workspace is not recorded", #calls == 0)

-- a path with a quote cannot break out of the command
workspaces = { "default" }
calls = {}
selector.action(window, {}, "/home/me/it's", "~/it's")
check("quotes are escaped", calls[#calls] == "zop visit '/home/me/it'\\''s'")

-- default visit still uses zoxide add
pub.visit_command = nil
calls = {}
selector.action(window, {}, "/home/me/z", "~/z")
check("default visit is zoxide add", calls[#calls] == "zoxide add '/home/me/z'")

os.exit(failures == 0 and 0 or 1)
