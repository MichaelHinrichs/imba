import cluster from 'cluster'
import np from 'path'
import cp from 'child_process'
import nfs from 'node:fs'
import { pathToFileURL } from 'node:url';
import Component from './component'
import {Logger} from '../utils/logger'
import {builtinModules} from 'module'
import {createHash, slash} from './utils'
import mm from 'micromatch'
import {__served__} from '../imba/utils'
import { viteServerConfigFile, resolveWithFallbacks, importWithFallback } from '../utils/vite'

class WorkerInstance
	runner = null
	fork = null
	args = {}
	mode = 'cluster'
	name = 'worker'
	restarts = 0

	get manifest
		runner.manifest or {}

	get bundle
		runner.bundle

	def constructor runner, options
		super(options)
		options = options
		runner = runner
		atime = Date.now!
		state = 'closed'
		log = new Logger(prefix: ["%bold%dim",name,": "])
		current = null
		restarts = 0

	def get-all-styles
		const urls = []
		const ids = []
		const moduleMap = {}
		for [id, mod] of runner.viteServer.moduleGraph.idToModuleMap
			const url = mod.url
			urls.push url
			ids.push id
			# debugger if url.endsWith(".css")
			moduleMap[url] = 
				file: mod.file
				id: mod.id
				url: url
				type: mod.type
				importedModules: Array.from(mod.importedModules.keys()).map(do $1.id)
				importers: Array.from(mod.importers.keys()).map(do $1.id)
				code: (url.endsWith('.css') ? mod.ssrTransformResult.code : "")
		const DEV_CSS_PATH = "./.dev-ssr"
		nfs.mkdirSync(DEV_CSS_PATH) unless nfs.existsSync(DEV_CSS_PATH)
		let all-css = ""
		for own id, mod of moduleMap when mod.code
			all-css += mod.code.substring(mod.code.indexOf('"') + 1, mod.code.lastIndexOf('"')).replace(/\\n/g, '\n') + "\n"
		nfs.writeFileSync("{DEV_CSS_PATH}/all.css",all-css)

	def start
		return if current and current.#next
		let o = runner.o
		let path = bundle.result.main

		let args = {
			windowsHide: yes
			args: o.extras
			exec: path
			execArgv: [
				o.inspect and '--inspect',
				(o.sourcemap or bundle.sourcemapped?) and '--enable-source-maps'
			].filter do $1
		}

		let env = {
			IMBA_RESTARTS: restarts
			IMBA_SERVE: true
			IMBA_PATH: o.imbaPath
			IMBA_OUTDIR: o.outdir
			IMBA_WORKER_NR: options.number
			IMBA_CLUSTER: !bundle.fork?
			IMBA_LOGLEVEL: process.env.IMBA_LOGLEVEL or 'warning'
			PORT: process.env.PORT or o.port
			VITE: o.vite
		}

		for own k,v of env
			env[k] = '' if v === false

		if bundle.fork? and !o.vite
			args.env = Object.assign({},process.env,env)
			fork = cp.fork(np.resolve(path),args.args,args)
			# setup-vite fork
			fork.on('exit') do(code) process.exit(code)
			return fork

		
		cluster.setupMaster(args)

		let worker = cluster.fork(env)

		worker.nr = restarts++
		let prev = worker.#prev = current

		if prev
			# log.info "reloading"
			prev.#next = worker
			prev..send(['emit','reloading'])
		worker.on 'exit' do(code, signal)
			if signal
				log.info "killed by signal: %d",signal
			elif code != 0
				log.error "exited with error code: %red",code
			elif !worker.#next
				log.info "exited"
		
		worker.on 'listening' do(address)
			o.#listening = address
			log.success "listening on %address",address unless o.vite
			prev..send(['emit','reloaded'])
			# now we can kill the reloaded process?

		worker.on 'error' do
			log.info "%red","errorerd"

		# worker.on 'online' do log.info "%green","online"
		# worker.on 'message' do(message, handle)

		worker.on 'message' do(message, handle)
			# console.log "msg", message, handle
			if message.type == 'fetch'
				# console.log "parent: fetching", message
				let md = await runner.fetchModule(message.id)
				if message.id == '\0virtual:imba/*?css'
					try await get-all-styles! catch error
						console.log "error creating DEV SSR styles", error
				console.log "md {JSON.stringify message.id}", message.id == 'virtual:imba/*?css'
				worker..send JSON.stringify
					type: 'fetched'
					id: message.id
					md: md
			elif message.type == 'resolve'
				# console.log "resolving", message
				const id = message.payload.id
				const importer = message.payload.importer
				const output = await runner.resolveId(id, importer)
				const response = JSON.stringify
					type: 'resolved'
					output: output
					input: {id, importer}
				worker.send response
			if message == 'exit'
				console.log "exit"
				process.exit!
			if message == 'reload'
				console.log "RELOAD MESSAGE"
				reload!

		current = worker
	
	def broadcast event
		current..send(event)

	def reload
		start!
		self


