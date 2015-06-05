package tone;
import haxe.ds.Vector;
import lime.app.Module;

enum BufferType { Missing; Floats; Integers; }

class BufferRef { /* references buffer and type of buffer */
	public var buffer_id : Int;
	public var type : BufferType;
	public function new() {}
}

class PCMInfo { /* info chunk for pcm data */
	public var id : Int;
	public var samplerate : Int;
	public var channels : Int;
	public function new() {}
}

class Buffer {
	public var id : Int;
	public var first : Int;
	public var last : Int;
	public var chunkfirst : Int;
	public var chunklen : Int;
	public function length() { return last - first; }
	public function new() { first = 0; last = 0; chunkfirst = 0; chunklen = 0; }
}

class BufferAllocatorFloat
{
	public function new(slabsize : Int, slabs : Int, padding : Int, zero_data : Float) {
		buffer = new LifeArray("buffer", [for (i0 in 0...128) new Buffer()]);
		buffer.onExhausted = function(a0) { /* double */
			var l0 = a0.a.length; for (i0 in 0...l0) 
			{
				a0.a.push(new Buffer());
				a0.z.push(false);
			}
		}
		buffer.onSpawn = function(id : Int, obj : Buffer) {
			obj.chunklen = 0;
			obj.chunkfirst = 0;
			obj.first = 0;
			obj.last = 0;
			obj.id = id;
		};
		var bufsize = slabs * slabsize;
		rawbuf = new Vector(bufsize); for (i0 in 0...bufsize) rawbuf[i0] = zero_data;
		this.slabsize = slabsize;
		this.padding = padding;
		this.zero_data = zero_data;
		slaballoc = [for (i0 in 0...slabsize) false];
		alloc_ptr = 0;
	}
	
	public var buffer : LifeArray<Buffer>;
	public var rawbuf : Vector<Float>;
	public var zero_data : Float;
	public var slaballoc : Array<Bool>;
	public var slabsize : Int;
	public var padding : Int;
	public var alloc_ptr : Int;
	
	public inline function zero(start : Int, length : Int) {
		for (i0 in start...(start+length))
		{
			rawbuf[i0] = zero_data;
		}
	}
	
	public inline function atSlab(c0 : Int) { /* exact buffer position */
		return Std.int(slabsize * c0);
	}
	
	public function allocBuffer(size : Int) {
		var s0 = size + padding;
		var c0 = Std.int(Math.ceil(s0 / slabsize));
		var i0 = alloc_ptr;
		while (i0 + c0 < slaballoc.length)
		{
			var ok = true;
			for (i1 in i0...i0 + c0 + 1)
			{
				if (slaballoc[i1])
				{
					i0 = i1 + 1; ok = false; break;
				}
			}
			if (ok)
			{
				var obj = buffer.a[buffer.spawn()];
				obj.chunkfirst = i0;
				obj.chunklen = c0;
				for (i1 in i0...i0 + c0 + 1)
				{
					slaballoc[i1] = true;
				}
				zero(atSlab(i0), s0);
				obj.first = atSlab(i0);
				obj.last = obj.first + size;
				alloc_ptr = (i0 + c0 + 1) % slaballoc.length;
				return obj.id;
			}
		}
		/* overrun: allocate double the memory */
		var newbuf = new Vector<Float>(rawbuf.length * 2);
		for (i0 in 0...rawbuf.length) newbuf[i0] = rawbuf[i0];
		for (i0 in rawbuf.length...newbuf.length) newbuf[i0] = zero_data;
		rawbuf = newbuf;
		var oldlen = slaballoc.length;
		for (i0 in 0...oldlen)
		{
			slaballoc.push(false);
		}
		return allocBuffer(size);
	}
	
	public function freeBuffer(id : Int) {
		var b0 = buffer.a[id];
		for (i0 in b0.chunkfirst...b0.chunkfirst + b0.chunklen)
		{
			slaballoc[i0] = false;
		}
		buffer.despawn(id);
	}
	
}

