package tone;

import haxe.ds.Vector;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.SampleDataEvent;
import openfl.Lib;
import openfl.media.Sound;
import openfl.media.SoundChannel;
import tone.Tone;
import tone.OscillatorAlgorithm;

/**
 * ...
 * @author nblah
 */

class Tests {
	
	public var bm : Bitmap;
	
	public function new() {
		/* shared visualizer */
		bm = ToneViz.genericVizBitmap();
		Lib.current.stage.addChild(bm);
	}
	
	public function all() {
		vizTest();
		allocationTest();		
	}
	
	public function vizTest() {
		bm.bitmapData.fillRect(bm.bitmapData.rect, 0);
		bm.bitmapData.fillRect(new openfl.geom.Rectangle(0., 0., bm.width, 1.), 0xFF0000FF);
		bm.bitmapData.fillRect(new openfl.geom.Rectangle(0., bm.bitmapData.height - 1, bm.width, 1.), 0xFF0000FF);
		bm.bitmapData.fillRect(new openfl.geom.Rectangle(0., bm.bitmapData.height / 2, bm.width, 1.), 0xFF0000FF);
		bm.bitmapData.fillRect(new openfl.geom.Rectangle(bm.width - 1, 0., 1., bm.height), 0xFFFF0000);
		var v0 = Vector.fromArrayCopy([for (i0 in 0...32) (i0 % 2) / 2]);
		ToneViz.renderFloatsLine(bm.bitmapData, v0, bm.bitmapData.rect, 0, v0.length - 1, 0xFFFFEE00);
		var v0 = Vector.fromArrayCopy([for (i0 in 0...32) -i0 / 31]);
		ToneViz.renderFloatsLine(bm.bitmapData, v0, bm.bitmapData.rect, 0, v0.length - 1, 0xFF00EE00);
		var v0 = Vector.fromArrayCopy([for (i0 in 0...3200) Math.sin(i0 / 3199 * Math.PI * 2)]);
		ToneViz.renderFloatsLine(bm.bitmapData, v0, bm.bitmapData.rect, 0, v0.length - 1, 0xFF00EE00);		
	}
	
	public function allocationTest() {
		var tone = new tone.Tone();
		var sine = new SineModule(tone);
		var sm0 = 0;
		for (i0 in 0...1000)
		{
			sm0 = sine.spawn(tone.spawnFloats(64));
			sine.write(sm0);
			sine.free(sm0);
		}
		sm0 = sine.spawn(tone.spawnFloats(64));
		sine.write(sm0);
		sine.free(sm0);
		
		bm.bitmapData.fillRect(bm.bitmapData.rect, 0);
		var buf = tone.floatsDeref(tone.module(sm0).buf_ref[0]);
		ToneViz.renderFloatsLine(bm.bitmapData, tone.floatallocator.rawbuf, bm.bitmapData.rect, buf.first, buf.last, 0xFF00EE00);
		//ToneViz.renderFloatsLine(bm.bitmapData, tone.floatsRawBuf(), bm.bitmapData.rect, 0, tone.floatsRawBuf() - 1, 0xFF00EE00);		
	}
	
}

class Realtime {
	
	public var snd : Sound;
	public var snch : SoundChannel;
	public var tone : Tone;
	public var sine : SineModule;
	public var wave : WavetableModule;
	public var sosc : SimpleOscModule;
	public var blep : PolyBLEPModule;
	public var sefm : SimpleFMModule;
	public var ads : ADSR;
	public var tonebuf : Buffer;
	public var sinemodule : Int;
	public var wavemodule : Int;
	public var soscmodule : Int;
	public var blepmodule : Int;
	public var sefmmodule : Int;
	public var adsmodule : Int;
	public var lfomodule : Int;
	
	public function new() {
		
	}
	
