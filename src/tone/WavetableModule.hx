package tone;
import haxe.ds.Vector;

enum OscillatorType {
	Sawtooth;
	Square;
	Pulse25;
	Pulse12;
	Triangle;
}

class WavetableModule {

	/* a 256-sample wavetable with linear resampling. */
	
	public var tone : Tone;
	public var module_id : Int;
	
	public static var rst : Int;
	
	public static inline var TABLE_LEN = 256;
	
	public function new(t : Tone) {
		this.tone = t;
		this.module_id = tone.assignModuleId(this);
		
		// TODO: go move this into a LUTResampler module.
		{
			rst = tone.spawnFloats(1024);
			var rb = tone.floatsRawBuf(); 
			var first = tone.getFloatsBuffer(tone.buffers.a[rst]).first;
			for (i0 in 0...1024) {
				//rb[first + i0] = blackmanharris(0.5 - (i0/1023));
				rb[first + i0] = lanczos(((i0/1023)), 5.); 
				//rb[first + i0] = lanczos((i0/511), 5.);
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
	
	public inline function getTable(mi : Int, idx : Int) : Float {
		var modules = tone.modules;
		var buffers = tone.buffers;
		var floatallocator = tone.floatallocator;
		var m0 = modules.a[mi]; if (!modules.z[mi]) throw 'module $mi used when not alive';
		var wavetableb = tone.getFloatsBuffer(buffers.a[m0.buf_ref[2]]);
		return floatallocator.rawbuf[wavetableb.first + (idx & 255)];
	}
	
	public inline function preset(mi : Int, oscillator : OscillatorType) {
		
		var frequency = 440;
		
		// we cache every midi note to quarter-step accuracy. (This biases towards even temperament...oh well)
		//var cacheidx = Std.int((12 * (Math.log(frequency / 440.) / Math.log(2))) * 4);
		//frequency = (Math.pow(2, (cacheidx / 4) / 12) * 440); // snap computed freq
		//var snap = wtCache[oscillator].get(cacheidx);
		//if (snap != null) return snap;
		
		// create an additive signal!
		
		var SAMPLERATE = 22050;
		
		var CUTOFF = 1 / 2; // points needed to render a sine
		var octaves = 1;
		while (frequency*octaves < SAMPLERATE) { octaves++; }
		octaves = octaves >> 1;
		if (octaves < 1) octaves = 1;
		var wt_length = TABLE_LEN - 1;
		
		var hw = wt_length >> 1;
		
		var SEQRES = 4096;
		var sintab = Vector.fromArrayCopy([for (n in 0...SEQRES) Math.sin(n / SEQRES * Math.PI * 2)]);
		var sintab_length = sintab.length - 1;
		
		var base_scale = 2 / Math.PI * 0.45;
		
		if (oscillator == Sawtooth)
		{
			var scale = base_scale * 0.95;
			for (pos in 0...hw)
			{
				var result = 0.;
				var sign = -1;
				var ofreq = 1 / wt_length;
				var i = Math.round(pos / wt_length * sintab_length);
				
				var oo = 1;
				while (oo < octaves) 
				{
					result = result + sintab[i * oo & (sintab_length - 1)] * sign / oo;
					sign = -sign;
					oo++;
					if (oo * ofreq > CUTOFF) break; // cut off octaves too high to render accurately
				}
				
				setTable(mi, pos, result * scale);
			}
		}
		else if (oscillator == Square || oscillator == Pulse25 || oscillator == Pulse12)
		{
			// TODO: None of these look like what I expect...
			var scale = base_scale;
			var wt_length = wt_length;
			var pw = 0.5;
			if (oscillator == Pulse25) { pw = 0.25; scale *= 1.2; }
			else if (oscillator == Pulse12) { pw = 0.125; scale *= 1.37; }
			else scale *= 1.4;
			var hpi = sintab_length >> 1;
			for (pos in 0...hw)
			{
				var result = 0.;
				var ofreq = 1 / wt_length;
				var i = Math.round(pos / wt_length * sintab_length);
				
				var oo = 1;
				while (oo < octaves) 
				{
					// general additive rectangular function (cos * sin)
					result = result + 
						sintab[Std.int((i + hpi) * oo) & (sintab_length - 1)] *
						sintab[Std.int(oo * pw * hpi) & (sintab_length - 1)]
						/ oo;
					oo+=1;
					if (oo * ofreq > CUTOFF) break; // cut off octaves too high to render accurately
				}
				
				setTable(mi, pos, result * scale);
			}			
		}
		else if (oscillator == Triangle)
		{
			var scale = base_scale * 2.5;
			for (pos in 0...hw)
			{
				var result = 0.;
				var sign = -1;
				var ofreq = 1 / wt_length;
				var i = Math.round(pos / wt_length * sintab_length);
				
				var oo = 1;
				while (oo < octaves) 
				{
					result = result + sintab[i * oo & (sintab_length - 1)] * sign / (oo*oo);
					sign = -sign;
					oo+=2;
					if (oo * ofreq > CUTOFF) break; // cut off octaves too high to render accurately
				}
				
				setTable(mi, pos, result * scale);
			}
		}
		
		// we only compute half, and mirror the waveform at the halfway point.
		
		{
			for (pos in 0...hw)
			{
				setTable(mi, pos + hw, -getTable(mi, hw - pos));
			}
		}
		
		// we pad by one because it's possible for the reader to jump over by one with FP error.
		setTable(mi, TABLE_LEN, getTable(mi, 0));
		
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
	/* triangle resampler. z is offset, centered between 0.0, 1.0 */
	public inline function triangle2(z : Float) {
		return Math.max(0., 0.5 - Math.abs(z))*2;
	}
	/* blackman-harris window, centered between 0.0, 1.0 */
	public inline function blackmanharris(z : Float) {
		var y = 2 * Math.PI * z;
		return 0.35875 
			- 0.48829 * Math.cos(y) 
			+ 0.14128 * Math.cos(y * 2)
			- 0.01168 * Math.cos(y * 3);
	}
	public inline function sinc1(z : Float) { /* centered between -1, 1 */
		if (z == 0) return 1.; else return Math.sin(z*Math.PI) / (z*Math.PI);
	}
	/* lanczos window, centered between -a, a where a indicates sidelobe falloff (usually 2-4) */
	public inline function lanczos(z : Float, a : Float) {
		if (z > -a && z < a) return (sinc1(z) * sinc1(z/a));
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
		
		// the alpha calculation is bad as I'm conflating two things:
		//		the width of each impulse band
		//		the ratio of amplitude area post resampling / pre resampling.
		//		ratio should be computable through an integration of the resampling window, i think?
		//			whatever the correct thing is, it needs to fix my power adjustment.
		var alpha = 1/deltaz;
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
		
		// SRC in r8brain is a good reference: https://github.com/avaneev/r8brain-free-src
		// it oversamples at 2x first, then interpolates that.
		// I may want to apply that strategy instead trying to do it direct, as oversampling is an easy add:
		//		all I have to do is plug in a fixed set of values for the kernel width and assign the result to temporaries.
		// 2x with Blackman-Harris and then linear would probably be a major improvement, and possibly simpler than
		// what i was trying to do.
		
		
		// result of studies in oversampling:
		// we can get pretty good results, but for the naive waveforms, it's actually far better to resort to linear
		// interpolation for upsampling!
		
		// and as we already knew, for downsampling, we need to low pass it.
		// lanczos is proving to be preferable for resampling(which i guess shouldn't be a surprise)
		
		var tap2x0 = lanczos(-2/2., 2.);
		var tap2x1 = lanczos(-1/2., 2.);
		var tap2x2 = lanczos(0., 2.);
		var tap2x3 = tap2x1;
		var tap2x4 = tap2x0;
		
		var tap4x0 = lanczos(-3/2., 5.);
		var tap4x1 = lanczos(-2/2., 5.);
		var tap4x2 = lanczos(-1/2., 5.);
		var tap4x3 = lanczos(0., 5.);
		var tap4x4 = tap4x2;
		var tap4x5 = tap4x1;
		var tap4x6 = tap4x0;
		
		for (i0 in outb.first...outb.last)
		{
			var zi = Std.int(z0);
			var zd = z0 - zi;
			
			// lanczos(2 tap)
			//fb[i0] = 0.5 * (
				//fb[Std.int(table + (zi & (255)))] * lanczos(alpha * (zd - 1), 5.) +
				//fb[Std.int(table + ((zi + 1) & (255)))] * lanczos(alpha * (zd), 5.));
			
			// lanczos(3 tap)
			//fb[i0] = 0.333333333 * (
				//fb[Std.int(table + (zi & (255)))] * lanczos(alpha * (zd - 1), 5.) +
				//fb[Std.int(table + ((zi + 1) & (255)))] * lanczos(alpha * (zd), 5.) +
				//fb[Std.int(table + ((zi + 2) & (255)))] * lanczos(alpha * (zd + 1), 5.));
			
			// lanczos(4 tap)
			//fb[i0] = 0.25 * (
				//fb[Std.int(table + (zi & (255)))] * lanczos(alpha * (zd - 2), 5.) +
				//fb[Std.int(table + ((zi + 1) & (255)))] * lanczos(alpha * (zd - 1), 5.) +
				//fb[Std.int(table + ((zi + 2) & (255)))] * lanczos(alpha * (zd), 5.) +
				//fb[Std.int(table + ((zi + 3) & (255)))] * lanczos(alpha * (zd + 1), 5.));
			
			// lanczos(6 tap)
			if (deltaz > 1) {
			fb[i0] = alpha * (
				fb[Std.int(table + (zi & (255)))] * lanczos(alpha * (zd - 3), 5.) +
				fb[Std.int(table + ((zi + 1) & (255)))] * lanczos(alpha * (zd - 2), 5.) +
				fb[Std.int(table + ((zi + 2) & (255)))] * lanczos(alpha * (zd - 1), 5.) +
				fb[Std.int(table + ((zi + 3) & (255)))] * lanczos(alpha * (zd), 5.) +
				fb[Std.int(table + ((zi + 4) & (255)))] * lanczos(alpha * (zd + 1), 5.) +
				fb[Std.int(table + ((zi + 5) & (255)))] * lanczos(alpha * (zd + 2), 5.));
			}
			else {
				var low = fb[Std.int(table + /*s0*/(zi & (255)))];
				var hi = fb[Std.int(table + /*s1*/((zi + 1) & (255)))];
				fb[i0] = (hi - low) * zd + low;
			}
			
			// lookup table (2 tap)
			//fb[i0] = 0.5 * (
				//fb[Std.int(table + (zi & (255)))] * lut(alpha * (1 - zd), fb, lutf, lutlen) +
				//fb[Std.int(table + ((zi + 1) & (255)))] * lut(alpha * (zd), fb, lutf, lutlen));
				
			// lookup table (4 tap)
			//fb[i0] = 0.25 * (
				//fb[Std.int(table + (zi & (255)))] * lut(alpha * (zd - 2), fb, lutf, lutlen) +
				//fb[Std.int(table + ((zi + 1) & (255)))] * lut(alpha * (zd - 1), fb, lutf, lutlen) +
				//fb[Std.int(table + ((zi + 2) & (255)))] * lut(alpha * (zd), fb, lutf, lutlen) +
				//fb[Std.int(table + ((zi + 3) & (255)))] * lut(alpha * (zd + 1), fb, lutf, lutlen));
			
			// triangle (2 tap)
			//fb[i0] = alpha * (  
				//fb[Std.int(table + (zi & (255)))] * triangle(alpha * (1 - zd)) +
				//fb[Std.int(table + ((zi + 1) & (255)))] * triangle(alpha * (zd)));
			
			// lookup table (16 tap)
			//if (deltaz > 1) {
			//fb[i0] = (
				//fb[Std.int(table + /*s0*/(zi & (255)))] * lut(alpha * (zd - 8), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s1*/((zi+1) & (255)))] * lut(alpha * (zd - 7), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s2*/((zi+2) & (255)))] * lut(alpha * (zd - 6), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s3*/((zi+3) & (255)))] * lut(alpha * (zd - 5), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s4*/((zi+4) & (255)))] * lut(alpha * (zd - 4), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s5*/((zi+5) & (255)))] * lut(alpha * (zd - 3), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s6*/((zi+6) & (255)))] * lut(alpha * (zd - 2), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s7*/((zi+7) & (255)))] * lut(alpha * (zd - 1), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s8*/((zi+8) & (255)))] * lut(alpha * (zd), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s9*/((zi+9) & (255)))] * lut(alpha * (zd + 1), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s10*/((zi+10) & (255)))] * lut(alpha * (zd + 2), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s11*/((zi+11) & (255)))] * lut(alpha * (zd + 3), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s12*/((zi+12) & (255)))] * lut(alpha * (zd + 4), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s13*/((zi+13) & (255)))] * lut(alpha * (zd + 5), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s14*/((zi+14) & (255)))] * lut(alpha * (zd + 6), fb, lutf, lutlen) +
				//fb[Std.int(table + /*s15*/((zi+15) & (255)))] * lut(alpha * (zd + 7), fb, lutf, lutlen))
				//;
			//}
			//else {
				//var low = fb[Std.int(table + /*s0*/(zi & (255)))];
				//var hi = fb[Std.int(table + /*s1*/((zi + 1) & (255)))];
				//fb[i0] = (hi - low) * zd + low;
			//} 
			// linear (1.5x oversampled)
			//var left = fb[Std.int(table + /*s0*/(zi & (255)))];
			//var right = fb[Std.int(table + /*s1*/((zi + 1) & (255)))];
			//var vd = [
				//tap2x2 * left + tap2x0 * right,
				//tap2x3 * left + tap2x1 * right,
				//tap2x4 * left + tap2x2 * right,
				//tap2x3 * right
			//];
			//var z1 = Math.max(0., Math.min(1., (((zd - 0.5) * alpha) + 0.5))) * (vd.length-2);
			//var zi2 = Std.int(z1);
			//var zd2 = z1 - zi2;
			//fb[i0] = (vd[zi2 + 1] - vd[zi2]) * zd2 + vd[zi2];
			
			// linear (3x oversampled)
			//var left = fb[Std.int(table + /*s0*/(zi & (255)))];
			//var right = fb[Std.int(table + /*s1*/((zi + 1) & (255)))];
			//var vd = [
				//tap4x3 * left + tap4x0 * right,
				//tap4x4 * left + tap4x1 * right,
				//tap4x5 * left + tap4x2 * right,
				//tap4x6 * left + tap4x3 * right,
				//tap4x4 * right
			//];
			//var z1 = Math.max(0., Math.min(1., (((zd - 0.5) * alpha) + 0.5))) * (vd.length-2);
			//var zi2 = Std.int(z1);
			//var zd2 = z1 - zi2;
			//fb[i0] = (vd[zi2 + 1] - vd[zi2]) * zd2 + vd[zi2];
			//if (!Math.isFinite(fb[i0])) throw [z1,fb[i0], vd[zi2], vd[zi2+1], zd2, left, right,vd[0],vd[1],vd[2],vd[3]];
			
			// linear
			//var low = fb[Std.int(table + /*s0*/(zi & (255)))];
			//var hi = fb[Std.int(table + /*s1*/((zi + 1) & (255)))];
			//fb[i0] = (hi - low) * zd + low;
			// simple nearest
			//fb[i0] = fb[table + (Std.int(z0 + 0.5) & (255))]; // simple nearest
			z0 += deltaz;
		}
		fb[stateb.first] = z0;
	}
	
	
}