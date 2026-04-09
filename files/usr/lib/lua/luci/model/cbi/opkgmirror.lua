local fs = require "nixio.fs"
local sys = require "luci.sys"
local util = require "luci.util"

local DISTFEEDS = "/etc/opkg/distfeeds.conf"
local LASTLOG = "/tmp/luci-opkgmirror.log"

local PRESETS = {
	{ id = "official", name = "官方（downloads.immortalwrt.org）", url = "https://downloads.immortalwrt.org" },
	{ id = "vsean", name = "mirrors.vsean.net/openwrt", url = "https://mirrors.vsean.net/openwrt" },
	{ id = "custom", name = "自定义", url = "" },
}

local function normalize_base_url(u)
	u = (u or ""):gsub("^%s+", ""):gsub("%s+$", "")
	u = u:gsub("/+$", "")
	if u == "" then
		return nil, "未填写镜像基址"
	end
	if not u:match("^https?://") then
		return nil, "镜像基址必须以 http:// 或 https:// 开头"
	end
	if u:match("%s") then
		return nil, "镜像基址不能包含空格"
	end
	return u
end

local function detect_current_base_url(content)
	if not content or content == "" then
		return nil
	end
	for line in content:gmatch("[^\r\n]+") do
		local base = line:match("^%s*src/gz%s+%S+%s+(https?://[^/]+)")
		if base then
			return base
		end
	end
	return nil
end

local function rewrite_distfeeds(content, new_base)
	local changed = 0
	local out = {}

	for line in ((content or "") .. "\n"):gmatch("(.-)\n") do
		local prefix, old_base, rest = line:match("^(%s*src/gz%s+%S+%s+)(https?://[^/]+)(/.*)$")
		if prefix and old_base and rest then
			if old_base ~= new_base then
				line = prefix .. new_base .. rest
				changed = changed + 1
			end
		end
		out[#out + 1] = line
	end

	return table.concat(out, "\n"), changed
end

local function write_log(s)
	fs.writefile(LASTLOG, s or "")
end

local function apply_mirror(new_base, do_update)
	if not fs.access(DISTFEEDS) then
		return nil, ("找不到文件：%s"):format(DISTFEEDS)
	end

	local content = fs.readfile(DISTFEEDS) or ""
	local rewritten, changed = rewrite_distfeeds(content, new_base)

	if changed == 0 then
		write_log(("未检测到可替换项：%s\n"):format(DISTFEEDS))
		return true, "未检测到需要替换的源（可能已经是该镜像，或 distfeeds 格式不同）"
	end

	local ts = os.date("%Y%m%d-%H%M%S")
	local bak = ("%s.bak.%s"):format(DISTFEEDS, ts)
	local tmp = ("%s.new.%s"):format(DISTFEEDS, ts)

	local ok, err
	ok = fs.writefile(tmp, rewritten .. "\n")
	if not ok then
		return nil, ("写入临时文件失败：%s"):format(tmp)
	end

	-- backup (best-effort)
	pcall(function()
		fs.writefile(bak, content)
	end)

	ok = fs.rename(tmp, DISTFEEDS)
	if not ok then
		return nil, ("替换失败：无法覆盖 %s"):format(DISTFEEDS)
	end

	local log = {}
	log[#log + 1] = ("已替换 %d 条源：%s"):format(changed, DISTFEEDS)
	log[#log + 1] = ("镜像基址：%s"):format(new_base)
	log[#log + 1] = ("备份：%s"):format(bak)

	if do_update then
		log[#log + 1] = ""
		log[#log + 1] = "==== opkg update 输出 ===="
		local out = sys.exec("opkg update 2>&1") or ""
		log[#log + 1] = out
	end

	write_log(table.concat(log, "\n"))
	return true
end

local distfeeds_content = fs.readfile(DISTFEEDS) or ""
local current_base = detect_current_base_url(distfeeds_content) or "-"
local lastlog = fs.readfile(LASTLOG) or ""

m = SimpleForm("opkgmirror", "软件源镜像切换",
	"用于一键切换 opkg 软件源镜像（修改 /etc/opkg/distfeeds.conf）。\n" ..
	"提示：此功能只会替换 distfeeds.conf 中 src/gz 行的域名部分，保留后续路径不变。")

m.reset = false
m.submit = false

local s = m:section(SimpleSection)

local cur = s:option(DummyValue, "_current", "当前源站基址")
cur.value = current_base

local preset = s:option(ListValue, "preset", "镜像选择")
for _, p in ipairs(PRESETS) do
	preset:value(p.id, p.name)
end
preset.default = "official"

local custom = s:option(Value, "custom_url", "自定义镜像基址（可选）")
custom.placeholder = "https://example.com"
custom:depends("preset", "custom")
function custom.validate(self, value)
	local u, err = normalize_base_url(value)
	if not u then
		return nil, err
	end
	return u
end

local function chosen_url(section)
	local pid = util.trim(preset:formvalue(section) or preset.default or "official")
	if pid == "custom" then
		local u, err = normalize_base_url(custom:formvalue(section))
		if not u then
			return nil, err
		end
		return u
	end
	for _, p in ipairs(PRESETS) do
		if p.id == pid then
			return p.url
		end
	end
	return nil, "未知镜像选项"
end

local btn_apply = s:option(Button, "_apply", "应用（仅替换）")
btn_apply.inputstyle = "apply"
function btn_apply.write(self, section)
	local url, err = chosen_url(section)
	if not url then
		m.errmessage = err
		return
	end
	local ok, e = apply_mirror(url, false)
	if not ok then
		m.errmessage = e or "应用失败"
	else
		m.message = "已应用镜像设置"
	end
end

local btn_update = s:option(Button, "_apply_update", "应用并执行 opkg update")
btn_update.inputstyle = "apply"
function btn_update.write(self, section)
	local url, err = chosen_url(section)
	if not url then
		m.errmessage = err
		return
	end
	local ok, e = apply_mirror(url, true)
	if not ok then
		m.errmessage = e or "应用失败"
	else
		m.message = "已应用镜像设置并执行 opkg update"
	end
end

local logv = m:section(SimpleSection, nil, "最近一次操作日志（/tmp）")
local tv = logv:option(TextValue, "_lastlog")
tv.rows = 18
tv.wrap = "off"
tv.readonly = true
function tv.cfgvalue(self, section)
	return lastlog ~= "" and lastlog or "（暂无）"
end

return m