	public function start() {
		if (tone == null) throw "Tone is not set on Realtime";
		if (sine == null) throw "SineModule is not set on Realtime";
		if (wave == null) throw "WavetableModule is not set on Realtime";
		if (sosc == null) throw "SimpleOscModule is not set on Realtime";
		if (blep == null) throw "PolyBLEPModule is not set on Realtime";
		if (sefm == null) throw "SimpleFMModule is not set on Realtime";
		if (ads == null) throw "ADS is not set on Realtime";
		if (tonebuf == null) throw "Realtime doesn't have a Buffer to copy from";
		if (snd != null) stop();
		snd = new Sound();
		
		var buflen = tonebuf.length() >> 1; // run all oscillators in mono
		
		sinemodule = sine.spawn(tone.spawnFloats(buflen));
		sine.setWavelength(sinemodule, 440. / 22050);
		
		//soscmodule = sosc.spawn(tone.spawnFloats(buflen));
		//sosc.setWavelength(soscmodule, 440. / 22050);
		//sosc.setType(soscmodule, 3);
		//
		blepmodule = blep.spawn(tone.spawnFloats(buflen));
		blep.setWavelength(blepmodule, 440. / 22050);
		blep.setType(blepmodule, 3);
		
		//sefmmodule = sefm.spawn(tone.spawnFloats(buflen));
		//sefm.setWavelength(sefmmodule, 440. / 22050);
		//sefm.setType(sefmmodule, 3);
		
		//wavemodule = wave.spawn(tone.spawnFloats(buflen));
		//wave.setWavelength(wavemodule, 440. / 22050);
		//for (i0 in 0...128) wave.setTable(wavemodule, i0, 0.25); // sqr(1)
		//for (i0 in 128...256) wave.setTable(wavemodule, i0, -0.25); // sqr(2)
		//for (i0 in 0...128) wave.setTable(wavemodule, i0, 0.25 * i0/128); // saw(1)
		//for (i0 in 0...128) wave.setTable(wavemodule, i0 + 128, 0.25 * i0/128 - 0.25); // saw(2)
		//for (i0 in 0...256) wave.setTable(wavemodule, i0, 0.5); // flat
		//for (i0 in 0...256) wave.setTable(wavemodule, i0, Math.sin((i0*Math.PI*2)/255) * 0.5); // sine
		
		//wave.preset(wavemodule, Pulse25);
		//var modbuf = wave.tableBuffer(wavemodule);
		
		//var sintab = tone.spawnFloats(4096);
		//OscillatorAlgorithm.sine(tone.floatallocator, tone.floatsDeref(sintab));
		//OscillatorAlgorithm.preset(tone.floatallocator, modbuf, tone.floatsDeref(sintab), 
		//	Sawtooth, 256 / 22050, 22050);
		
		lfomodule = sine.spawn(tone.spawnFloats(buflen));
		sine.setWavelength(lfomodule, 0.01 / 22050);
		//sine.setWavelength(lfomodule, 1 / 22050);
		
		//adsmodule = ads.spawn(sefm.out(sefmmodule).id, tone.spawnFloats(buflen));
		adsmodule = ads.spawn(blep.out(blepmodule).id, tone.spawnFloats(buflen));
		ads.setFloatParam(adsmodule, ADSR.ATTACK, 2205);
		ads.setFloatParam(adsmodule, ADSR.DECAY, 2205);
		ads.setFloatParam(adsmodule, ADSR.SUSTAIN, 0.5);		
		ads.setFloatParam(adsmodule, ADSR.RELEASE, 2205);
		
		snd.addEventListener(SampleDataEvent.SAMPLE_DATA, onSampleData);
		snch = snd.play();
	}
	
	public function stop() {
		snd.removeEventListener(SampleDataEvent.SAMPLE_DATA, onSampleData);
		snch.stop();
		snch = null;
		snd = null;
	}
	
	public var smp = 0.;
	
