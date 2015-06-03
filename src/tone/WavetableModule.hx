package tone;
import haxe.ds.Vector;

class WavetableModule {

	/* a 256-sample wavetable with linear resampling. */
	
	public var tone : Tone;
	public var module_id : Int;
	
	public static var resamplertab : Vector<Float>;
	
	public function new(t : Tone) {
		this.tone = t;
		this.module_id = tone.assignModuleId(this);
		if (resamplertab == null) {
			resamplertab = new Vector<Float>(2048);
			for (i0 in 0...2048) {
				resamplertab[i0] = blackmanharris(i0/2047);
			}
		}
	}
	
	public function spawn(output : Int) {
		var modules = tone.modules;
		var pcm = tone.pcm;
		var module0 = modules.spawn();
		var module = modules.a[module0];
		module.buf_ref = [
			output, /* outb */
			tone.spawnFloats(2), /* stateb */
			tone.spawnFloats(256)]; /* wavetableb */
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
	
	public function setWavelength(mi : Int, wl : Float) {
		var modules = tone.modules;
		var buffers = tone.buffers;
		var floatallocator = tone.floatallocator;
		var m0 = modules.a[mi]; if (!modules.z[mi]) throw 'module $mi used when not alive';
		var stateb = tone.getFloatsBuffer(buffers.a[m0.buf_ref[1]]);
		floatallocator.rawbuf[stateb.first + 1] = wl * 256;
	}
	
	public inline function setTable(mi : Int, idx : Int, v : Float) {
		var modules = tone.modules;
		var buffers = tone.buffers;
		var floatallocator = tone.floatallocator;
		var m0 = modules.a[mi]; if (!modules.z[mi]) throw 'module $mi used when not alive';
		var wavetableb = tone.getFloatsBuffer(buffers.a[m0.buf_ref[2]]);
		floatallocator.rawbuf[wavetableb.first + (idx & 255)] = v;
	}
	
	public function out(mi : Int) {
		var modules = tone.modules;
		var buffers = tone.buffers;
		var m0 = modules.a[mi]; if (!modules.z[mi]) throw 'module $mi used when not alive';
		return tone.getFloatsBuffer(buffers.a[m0.buf_ref[0]]);
	}
	
	// z * a: 0, -1, -2, 
	
	// z = 0		a = 1		r = 1
	// z = -0.5		a = 1		r = 0.5
	// z = -1		a = 1		r = 0
	// z = 0.5		a = 1		r = 0.5
	// z = 1		a = 1		r = 0
	
	// z = 0		a = 2		r = 1
	// z = -0.5		a = 2		r = 0.75
	// z = -1		a = 2		r = 0.5
	// z = 0.5		a = 2		r = 0.75
	// z = 1		a = 2		r = 0.5

	// z = 0		a = 0.5		r = 1
	// z = -0.5		a = 0.5		r = 0
	// z = -1		a = 0.5		r = 0
	// z = 0.5		a = 0.5		r = 0
	// z = 1		a = 0.5		r = 0
	
	/* triangle resampler. z is offset. a is 1/width. */
	public inline function triangle(z : Float, a : Float) {
		return Math.max(0., 1 - Math.abs(z * a));
	}
	/* blackman-harris window */
	public inline function blackmanharris(z : Float) {
		var y = 2 * Math.PI * z;
		return 0.35875 
			- 0.48829 * Math.cos(y) 
			+ 0.14128 * Math.cos(y * 2)
			- 0.01168 * Math.cos(y * 3);
	}
	
	/* LUT resampler. z is offset. a is 1/width. */
	public inline function lut(z : Float, a : Float) {
		return resamplertab[Std.int(Math.max(0., 1 - Math.abs(z * a))*(resamplertab.length-1))];
	}
	
	public function write(mi : Int) {
		var modules = tone.modules;
		var buffers = tone.buffers;
		var floatallocator = tone.floatallocator;
		var m0 = modules.a[mi]; if (!modules.z[mi]) throw 'module $mi used when not alive';
		var outb = tone.getFloatsBuffer(buffers.a[m0.buf_ref[0]]);
		var stateb = tone.getFloatsBuffer(buffers.a[m0.buf_ref[1]]);
		var wavetableb = tone.getFloatsBuffer(buffers.a[m0.buf_ref[2]]);
		var fb = floatallocator.rawbuf;
		var z0 = fb[stateb.first];
		var deltaz = fb[stateb.first + 1];
		var table = wavetableb.first;
		
		// TODO: Higher quality resampling methods. Linear + octave mipmap?
		// with mipmap i feasibly have levels for 128(2p), 64(4p), 32(8p), 16(16p).
		// however the bigger quality difference is with the >256 wavelengths.
		// for those it'd be nice to switch to a triangular resampler that gets progressively
		// narrower.
		
		var alpha = 1./deltaz;
		for (i0 in outb.first...outb.last)
		{
			var zi = Std.int(z0);
			var zd = z0 - zi;
			// lookup table
			//fb[i0] = fb[Std.int(table + /*s0*/(zi & (255)))] * lut(zd - 1, alpha) +
				//fb[Std.int(table + /*s0*/((zi + 1) & (255)))] * lut(zd, alpha) +
				//fb[Std.int(table + /*s0*/((zi + 2) & (255)))] * lut(zd + 1, alpha);
			// linear
			fb[i0] = fb[Std.int(table + /*s0*/(zi & (255)))] * (1 - zd) + 
					 fb[Std.int(table + /*s1*/((zi + 1) & (255)))] * zd;
			// simple nearest
			//fb[i0] = fb[table + (Std.int(z0 + 0.5) & (255))]; // simple nearest
			z0 += deltaz;
		}
		fb[stateb.first] = z0;
	}
	
	
}