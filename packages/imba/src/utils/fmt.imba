import { fdir } from 'fdir'
import fs from 'fs'
import cp from 'child_process'
import 'imba/colors'

const E = do
	console.error String($1).red
	process.exit!

const debug-log = /^\t*\bL\b.*$/
const trailing-whitespace = /[ \t]+$/gm
const extra-lines = /\n\n\n+/gm
const commented-logs = /^\s*#\s+(console\.|L)\b.*\n/gm
const empty-comments = /^\s*#\s*\n/gm

def remove-debug-logs contents

	let result = []
	let lines = contents.split('\n')

	for line, i in lines

		unless debug-log.test line
			result.push line
			continue

		let prev-line = lines[i - 1]
		let next-line = lines[i + 1]

		let j = i - 1
		while typeof prev-line is 'string' and (/^\s*$/.test(prev-line) or /^\s*#/.test(prev-line))
			prev-line = lines[--j]

		j = i + 1
		while typeof next-line is 'string' and (/^\s*$/.test(next-line) or /^\s*#/.test(next-line))
			next-line = lines[++j]

		let pt = prev-line..match(/^\t*/)[0]
		let ct = line.match(/^\t*/)[0]
		let nt = next-line..match(/^\t*/)[0]

		continue if !debug-log.test(prev-line) and (pt is ct or ct is nt)
		result.push line.replace /(?<=^\t*)\bL\b.*/, null

	result.join("\n")

export default def fmt opts

	unless opts.force
		try
			if cp.execSync("git status --porcelain", { stdio: "pipe" }).toString!
				E "Git working directory is not clean"
		catch e
			E "Failed to check git status"

	let files = new fdir!
		.glob("**/*.imba")
		.withFullPaths!
		.crawl(".")
		.sync!

	for file\string of files
		continue if file.endsWith 'fmt.imba'
		continue if file.includes 'node_modules'

		let contents = fs.readFileSync file, 'utf8'
		let prev = contents
		contents = remove-debug-logs contents
		contents = contents.replaceAll commented-logs, ''
		contents = contents.replaceAll trailing-whitespace, ''
		contents = contents.replaceAll extra-lines, '\n\n'
		contents = contents.replaceAll empty-comments, ''
		continue if prev is contents

		fs.writeFileSync file, contents