class BufferAllocatorInt
{
	public function new(slabsize : Int, slabs : Int, padding : Int, zero_data : Int) {
		buffer = new LifeArray("buffer", [for (i0 in 0...128) new Buffer()]);
		buffer.onExhausted = function(a0) { /* double */
			var l0 = a0.a.length; for (i0 in 0...l0) 
			{
				a0.a.push(new Buffer());
				a0.z.push(false);
			}
		}
		buffer.onSpawn = function(id : Int, obj : Buffer) {
			obj.chunklen = 0;
			obj.chunkfirst = 0;
			obj.first = 0;
			obj.last = 0;
			obj.id = id;
		};
		var bufsize = slabs * slabsize;
		rawbuf = new Vector(bufsize); for (i0 in 0...bufsize) rawbuf[i0] = zero_data;
		this.slabsize = slabsize;
		this.padding = padding;
		this.zero_data = zero_data;
		slaballoc = [for (i0 in 0...slabsize) false];
	}
	
	public var buffer : LifeArray<Buffer>;
	public var rawbuf : Vector<Int>;
	public var zero_data : Int;
	public var slaballoc : Array<Bool>;
	public var slabsize : Int;
	public var padding : Int;
	
	public inline function zero(start : Int, length : Int) {
		for (i0 in start...(start+length))
		{
			rawbuf[i0] = zero_data;
		}
	}
	
	public inline function atSlab(c0 : Int) { /* exact buffer position */
		return Std.int(slabsize * c0);
	}
	
	public function allocBuffer(size : Int) {
		var s0 = size + padding;
		var c0 = Std.int(Math.ceil(s0 / slabsize));
		var i0 = 0;
		while (i0 + c0 < slaballoc.length)
		{
			var ok = true;
			for (i1 in i0...i0 + c0 + 1)
			{
				if (slaballoc[i1])
				{
					i0 = i1 + 1; ok = false; break;
				}
			}
			if (ok)
			{
				var obj = buffer.a[buffer.spawn()];
				obj.chunkfirst = i0;
				obj.chunklen = c0;
				for (i1 in i0...i0 + c0 + 1)
				{
					slaballoc[i1] = true;
				}
				zero(atSlab(i0), s0);
				obj.first = atSlab(i0);
				obj.last = obj.first + size;
				return obj.id;
			}
		}
		/* overrun: allocate double the memory */
		var newbuf = new Vector<Int>(rawbuf.length * 2);
		for (i0 in 0...rawbuf.length) newbuf[i0] = rawbuf[i0];
		for (i0 in rawbuf.length...newbuf.length) newbuf[i0] = zero_data;
		rawbuf = newbuf;
		var oldlen = slaballoc.length;
		for (i0 in 0...oldlen)
		{
			slaballoc.push(false);
		}
		return allocBuffer(size);
	}
	
	public function freeBuffer(id : Int) {
		var b0 = buffer.a[id];
		for (i0 in b0.chunkfirst...b0.chunkfirst + b0.chunklen)
		{
			slaballoc[i0] = false;
		}
		buffer.despawn(id);
	}
	
}

class Module {
	public var module_type : Int; /* which module class (if any) this is mapped to */
	public var module_id : Int; /* id referencing type instance, if any */
	public var buf_ref : Array<Int>; /* bufferref references */
	public var pcm_info : Array<Int>;
	public var string_data : Array<String>;
	public function new() {}
}

class Tone {

	public var floatallocator : BufferAllocatorFloat; /* float parameters and processing intermediates */ 
	public var intallocator : BufferAllocatorInt; /* integer parameters and processing intermediates */
	public var buffers : LifeArray<BufferRef>;
	public var modules : LifeArray<Module>;
	public var pcm : LifeArray<PCMInfo>;
	
	public var module_ids : Map<Int, Dynamic>;
	public function assignModuleId(module_class : Dynamic) : Int {
		var id = -1;
		while (id < 0 || module_ids.exists(id)) id = Std.int(Math.random() * 65535);
		module_ids.set(id, module_class);
		return id;
	}
	
