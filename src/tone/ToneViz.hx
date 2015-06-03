package tone;
import haxe.ds.Vector;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.Lib;
import tone.Tone;

class ToneViz
{
	
	public static function genericVizBitmap() {
		var bm = new Bitmap(new BitmapData(Lib.current.stage.stageWidth, Lib.current.stage.stageHeight >> 1, true, 0));
		bm.y = Lib.current.stage.stageHeight / 2 - bm.height / 2;
		return bm;
	}
	
	public static inline function linScale(l0 : Float, h0 : Float, l1 : Float, h1 : Float, z : Float) : Float {
		/* linear rescaling function */
		return ((z - l0) / (h0 - l0)) * (h1 - l1) + l1;
	}
	
	public static function renderFloatsLine(bd : BitmapData, v0 : Vector<Float>, 
		r0 : Rectangle, start : Int, end : Int, color : UInt) {
		/* render a line chart using "squarish" interpolation between points */
		var prevz = v0[start];
		var prevx = 0;
		var l0 = -1.;
		var h0 = 1.;
		var l1 = r0.height-1;
		var h1 = 0.;
		var prevy = Math.round(linScale(l0, h0, l1, h1, prevz));
		var starty = 0.;
		var endy = 0.;
		bd.lock();
		var r1 = new Rectangle();
		var pos = start + 0.;
		while (pos <= end)
		{
			var i0 = Std.int(pos);
			var x = Std.int(linScale(start, end, 0., r0.width, i0));
			var z = v0[i0];
			var y = Math.round(linScale(l0, h0, l1, h1, z));
			if (y < prevy) { starty = y; endy = prevy; } else { endy = y; starty = prevy; }
			r1.x = Std.int(prevx + r0.x);
			r1.y = Std.int(starty + r0.y);
			r1.height = Math.max(1., Std.int(endy - starty));
			r1.width = Math.max(1., Std.int(x - prevx));
			bd.fillRect(r1, color);
			prevy = y;
			prevx = x;
			pos += ((end-start) / r0.width);
		}
		bd.unlock();
	}
	
	public static function renderIntervals(bd : BitmapData,
		r0 : Rectangle, start : Int, end : Int, offset : Int, interval_len : Int, color : UInt) {
		
		bd.lock();
		var r1 = new Rectangle();
		r1.width = 1;
		r1.height = r0.height;
		r1.y = r0.y;
		for (i0 in start...(end+1))
		{
			if ((i0 - start + offset) % interval_len == 0)
			{
				var x = Std.int(linScale(start, end, 0., r0.width, i0));
				r1.x = Std.int(x + r0.x);
				bd.fillRect(r1, color); /* render a vertical line */
			}
		}
		bd.unlock();
		
	}
	
}