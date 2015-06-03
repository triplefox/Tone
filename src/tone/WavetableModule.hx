package tone;
import haxe.ds.Vector;

class WavetableModule {

	/* a 256-sample wavetable with linear resampling. */
	
	public var tone : Tone;
	public var module_id : Int;
	
	public static var rst : Int;
	
	public function new(t : Tone) {
		this.tone = t;
		this.module_id = tone.assignModuleId(this);
		
		// TODO: go move this into a LUTResampler module.
		{
			rst = tone.spawnFloats(1024);
			var rb = tone.floatsRawBuf(); 
			var first = tone.getFloatsBuffer(tone.buffers.a[rst]).first;
			for (i0 in 0...1024) {
				//rb[first + i0] = blackmanharris(0.5 - (i0/1023 / 2));
				rb[first + i0] = lanczos((i0/1023), 3.);
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
	
	/* triangle resampler. z is offset, centered between 0.0, 2.0 */
	public inline function triangle(z : Float) {
		return Math.max(0., 1 - Math.abs(z));
	}
	/* blackman-harris window, centered between 0.0, 1.0 */
	public inline function blackmanharris(z : Float) {
		var y = 2 * Math.PI * z;
		return 0.35875 
			- 0.48829 * Math.cos(y) 
			+ 0.14128 * Math.cos(y * 2)
			- 0.01168 * Math.cos(y * 3);
	}
	public inline function sinc(z : Float) {
		if (z == 0) return 1.; else return Math.sin(z*Math.PI) / (z*Math.PI);
	}
	/* lanczos window, centered between -a, a */
	public inline function lanczos(z : Float, a : Float) {
		if (z > -a && z < a) return (sinc(z) * sinc(z/a));
		else return 0.;
	}
	
	/* LUT resampler. z is offset 0-1. */
	public inline function lut(z : Float, d : Vector<Float>, first : Int, len : Int) {
		return d[first + Std.int(Math.min(len, Math.abs(z * 2) * len))];
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
		
		var alpha = 1./deltaz;
		var rstd = tone.floatsDeref(rst);
		var lutf = rstd.first;
		var lutlen = rstd.length();
		
		// The 16-tap works relatively well - after compensating for the alpha value,
		// it only breaks up when the taps fail to reach the impulses at the low end.
		// it costs about 3% CPU over the linear version.
		// when I use the triangle function I get a grainier sound, but less whirlwind artifacts.
		
		// The breakups are caused by taps that jump over the bulk of the impulse.
		// When deltaz is at 1, we only need exactly one tap.
		// When deltaz is 2, we need 2 additional taps to incorporate the wider bands of the adjacent impulses.
		// When deltaz is less than 1, we need the tap of the nearest two impulses only!
		
		// The trouble isn't with the number of taps, but with the assumed width of each impulse!
		// As our impulses get smaller in width, the premise of most windowing functions fails.
		// We would have to switch to one that allows ringing to eliminate the zero-power zones.
		// A reasonable compromise would be linear down, 2-tap Blackman-Harris or Lanczos up.
		// This gives us nearly the same CPU performance going both directions, and adequate quality.
		
		// I need to test on additive versions of my wavetable oscillators before I come to a conclusion.
		
		for (i0 in outb.first...outb.last)
		{
			var zi = Std.int(z0);
			var zd = z0 - zi;
			// lookup table (2 tap)
			//fb[i0] = 
				//fb[Std.int(table + (zi & (255)))] * alpha * lut(alpha * (1 - zd), fb, lutf, lutlen) +
				//fb[Std.int(table + ((zi + 1) & (255)))] * alpha * lut(alpha * (zd), fb, lutf, lutlen);
			// lookup table (16 tap)
			//fb[i0] = 
				//fb[Std.int(table + /*s0*/(zi & (255)))] * alpha * lut(alpha * (zd - 7.5), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s1*/((zi+1) & (255)))] * alpha * lut(alpha * (zd - 6.5), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s2*/((zi+2) & (255)))] * alpha * lut(alpha * (zd - 5.5), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s3*/((zi+3) & (255)))] * alpha * lut(alpha * (zd - 4.5), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s4*/((zi+4) & (255)))] * alpha * lut(alpha * (zd - 3.5), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s5*/((zi+5) & (255)))] * alpha * lut(alpha * (zd - 2.5), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s6*/((zi+6) & (255)))] * alpha * lut(alpha * (zd - 1.5), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s7*/((zi+7) & (255)))] * alpha * lut(alpha * (zd - 0.5), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s8*/((zi+8) & (255)))] * alpha * lut(alpha * (zd + 0.5), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s9*/((zi+9) & (255)))] * alpha * lut(alpha * (zd + 1.5), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s10*/((zi+10) & (255)))] * alpha * lut(alpha * (zd + 2.5), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s11*/((zi+11) & (255)))] * alpha * lut(alpha * (zd + 3.5), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s12*/((zi+12) & (255)))] * alpha * lut(alpha * (zd + 4.5), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s13*/((zi+13) & (255)))] * alpha * lut(alpha * (zd + 5.5), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s14*/((zi+14) & (255)))] * alpha * lut(alpha * (zd + 6.5), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s15*/((zi+15) & (255)))] * alpha * lut(alpha * (zd + 7.5), fb, lutf, lutlen)
				//;
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