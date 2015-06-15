package tone;

class PolyBLEPModule {
	
	public var tone : Tone;
	public var module_id : Int;
	
	public function new(t : Tone) {
		this.tone = t;
		this.module_id = tone.assignModuleId(this);
	}
	
	public function spawn(output : Int) {
		var modules = tone.modules;
		var pcm = tone.pcm;
		var module0 = modules.spawn();
		var module = modules.a[module0];
		module.buf_ref = [
			output, /* outb */
			tone.spawnFloats(3), /* stateb */
			tone.spawnInts(1)]; /* typeb */
		module.module_id = module_id;
		module.module_type = 0;
		module.pcm_info = [pcm.spawn()];
		pcm.a[module.pcm_info[0]].samplerate = 44100;
		pcm.a[module.pcm_info[0]].channels = 1;
		return module0;
	}
	
	public function free(module0 : Int) {
		tone.modules.despawn(module0);
	}
	
	public inline function polyBlep(t : Float, dt : Float) : Float
	{
		// 0 <= t < 1
		if (t < dt) {
			t /= dt;
			return t+t - t*t - 1.0;
		}
		// -1 < t < 0
		else if (t > 1. - dt) {
			t = (t - 1.) / dt;
			return t*t + t+t + 1.0;
		}
		// 0 otherwise
		else return 0.0;
	}
	
	public function setWavelength(mi : Int, wl : Float) {
		var modules = tone.modules;
		var buffers = tone.buffers;
		var floatallocator = tone.floatallocator;
		var m0 = modules.a[mi]; if (!modules.z[mi]) throw 'module $mi used when not alive';
		var stateb = tone.getFloatsBuffer(buffers.a[m0.buf_ref[1]]);
		floatallocator.rawbuf[stateb.first + 1] = wl;
	}
	
	public function out(mi : Int) {
		var modules = tone.modules;
		var buffers = tone.buffers;
		var m0 = modules.a[mi]; if (!modules.z[mi]) throw 'module $mi used when not alive';
		return tone.getFloatsBuffer(buffers.a[m0.buf_ref[0]]);
	}
	
	public function write(mi : Int) {
		var modules = tone.modules;
		var buffers = tone.buffers;
		var floatallocator = tone.floatallocator;
		var m0 = modules.a[mi]; if (!modules.z[mi]) throw 'module $mi used when not alive';
		var outb = tone.getFloatsBuffer(buffers.a[m0.buf_ref[0]]);
		var stateb = tone.getFloatsBuffer(buffers.a[m0.buf_ref[1]]);
		var typeb = tone.getIntsBuffer(buffers.a[m0.buf_ref[2]]);
		var fb = floatallocator.rawbuf;
		var ib = tone.intallocator.rawbuf;
		var z0 = fb[stateb.first];
		var deltaz = fb[stateb.first + 1];
		var lastout = fb[stateb.first + 2];
		
		switch(ib[typeb.first]) {
			case 0: /* sine */
				var dzp = deltaz * Math.PI;
				for (i0 in outb.first...outb.last)
				{
					fb[i0] = Math.sin(z0);
					z0 += dzp;
				}
			case 1: /* saw */
				var bw = 1 / deltaz;
				for (i0 in outb.first...outb.last)
				{
					var z1 = (z0 + 0.5) % 1.;
					fb[i0] = (z1 * 2) - 1 - polyBlep(z1, deltaz);
					z0 += deltaz;
				}
			case 2: /* tri */
				for (i0 in outb.first...outb.last)
				{
					// start with square
					var o = (z0 < 0.5 ? 1.0 : -1.0) + 
						polyBlep(z0, deltaz) - 
						polyBlep((z0 + 0.5) % 1.0, deltaz);
					// Leaky integrator: y[n] = A * x[n] + (1 - A) * y[n-1]
					lastout = deltaz * o + (1 - deltaz) * lastout;
					fb[i0] = lastout * 4;
					z0 = (z0 + deltaz) % 1;
				}
			case 3: /* sqr */
				for (i0 in outb.first...outb.last)
				{
					fb[i0] = (z0 < 0.5 ? 1.0 : -1.0) + 
						polyBlep(z0, deltaz) - 
						polyBlep((z0 + 0.5) % 1.0, deltaz);
					z0 = (z0 + deltaz) % 1;
				}
		}
		fb[stateb.first] = z0;
		fb[stateb.first + 2] = lastout;
	}
	
	public function setType(mi : Int, type : Int) {
		var modules = tone.modules;
		var buffers = tone.buffers;
		var m0 = modules.a[mi]; if (!modules.z[mi]) throw 'module $mi used when not alive';
		var typeb = tone.getIntsBuffer(buffers.a[m0.buf_ref[2]]);
		var ib = tone.intallocator.rawbuf;
		ib[typeb.first] = type;
	}
	
}