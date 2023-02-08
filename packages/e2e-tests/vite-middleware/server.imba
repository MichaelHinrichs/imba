import path from "path"
import express from "express"
import compression from "compression"
import serveStatic from "serve-static"
import App from './src/App.imba'
import Home from './src/Home.imba'
import np from 'node:path'
import url from 'node:url'
# tag vite-script
# 	prop src
# 	prop type = "module"
# 	get _src
# 		src.replace("./", "")
# 	def render
# 		<self>
# 			if __vite_manifest__
# 				const prod-src = manifest[_src].file
# 				const css-files = manifest[_src].css
# 				<script type="module" src=prod-src>
# 				for css-file in css-files
# 					<style src=css-file>
# 			else
# 				<script src=_src type=type>

let port = 3000
const args = process.argv.slice(2)
const portArgPos = args.indexOf("--port") + 1
if portArgPos > 0
	port = parseInt(args[portArgPos], 10)

let manifest
def createServer(root = process.cwd())
	# if import.meta.env.MODE === "production"
	# 	manifest = (await import("./client/manifest.json")).default
	const resolve = do(p) path.resolve(root, p)
	const app = express()
	await imba.setupVite app, import.meta.env.MODE, do(dist)
		app.use compression()
		app.use serveStatic(dist, index: false)
	app.use "/home", do(req, res)
		let html = <html lang="en">
			<head>
				<meta charset="UTF-8">
				<meta name="viewport" content="width=device-width, initial-scale=1.0">
				<title> "Imba App"
				<script type="module" src="./src/Home.imba">
			<body>
				<Home>
		res.status(200).set("Content-Type": "text/html").end String html
	app.use "/", do(req, res)
		let html = <html lang="en">
			<head>
				<meta charset="UTF-8">
				<meta name="viewport" content="width=device-width, initial-scale=1.0">
				<title> "Imba App"
				<script type="module" src="./src/App.imba">
			<body>
				<App>
		res.status(200).set("Content-Type": "text/html").end String html
	app

const app = await createServer!
console.log "server created now"
const server = app.listen port, do console.log "http://localhost:{port}"
const exitProcess = do
	console.log "exiting process"
	process.off "SIGTERM", exitProcess
	process.off "SIGINT", exitProcess
	process.stdin.off "end", exitProcess
	try await server.close do console.log "server closed" finally process.exit 0

process.once "SIGTERM", exitProcess
process.once "SIGINT", exitProcess
process.stdin.on "end", exitProcess

