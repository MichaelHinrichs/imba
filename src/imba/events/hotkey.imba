import {Event,CustomEvent,Element} from '../dom/core'

export def use_events_hotkey
	yes

const KeyLabels = {
	esc: '⎋'
	enter: '⏎'
	shift: '⇧'
	command: '⌘'
	option: '⌥'
	alt: '⎇'
	del: '⌦'
	backspace: '⌫'

}

const Globals = {
	"command+1": yes
	"command+2": yes
	"command+3": yes
	"command+4": yes
	"command+5": yes
	"command+6": yes
	"command+7": yes
	"command+8": yes
	"command+9": yes
	"command+0": yes
	"command+n": yes
	"command+f": yes
	"command+k": yes
	"command+j": yes
	"command+s": yes
	"esc": yes
	"shift+command+f": yes
}

import Mousetrap from './mousetrap'

const stopCallback = do |e,el,combo|	
	if (' ' + el.className + ' ').indexOf(' mousetrap ') > -1
		return false
		
	if el.mousetrappable
		return false

	if el.tagName == 'INPUT' && (combo == 'down' or combo == 'up')
		return false
	
	if el.tagName == 'INPUT' || el.tagName == 'SELECT' || el.tagName == 'TEXTAREA'
		if Globals[combo]
			e.#globalHotkey = yes
			e.#inFormInput = yes
			return false
		return true
		
	if el.contentEditable && (el.contentEditable == 'true' || el.contentEditable == 'plaintext-only' || el.closest('.editable'))
		if Globals[combo]
			e.#globalHotkey = yes
			e.#inContentEditable = yes
			return false
		return true
		
	return false

export const hotkeys = new class HotKeyManager
	def constructor
		combos = {'*': {}}
		identifiers = {}
		labels = {}
		handler = handle.bind(self)
		mousetrap = null
		hothandler = handle.bind(self)

	def register key,mods = {}
		unless mousetrap
			mousetrap = Mousetrap(document)
			mousetrap.stopCallback = stopCallback

		unless combos[key]
			combos[key] = yes
			mousetrap.bind(key,handler)

		if mods.global
			Globals[key] = yes
		self
		
	def comboIdentifier combo
		identifiers[combo] ||= combo.replace(/\+/g,'_').replace(/\ /g,'-').replace(/\*/g,'all')

	def shortcutHTML combo
		("<u>" + comboLabel(combo).split(" ").join("</u><u>") + "</u>").replace('<u>/</u>','<span>or</span>')
		
	def comboLabel combo
		labels[combo] ||= combo.split(" ").map(do $1.split("+").map(do KeyLabels[$1] or $2.toUpperCase!).join("") ).join(" ")
		
	def matchCombo str
		yes

	def handle e\Event, combo
		# e is the original event
		let source = e.target.#hotkeyTarget or e.target
		let targets\HTMLElement[] = Array.from(document.querySelectorAll('[data-hotkey]'))
		let root = source.ownerDocument
		let group = source
		
		# find the closest hotkey 
		while group and group != root
			if group.hotkeys === true
				break
			group = group.parentNode
			
		if group == root
			group = source
		
		targets = targets.reverse!.filter do |el|
			return no unless el.#hotkeyCombos and el.#hotkeyCombos[combo]
			return no if el.closest('.hiding,.no-hotkeys')

			let par = el
			while par and par != root
				if par.hotkeys === false
					return no
				par = par.parentNode
			return yes
			
		return unless targets.length
	
		let detail = {combo: combo, originalEvent: e, targets: targets}
		let event = new CustomEvent('hotkey', bubbles: true, detail: detail)
		event.originalEvent = e

		event.handle$mod = do(options)
			let el = this.element
			if !this.handler.#combos[combo]
				return false

			if e.#globalHotkey and !this.modifiers.global
				return false

			if !group.contains(el) and !el.contains(group) and !this.modifiers.global
				return false

			return true
		
		let res = source.dispatchEvent(event)

		# global.ce = event
		for receiver in targets
			for handler in receiver.#hotkeyHandlers
				unless event.#stopPropagation
					handler.handleEvent(event)

			if event.#defaultPrevented or event.#stopPropagation
				e.preventDefault!

			if false and receiver.matches('input:not([type=button]),select,textarea')
				e.preventDefault!
				receiver.focus! if receiver.focus
			else
				yes
				# if params.within and !receiver.parentNode.contains(document.activeElement)
				# 	continue
				# if (/command|cmd|ctrl|shift/).test(combo) or params.prevent
				# 	e.preventDefault!
				# console.log 'emit click!'
				# receiver.click!

			if event.#stopPropagation
				break
		self

extend class Element
		
	def on$hotkey mods, scope, handler, o
		#hotkeyHandlers ||= []
		#hotkeyHandlers.push(handler)
		# addEventListener('hotkey',handler,o)
		console.log "HOTKEY",mods.options,mods
		handler.#target = self
		#updateHotKeys!
		return handler
		
	def #updateHotKeys
		let all = {}
		let isMac = global.navigator.platform == 'MacIntel'
		for handler in #hotkeyHandlers
			let mods = handler.params
			let key = mods.options[0]
			let prev = handler.#key
			if handler.#key =? key
				handler.#combos = {}
				let combos = key.replace(/\bmod\b/g,isMac ? 'command' : 'ctrl')
				for combo in combos.split('|')
					hotkeys.register(combo,mods)
					handler.#combos[combo] = yes
			Object.assign(all,handler.#combos)

		let keys = Object.keys(all)
		#hotkeyCombos = all
		dataset.hotkey = keys.join(' ')
		self

def Event.hotkey$click
	this.element.click!
	return yes
	
def Event.hotkey$focus expr
	let el = this.element
	let doc = el.ownerDocument
	
	if expr
		el = el.querySelector(expr) or el.closest(expr) or doc.querySelector(expr)

	if el == doc.body
		doc.activeElement.blur! unless doc.activeElement == doc.body
	else
		el.focus!
		
	return yes