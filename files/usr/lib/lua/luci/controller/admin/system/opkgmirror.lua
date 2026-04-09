module("luci.controller.admin.system.opkgmirror", package.seeall)

function index()
	local fs = require "nixio.fs"
	if not fs.access("/etc/config/luci") then
		return
	end

	local page = entry({ "admin", "system", "opkgmirror" }, cbi("opkgmirror"), _("软件源镜像切换"), 60)
	page.dependent = true
end