	public function onSampleData(evt : SampleDataEvent) {
		
		var total = 0;
		evt.data.position = 0;
		while (total < 4096) {
			/* run a frame of tone */
			sine.write(lfomodule);
			var lfo_freq = (880. + tone.floatsRawBuf()[sine.out(lfomodule).first] * 879. ) / 22050;
			//var lfo_freq = ((22050/256) + tone.floatsRawBuf()[sine.out(lfomodule).first] * 10. ) / 22050;
			//var lfo_freq = (22050 / 256) / 22050;
			//var lfo_freq = 440 / 22050;
			sine.setWavelength(sinemodule, (lfo_freq));
			sine.write(sinemodule);
			//wave.setWavelength(wavemodule, (lfo_freq));
			//wave.write(wavemodule);
			
			//sosc.setWavelength(soscmodule, (lfo_freq));
			//sosc.write(soscmodule);
			blep.setWavelength(blepmodule, (lfo_freq));
			blep.write(blepmodule);
			//sefm.setWavelength(sefmmodule, (lfo_freq));
			//sefm.write(sefmmodule);
						
			// so, this works in that the LFO behaves as we expect,
			// but it's weird that i am writing out a whole frame of samples and then taking one.
			// which suggests that...I should just provide a whole buffer within the sine?
			// except that then the problem recurses?
			// it doesn't, it stops at the point where I have a flatline buffer.
			// in effect, if I want to do FM... I have a great little tool for it.
			// run it at 2x rate and downsample too, that allows me to introduce resampling algorithms.
			
			ads.write(adsmodule);
			
			//tone.copyFloats(tone.sineOut(sinemodule), tonebuf, 0, 0, tonebuf.length());
			//tone.toStereo(sine.out(sinemodule), tonebuf, 0, 0, tonebuf.length() >> 1);
			//tone.toStereo(wave.out(wavemodule), tonebuf, 0, 0, tonebuf.length() >> 1);
			//tone.toStereo(sosc.out(soscmodule), tonebuf, 0, 0, tonebuf.length() >> 1);
			//tone.toStereo(blep.out(blepmodule), tonebuf, 0, 0, tonebuf.length() >> 1);
			//tone.toStereo(sefm.out(sefmmodule), tonebuf, 0, 0, tonebuf.length() >> 1);
			tone.toStereo(ads.out(adsmodule), tonebuf, 0, 0, tonebuf.length() >> 1);
		
			/* copy frame */
			var raw = tone.floatsRawBuf();
			var first = tonebuf.first;
			var len = tonebuf.length();
			for (i0 in 0...len)
			{
				evt.data.writeFloat(raw[first + i0]);
			}
			total += len;
		}
		
		/*for (i0 in 0...2048) {
			evt.data.writeFloat(Math.sin(smp * 3.1415));
			evt.data.writeFloat(Math.sin(smp * 3.1415));
			smp += 440/44100;
		}*/
	}
	
}

class VizCam {
	
	public var bm : Bitmap;
	public var cam_x : Int;
	public var cam_width : Int;
	public var intervalsize : Int;
	public var buf : Vector<Float>;
	
	public function new(bm : Bitmap, buf : Vector<Float>, intervalsize : Int) {
		this.bm = bm;
		this.cam_x = 0;
		this.cam_width = 1024;
		this.intervalsize = intervalsize;
		this.buf = buf;
	}
	
	public function translate(x : Int) {
		cam_x += x;
		if (cam_x < 0) cam_x = 0;
		if (cam_x + cam_width > buf.length) cam_x = buf.length - cam_width;		
	}
	
	public function update() {
		ToneViz.renderIntervals(bm.bitmapData, 
			bm.bitmapData.rect, cam_x, cam_x+cam_width, cam_x, intervalsize, 0xFF4444FF);
		ToneViz.renderFloatsLine(bm.bitmapData, buf, bm.bitmapData.rect, cam_x, cam_x+cam_width, 0xFF448844);
	}
	
}

class Main extends Sprite 
{

	public function new() 
	{
		super();
		
		var rte = new Realtime();
		rte.tone = new Tone();
		rte.tonebuf = rte.tone.floatsDeref(rte.tone.spawnFloats(256));
		rte.sine = new SineModule(rte.tone);
		rte.wave = new WavetableModule(rte.tone);
		rte.sosc = new SimpleOscModule(rte.tone);
		rte.blep = new PolyBLEPModule(rte.tone);
		rte.sefm = new SimpleFMModule(rte.tone);
		rte.ads = new ADSR(rte.tone);
		rte.start();
		
		var bm = ToneViz.genericVizBitmap();
		Lib.current.stage.addChild(bm);
		
		var cam = new VizCam(bm, rte.tone.floatsRawBuf(), rte.tone.floatallocator.slabsize);
		
		Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, function(evt) {
			if (evt.keyCode == 39)
				cam.translate(rte.tone.floatallocator.slabsize >> 1);
			else if (evt.keyCode == 37)
				cam.translate( -rte.tone.floatallocator.slabsize >> 1);
			else if (evt.keyCode == 65)
				rte.ads.start(rte.adsmodule);
			else if (evt.keyCode == 66)
				rte.ads.release(rte.adsmodule);
		});
		Lib.current.stage.addEventListener(Event.ENTER_FRAME, function(evt) {
			bm.bitmapData.fillRect(bm.bitmapData.rect, 0);
			cam.update();
		});
		
		// Assets:
		// openfl.Assets.getBitmapData("img/assetname.jpg");
	}
	
}
