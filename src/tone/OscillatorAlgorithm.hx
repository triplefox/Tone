package tone;
import haxe.ds.Vector;
import tone.Tone.Buffer;
import tone.Tone.BufferAllocatorFloat;

enum OscillatorType {
	Sawtooth;
	Square;
	Pulse25;
	Pulse12;
	Triangle;
}

class OscillatorAlgorithm {
	
	public static function sine(allocator : BufferAllocatorFloat, target : Buffer) {
		var SEQRES = target.length();
		var fb = allocator.rawbuf;
		var start = target.first;
		for (n in 0...SEQRES) fb[start + n] = Math.sin(n / (SEQRES - 1) * Math.PI * 2);
	}
	
	public static function preset(
		allocator : BufferAllocatorFloat, target : Buffer, sinetable : Buffer,
		oscillator : OscillatorType, frequency : Float, samplerate : Int) {
		
		// create an additive signal!
		
		var CUTOFF = 1 / 2; // points needed to render a sine
		var octaves = 1;
		while (frequency*octaves < samplerate) { octaves++; }
		octaves = octaves >> 1;
		if (octaves < 1) octaves = 1;
		
		var buffer = allocator.rawbuf;
		var start = target.first;
		var length = target.length();
		var wt_length = length - 1;
		
		var hw = wt_length >> 1;
		
		var sine = sinetable.first;
		var sintab_length = sinetable.length();
		
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
					result = result + buffer[sine + (i * oo & (sintab_length - 1))] * sign / oo;
					sign = -sign;
					oo++;
					if (oo * ofreq > CUTOFF) break; // cut off octaves too high to render accurately
				}
				
				buffer[start + pos] = result * scale;
			}
		}
		else if (oscillator == Square || oscillator == Pulse25 || oscillator == Pulse12)
		{
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
					// general additive rectangular function (cos * sin) (note: does not look like a square)
					result = result + 
						buffer[sine + (Std.int((i + hpi) * oo) & (sintab_length - 1))] *
						buffer[sine + (Std.int(oo * pw * hpi) & (sintab_length - 1))]
						/ oo;
					oo+=1;
					if (oo * ofreq > CUTOFF) break; // cut off octaves too high to render accurately
				}
				
				buffer[start + pos] = result * scale;
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
					result = result + buffer[sine + (i * oo & (sintab_length - 1))] * sign / (oo*oo);
					sign = -sign;
					oo+=2;
					if (oo * ofreq > CUTOFF) break; // cut off octaves too high to render accurately
				}
				
				buffer[start + pos] = result * scale;
			}
		}
		
		// we only compute half, and mirror the waveform at the halfway point.
		
		{
			for (pos in 0...hw)
			{
				buffer[start + pos + hw] = -buffer[start + hw - pos];
			}
		}
		
		// we pad by one because it's possible for the reader to jump over by one with FP error.
		buffer[start + length] = buffer[start];
		
	}	
	
}

