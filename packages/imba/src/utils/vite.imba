import np from 'node:path'
import nfs from 'node:fs'
import url from 'node:url'
import c from 'picocolors'
const _dirname = if typeof __dirname !== 'undefined' then __dirname else np.dirname(url.fileURLToPath(import.meta.url))

const EXIT_CODE_RESTART = 43
export const viteServerConfigFile = np.join(_dirname, "..", "bin", "./vite.config.server.mjs")
export const viteClientConfigFile = np.join(_dirname, "..", "bin", "./vite.config.mjs")
export const vitestSetupPath = np.join(_dirname, "..", "bin", "./test-setup.js")

export def resolveWithFallbacks(ours, fallbacks, opts = {})
	const {ext, resolve} = opts
	let pkg = ours
	pkg += ".{ext}" if ext..length
	fallbacks = [fallbacks] unless Array.isArray fallbacks
	for fallback in fallbacks
		fallback = "{ours}.{fallback}" if ext
		# const userPkg = np.resolve(fallback)
		if nfs.existsSync fallback
			pkg = fallback
	if resolve
		if ((ext and pkg == "{ours}.{ext}") or pkg == ours)
			pkg = np.resolve np.join _dirname, pkg
		else
			pkg = np.resolve np.join process.cwd(), pkg
		pkg = "{url.pathToFileURL pkg}"
	pkg

export def ensurePackagesInstalled(dependencies, root)
	const to-install = []
	const {isPackageExists} = require('local-pkg')
	for dependency in dependencies
		to-install.push dependency if !isPackageExists(dependency, {paths: [root]})
	return true if to-install.length == 0
	const promptInstall = !process.env.CI and process.stdout.isTTY
	const deps = to-install.join(', ')
	process.stderr.write c.red("{c.inverse(c.red(' MISSING DEP '))} Can not find dependencies '{deps}'\n\n")
	if !promptInstall
		return false
	const prompts = await import("prompts")
	const {install} = await prompts.prompt(
		type: "confirm"
		name: "install"
		message: c.reset("Do you want to install {c.green(deps)}?"))
	if install
		for dependency in to-install
			await (await import("@antfu/install-pkg")).installPackage(dependency, dev: true)
		process.stderr.write c.yellow("\nPackages {deps} installed, re-run the command to start.\n")
		process.exit EXIT_CODE_RESTART
		return true
	return false
