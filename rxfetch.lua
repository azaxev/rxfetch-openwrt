#!/usr/bin/lua

--[[

rxfetch.lua

OpenWrt fork of Mangeshrex's rxfetch. See https://github.com/Mangeshrex/rxfetch

Usage:

Add "/usr/bin/lua /root/rxfetch.lua" at the end of /etc/profile
Modify /etc/banner, bottom info is redundant

TODO:

- shebang not working, need to be called with lua ...
- check very nicely done fork https://github.com/mayTermux/rxfetch-termux

]]

-- testing stuff 
-- package.path = "/root/.lualibs/?.lua;"..package.path
-- pp = require("lua-pretty-print")

-- colors
esc = string.char(27)	-- Lua interpretatin of escape \nnn in strings is sketchy
						-- testing 5.1, used decimal instead octal, \x033 was '!'
--bold="(tput bold)"
magenta=esc.."[1;35m"
green=esc.."[1;32m"
white=esc.."[1;37m"
blue=esc.."[1;34m"
red=esc.."[1;31m"
black=esc.."[1;40;30m"
yellow=esc.."[1;33m"
cyan=esc.."[1;36m"
reset=esc.."[0m"
bgyellow=esc.."[1;43;33m"
bgwhite=esc.."[1;47;37m"
c0=reset
c1=magenta
c2=green
c3=white
c4=blue
c5=red
c6=yellow
c7=cyan
c8=black
c9=bgyellow
c10=bgwhite

function echo(str)
	local function __macro(key) return _G[key] end
	str = str:gsub("%${([^}]+)}", __macro )
	print(str)
end

function trim(str)
	str = str:gsub("%s+$", "")
	return str
end

function exec(cmd)
	local handle = io.popen(cmd)
	local output = trim(handle:read("*a"))
	handle:close()
	handle = io.popen("echo $?")
	local retval = tonumber(handle:read("*a"))
	handle:close()
	if 0 == retval then
		return output
	end
	return ""
end

function cat (filepath)
	local f = io.open(filepath)
	if f == nil then return "" end
	local text = f:read("*a")
	f:close()
	return text
end

function file_exists (fpath)
	local f = io.open(fpath, 'r')
	if f == nil then return false end
	f:close()
	return true
end

-- todo: still using shell commands
function get_init()
	local osname = exec("uname -o")
	local init
	if osname == "Android" then
		init = 'init.rc'
	elseif osname == "Darwin" then
		init = 'launchd'
	elseif not os.execute("pidof systemd") then
		init = 'systemd'
	elseif file_exists('/sbin/openrc') then
		init = 'openrc'
	elseif file_exists('/sbin/dinit') then
		init = 'dinit'
	else
		init = exec("cut -d ' ' -f 1 /proc/1/comm")
	end
	return init
end

function get_distro_name()
	local text = cat("/etc/os-release")
	local function __getkey(key)
		local val = text:match('\n'..key..'="([^"]*)"')
		return val
	end
	return __getkey("PRETTY_NAME") .. " " .. __getkey("BUILD_ID")
end

-- todo: still using shell commands
function get_storage_info()
	return exec("df -h / | awk 'NR == 2 { print $3\" / \"$2\" (\"$5\")\" }'")
end

function get_mem()
	local text = '\n' .. cat("/proc/meminfo")
	local function __getkey(key)
		local val = text:match('\n'..key..':%s*(%d+)')
		return val
	end
	local MemTotal = tonumber(__getkey("MemTotal"))
	local MemFree = tonumber(__getkey("MemFree"))
	return string.format("%.0f / %.0f MB (%.0f%%)", MemFree/1024, MemTotal/1024, MemFree/MemTotal*100)
end

function get_uptime()
	local uptime = cat("/proc/uptime")
	uptime = uptime:gsub(" .+", "")
	local days = math.floor(uptime / 86400)
	uptime = uptime - days * 86400
	local hours = math.floor(uptime / 3600)
	uptime = uptime - hours * 3600
	local minutes = math.floor((uptime + 30) / 60)
	return string.format("%d days, %d hours, %d minutes", days, hours, minutes)
end

function get_board()
	return cat("/etc/board.json"):match('"name"%s*:%s*"([^"]+)"')
end

function get_ssh_connection()
	local s = os.getenv("SSH_CONNECTION")
	local a = {} for m in s:gmatch("[^%s]+") do a[#a+1]=m end
	if #a == 4 then return a[3]..':'..a[4] end
	return "?"
end

board = get_board()
distro = get_distro_name()
kernel = trim(cat("/proc/sys/kernel/osrelease"))
pkgcount = exec("opkg list-installed | wc -l") -- this one stays as shell command
shell = os.getenv("SHELL")
mem = get_mem()
init = get_init()
uptime = get_uptime()
storage_info = get_storage_info()
ssh_connection = get_ssh_connection()

echo("               ")
echo("               ${c5}board${c3}   ${board}")
echo("               ${c1}os${c3}      ${distro}")
echo("               ${c2}kernel${c3}  ${kernel}")
echo("     ${c3}•${c8}_${c3}•${c0}       ${c7}pkgs${c3}    ${pkgcount}")
echo("     ${c8}${c0}${c9}oo${c0}${c8}|${c0}       ${c4}shell${c3}   ${shell}")
echo("     ${c8}/${c0}${c10} ${c0}${c8}'\'${c0}      ${c6}ram${c3}     ${mem}")
echo("    ${c9}(${c0}${c8}\_;/${c0}${c9})${c0}      ${c1}init${c3}    ${init}")
echo("               ${c7}up${c3}      ${uptime}")
echo("               ${c6}disk${c3}    ${storage_info}")
echo("               ${c5}sshd${c3}    ${ssh_connection}")
echo("               ")
echo("        ${c6}󰮯  ${c6}${c2}󰊠  ${c2}${c4}󰊠  ${c4}${c5}󰊠  ${c5}${c7}󰊠  ${c7}")
echo("               ${reset}")