export default class Runner < Component
	viteNodeServer
	viteServer
	fileToRun
	def constructor bundle, options
		super()
		o = options
		bundle = bundle
		workers = new Set
		fileToRun = np.resolve bundle.cwd, o.name
	def fetchModule(id)
		viteNodeServer.fetchModule id
	def resolveId(id)
		viteNodeServer.resolveId id
	def shouldRerun(id)
		return yes if id == fileToRun
		# __served__ contains modules that were served by Vite in the client
		# These would trigger HMR, so there is no need to live reload the server
		return false if __served__.has id
		const mod = viteServer.moduleGraph.getModuleById(id)
		return false unless mod
		let rerun = false
		mod.importers.forEach do(i)
			if !i.id
				return
			const heedsRerun = shouldRerun(i.id)
			if heedsRerun
				rerun = true
		rerun
	# TODO: static variables
	_rerunTimer
	restartsCount = 0
	watcher-debounce = 100
	def schedule-reload()
		const currentCount = restartsCount
		clearTimeout _rerunTimer
		return if restartsCount !== currentCount
		_rerunTimer = setTimeout(&, watcher-debounce) do
			return if restartsCount !== currentCount
			reload!
	def initVite
		const builtins = new RegExp(builtinModules.join("|"), 'gi');
		let Vite = await import("vite")
		let ViteNode = await import("vite-node/server")
		const configFile = resolveWithFallbacks(viteServerConfigFile, ["vite.config.server.ts", "vite.config.server.js"])
		viteServer = await Vite.createServer
			configFile: configFile
		viteNodeServer = new ViteNode.ViteNodeServer viteServer,
			transformMode:
				ssr: [/.*/g]
		viteServer.watcher.on "change", do(id)
			id = slash(id)
			const needsRerun = shouldRerun(id)
			const file-path = np.relative(viteServer.config.root, id)
			const skip? = o.skipReloadingFor and mm.isMatch(file-path, o.skipReloadingFor)
			if needsRerun and !skip?
				schedule-reload()
		fileToRun = np.resolve bundle.cwd, o.name
		let body = nfs.readFileSync(np.resolve(__dirname, "./worker_template.js"), 'utf-8')
			.replace("__ROOT__", viteServer.config.root)
			.replace("__BASE__", viteServer.config.base)
			.replace("__FILE__", fileToRun)
		# start uncommend to upgrade vite-node-client
		# const output = await Vite.build
		# 	optimizeDeps: {disabled: yes}
		# 	ssr:
		# 		target: "node"
		# 	build:
		# 		minify: no
		# 		rollupOptions:
		# 			external: builtinModules
		# 		target: "node16"
		# 		lib:
		# 			formats: ["es"]
		# 			entry: require.resolve("vite-node/client").replace(".cjs", ".mjs")
		# 			name: "vite-node-client"
		# 			fileName: "vite-node-client"
		# const license = nfs.readFileSync(np.join(require.resolve("vite-node/client"), "..", "..", "LICENSE"), "utf-8")
		# const content = "/* {license} */\n{output[0].output[0].code}"
		# nfs.writeFileSync(np.resolve(__dirname, np.join("..", 'vendor', 'vite-node-client.mjs')), content)
		# end   uncommend to upgrade vite-node-client

		const hash = createHash(body)
		const fpath = np.join o.tmpdir, "bundle.{hash}.mjs"
		# in windows, the path would start with c: ...
		# and esm doesn't support it. 
		const vnpath = pathToFileURL(np.join o.tmpdir, "vite-node-client.mjs")
		const vn-vendored = np.resolve __dirname, np.join("..", "vendor","vite-node-client.mjs")
		nfs.writeFileSync(vnpath, nfs.readFileSync(vn-vendored, 'utf-8')) unless nfs.existsSync(vnpath)
		body = body.replace("__VITE_NODE_CLIENT__", vnpath.href)
		nfs.writeFileSync(fpath, body)
		# this is need to initialize the plugins
		await viteServer.pluginContainer.buildStart({})
		bundle =
			fork?: no
			result:
				main: fpath
				hash: hash
	def start
		let max = o.instances or 1
		let nr = 1

		let name = o.name or 'script' # or np.basename(bundle.result.main.source.path)

		while nr <= max
			let opts = {
				number: nr,
				name: max > 1 ? "{name} {nr}/{max}" : name
			}
			workers.add new WorkerInstance(self,opts)
			nr++

		for worker of workers
			worker.start!
		if o.watch
			#hash = bundle.result.hash

			# running with vite, we use a thinner bundle
			bundle..on('built') do(result)
				# console.log "got manifest?"
				# let hash = result.manifest.hash
				if #hash =? result.hash
					reload!
				else
					broadcast(['emit','rebuild',result.manifest])
		return self

	def reload
		log.info "reloading %path",o.name
		for worker of workers
			worker.reload!
		self

	def broadcast ...params
		for worker of workers
			worker.broadcast(...params)
		self