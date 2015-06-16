package tone;

class ADS {
	
	public var tone : Tone;
	public var module_id : Int;
	
	public static inline var POSITION = 0;
	public static inline var ATTACK = 1;
	public static inline var DECAY = 2;
	public static inline var SUSTAIN = 3;
	
	public static inline var INB = 0;
	public static inline var OUTB = 1;
	public static inline var STATEB = 2;
	public static inline var TYPEB = 3;
	
	// for now, we are doing a simple "attack, then decay to sustain value."
	// release should be added if we want to signal release when we're past
	// the attack phase...
	
	// this will need some curvature additions so that ramp-to-attack, ramp-to-sustain
	// is non-linear.
	
	// as well, I should have an function to set the parameters in -dB.
	// that can probably be done using a conversion function from elsewhere.
	
	public function new(t : Tone) {
		this.tone = t;
		this.module_id = tone.assignModuleId(this);
	}
	
	public function spawn(input : Int, output : Int) {
		var modules = tone.modules;
		var pcm = tone.pcm;
		var module0 = modules.spawn();
		var module = modules.a[module0];
		module.buf_ref = [
			input, /* inb */
			output, /* outb */
			tone.spawnFloats(4), /* stateb */
			tone.spawnInts(1)]; /* typeb */
		module.module_id = module_id;
		module.module_type = 0;
		return module0;
	}
	
	public function free(module0 : Int) {
		tone.modules.despawn(module0);
	}
	
	public function setParam(mi : Int, param : Int, v : Float) {
		var modules = tone.modules;
		var buffers = tone.buffers;
		var floatallocator = tone.floatallocator;
		var m0 = modules.a[mi]; if (!modules.z[mi]) throw 'module $mi used when not alive';
		var stateb = tone.getFloatsBuffer(buffers.a[m0.buf_ref[STATEB]]);
		floatallocator.rawbuf[stateb.first + param] = v;
	}
	
	public function out(mi : Int) {
		var modules = tone.modules;
		var buffers = tone.buffers;
		var m0 = modules.a[mi]; if (!modules.z[mi]) throw 'module $mi used when not alive';
		return tone.getFloatsBuffer(buffers.a[m0.buf_ref[OUTB]]);
	}
	
	public function inp(mi : Int) {
		var modules = tone.modules;
		var buffers = tone.buffers;
		var m0 = modules.a[mi]; if (!modules.z[mi]) throw 'module $mi used when not alive';
		return tone.getFloatsBuffer(buffers.a[m0.buf_ref[INB]]);
	}
	
	public function write(mi : Int) {
		var modules = tone.modules;
		var buffers = tone.buffers;
		var floatallocator = tone.floatallocator;
		var m0 = modules.a[mi]; if (!modules.z[mi]) throw 'module $mi used when not alive';
		var outb = tone.getFloatsBuffer(buffers.a[m0.buf_ref[OUTB]]);
		var inb = tone.getFloatsBuffer(buffers.a[m0.buf_ref[INB]]);
		var stateb = tone.getFloatsBuffer(buffers.a[m0.buf_ref[STATEB]]);
		var typeb = tone.getIntsBuffer(buffers.a[m0.buf_ref[TYPEB]]);
		var fb = floatallocator.rawbuf;
		var ib = tone.intallocator.rawbuf;
		var attack = fb[stateb.first + ATTACK];
		var decay = fb[stateb.first + DECAY];
		var suslevel = fb[stateb.first + SUSTAIN];
		var declevel = 1 - fb[stateb.first + SUSTAIN];
		var i1 = inb.first;
		var z0 = fb[stateb.first + POSITION];
		for (i0 in outb.first...outb.last)
		{
			var v = z0 - attack;
			if (v < 0.) {
				var linear = Math.min(1., Math.max(0., 1. + (v / attack)));
				fb[i0] = fb[i1] * linear - 0.00000000001;
			}
			else {
				var linear = Math.min(1., Math.max(0., 1. - (v / decay)));
				fb[i0] = fb[i1] * linear * declevel + fb[i1] * suslevel - 0.00000000001;
			}
			z0 += 1;
			i1 += 1;
		}
		fb[stateb.first + POSITION] = z0;
	}
	
}