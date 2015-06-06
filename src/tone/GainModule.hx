package tone;

enum GainType {
	Step;
	Linear;
}

class GainModule {
	
	public var tone : Tone;
	public var module_id : Int;
	
	public function new(t : Tone) {
		this.tone = t;
		this.module_id = tone.assignModuleId(this);
	}
	
	public function spawn(output : Int, type : GainType, points : Int) {
		var modules = tone.modules;
		var pcm = tone.pcm;
		var module0 = modules.spawn();
		var module = modules.a[module0];
		
		// depending on which type, we spawn slightly different modules:
		// step - apply the point or sample nearest
		// linear - interpolate between the points
		
		// should they be different modules? probably not.
		
		module.buf_ref = [
			output, /* outb */
			tone.spawnInts(1), /* typeb */
			tone.spawnFloats(points), /* envelopeb */
			];
		module.module_id = module_id;
		module.module_type = 0;
		module.pcm_info = [];
		return module0;
	}
	
	public function free(module0 : Int) {
		tone.modules.despawn(module0);
	}	
	
}