	public function new()
	{
		floatallocator = new BufferAllocatorFloat(64, 64, 16, 0.);
		intallocator = new BufferAllocatorInt(64, 32, 16, 0);
		module_ids = new Map();
		
		buffers = new LifeArray("buffers", [for (i0 in 0...128) new BufferRef()]);
		buffers.onExhausted = 
			function(a0) { var dbl = a0.a.length; for (i0 in 0...dbl) { a0.a.push(new BufferRef()); a0.z.push(false); } };
		buffers.onSpawn =
			function(id : Int, obj : BufferRef) {
				obj.type = Missing;
			};
		buffers.onDespawn =
			function(id : Int, obj : BufferRef) {
				switch(obj.type)
				{
					case Missing:
					case Floats:
						floatallocator.freeBuffer(obj.buffer_id);
					case Integers:						
						intallocator.freeBuffer(obj.buffer_id);
				}
			};
			
		modules = new LifeArray("modules", [for (i0 in 0...128) new Module()]);		
		modules.onExhausted = 
			function(a0) { var dbl = a0.a.length; for (i0 in 0...dbl) { a0.a.push(new Module()); a0.z.push(false); } };
		modules.onSpawn =
			function(id : Int, obj : Module) {
				obj.buf_ref = [];
				obj.pcm_info = [];
				obj.string_data = [];
				obj.module_type = -1;
				obj.module_id = -1;
			};
		modules.onDespawn =
			function(id : Int, obj : Module) {
				for (b0 in obj.buf_ref)
					buffers.despawn(b0);
				for (p0 in obj.pcm_info)
					pcm.despawn(p0);
			};
			
		pcm = new LifeArray("pcm", [for (i0 in 0...128) new PCMInfo()]);
		pcm.onExhausted = 
			function(a0) { var dbl = a0.a.length; for (i0 in 0...dbl) {a0.a.push(new PCMInfo()); a0.z.push(false);}  };
		pcm.onSpawn =
			function(id : Int, obj : PCMInfo) {
				obj.id = id;
				obj.channels = -1;
				obj.samplerate = -1;
			};
		
	}
	
	public function getFloatsBuffer(b0 : BufferRef) : Buffer {
		if (b0.type == Floats) {
			return floatallocator.buffer.a[b0.buffer_id];
		}
		else { throw "wrong BufferProxy type, expected Floats, got " + Std.string(b0.type);
			return null;
		}
	}
	public function spawnFloats(size : Int) : Int {
		var b0 = floatallocator.allocBuffer(size);
		var b1 = buffers.spawn();
		var b2 = buffers.a[b1];
		b2.type = Floats;
		b2.buffer_id = b0;
		return b1;
	}
	
	public function getIntsBuffer(b0 : BufferRef) : Buffer {
		if (b0.type == Integers) {
			return intallocator.buffer.a[b0.buffer_id];
		}
		else { throw "wrong BufferProxy type, expected Integers, got " + Std.string(b0.type);
			return null;
		}
	}
	public function spawnInts(size : Int) : Int {
		var b0 = intallocator.allocBuffer(size);
		var b1 = buffers.spawn();
		var b2 = buffers.a[b1];
		b2.type = Integers;
		b2.buffer_id = b0;
		return b1;
	}
	
	public function floatsRawBuf() { return floatallocator.rawbuf; }
	public function floatsDeref(buf0 : Int) { return getFloatsBuffer(buffers.a[buf0]); }
	public function intsRawBuf() { return intallocator.rawbuf; }
	public function intsDeref(buf0 : Int) { return getIntsBuffer(buffers.a[buf0]); }
	public function module(m0 : Int) { return modules.a[m0]; }	
	
	public function copyFloats(b0 : Buffer, b1 : Buffer, b0_start : Int, b1_start : Int, len : Int) {
		var fb = floatallocator.rawbuf;
		var b0s = b0_start + b0.first;
		var b1s = b1_start + b1.first;
		if (len > b0.length() - b0_start) throw 'left side buffer is smaller (${b0.length()}) than expressed length ($len)';
		if (len > b1.length() - b1_start) throw 'right side buffer is smaller (${b1.length()}) than expressed length ($len)';
		for (i0 in 0...len) {
			fb[b1s + i0] = fb[b0s + i0];
		}
	}
	
	public function toStereo(b0 : Buffer, b1 : Buffer, b0_start : Int, b1_start : Int, len_b0 : Int) {
		var fb = floatallocator.rawbuf;
		var b0s = b0_start + b0.first;
		var b1s = b1_start + b1.first;
		if (len_b0 > b0.length() - b0_start) throw 'left side buffer is smaller (${b0.length()}) than expressed length ($len_b0)';
		if (len_b0 << 1 > b1.length() - b1_start) throw 'right side buffer is smaller (${b1.length()}) than expressed length ($len_b0)';
		for (i0 in 0...len_b0) {
			fb[(b1s + i0) << 1] = fb[b0s + i0];
			fb[((b1s + i0) << 1) + 1] = fb[b0s + i0];
		}
	}
	
}