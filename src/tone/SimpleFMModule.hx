package tone;

class SimpleFMModule {
	
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
			tone.spawnFloats(5), /* stateb */
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
	
	public function setWavelength(mi : Int, wl : Float) {
		var modules = tone.modules;
		var buffers = tone.buffers;
		var floatallocator = tone.floatallocator;
		var m0 = modules.a[mi]; if (!modules.z[mi]) throw 'module $mi used when not alive';
		var stateb = tone.getFloatsBuffer(buffers.a[m0.buf_ref[1]]);
		floatallocator.rawbuf[stateb.first] = wl;
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
		var deltaz = fb[stateb.first];
		var z0 = fb[stateb.first + 1];
		var z1 = fb[stateb.first + 2];
		var z2 = fb[stateb.first + 3];
		var z3 = fb[stateb.first + 4];
		var dzp = deltaz * Math.PI;
		var fmul1 = 1/4;
		var fmul2 = 1/4;
		var fmul3 = 1/4;
		var amul1 = 1/4;
		var amul2 = 1/4;
		var amul3 = 1/4;
		for (i0 in outb.first...outb.last)
		{
			// what am I doing... I will have to create all the different routing algorithms...
			// I have to choose between add and multiply in various places etc.
			
			fb[i0] = Math.sin(z3 * Math.PI);
			z0 += dzp;
			z1 += Math.sin(z0 * Math.PI * fmul1) * amul1;
			z2 += Math.sin(z1 * Math.PI * fmul2) * amul2;
			z3 += Math.sin(z2 * Math.PI * fmul3) * amul3;
		}
		switch(ib[typeb.first]) {
			case 0: /* sine */
		}
		fb[stateb.first + 1] = z0;
		fb[stateb.first + 2] = z1;
		fb[stateb.first + 3] = z2;
		fb[stateb.first + 4] = z3;
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