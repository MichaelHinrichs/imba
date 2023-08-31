class One

let num = 123
let str = 'a'
let bool = yes
let arr = [1,2,3]
let obj = {}
let sym = Symbol!
let one = new One

let OddNumber = {
	def [Symbol.hasInstance] val
		val isa 'number' and (val % 2 == 1)
}

test do
	ok bool isa 'boolean'
	ok str isa 'string'
	ok obj isa 'object'
	ok sym isa 'symbol'
	ok arr isa 'object'
	ok arr isa Array
	ok one isa ('string' or One)
	ok num isa OddNumber
	ok 120 !isa OddNumber

	let dynamic = 'string'
	ok str isa dynamic

	ok "a" !isa Array
	ok "a" isa (String or 'string')
	ok "a" isa ('string' or 'number')
	ok true isa ('boolean')
	ok 0 !isa ('boolean')
	ok 0 isa ('number')
