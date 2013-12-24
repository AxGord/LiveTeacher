package ;

import flash.display.Sprite;
import flash.display.StageAlign;
import flash.display.StageScaleMode;
import flash.Lib;
import flash.text.TextField;
import flash.text.TextFieldType;
import flash.events.Event;
import flash.text.TextFormat;
import flash.display.LineScaleMode;
import flash.events.KeyboardEvent;
import flash.ui.Keyboard;
import pony.Tools;

import hscript.Interp;
import hscript.Parser;
import hscript.Expr;
import pony.DeltaTime;

using pony.flash.FLExtends;

/**
 * ...
 * @author AxGord
 */

class Main
{
	public static var width:Int = 800;
	public static var height:Int = 600;
	
	public static var drawZone:Sprite = new Sprite();
	
	static var styleDefault:TextFormat = new TextFormat('Courier New',18, 0);
	static var styleConst:TextFormat = new TextFormat(18, 0x0000AA);
	static var styleKeyword:TextFormat = new TextFormat(18, 0x0000FF);
	static var styleError:TextFormat = new TextFormat(18, 0xFF0000);
	
	static var update:Float->Void;
	
	static var input:TextField = new TextField();
	static var output:TextField = new TextField();
	static var error:TextField = new TextField();
	
	static var parser = new Parser();
	static var interp = new Interp();
  
	static function main()
	{
		var stage = Lib.current.stage;
		stage.scaleMode = StageScaleMode.SHOW_ALL;
		stage.align = StageAlign.TOP;
		
		DeltaTime.init(stage.buildSignal(Event.ENTER_FRAME));
		DeltaTime.update.add(_update);
		
		
		input.width = stage.stageWidth / 2;
		input.height = stage.stageHeight * 0.8;
		input.x = input.y = 0;
		
		output.width = stage.stageWidth / 2;
		output.height = stage.stageHeight * 0.8;
		output.x = stage.stageWidth / 2;
		output.y = 0;
		output.wordWrap = true;
		error.width = stage.stageWidth;
		error.height = stage.stageHeight * 0.2;
		error.x = 0;
		error.y = stage.stageHeight * 0.8;
		output.wordWrap = true;
		
		Lib.current.addChild(input);
		Lib.current.addChild(output);
		Lib.current.addChild(error);
		
		error.border = output.border = input.border = true;
		error.borderColor = output.borderColor = input.borderColor = 0xDDDDDD;
		error.defaultTextFormat = output.defaultTextFormat = input.defaultTextFormat = styleDefault;
		//input.background = true;
		//input.backgroundColor = 0x999999;
		input.type = TextFieldType.INPUT;
		input.multiline = true;
		stage.focus = input;
		
		drawZone.x = width / 2;
		drawZone.y = height / 2;
		drawZone.alpha = 0.5;
		Lib.current.addChild(drawZone);
		
		parser.allowTypes = true;
		interp.variables.set('createCircle', Circle.create);
		interp.variables.set('update', regUpdate);
		interp.variables.set('print', print);
		interp.variables.set('screen', out);
		interp.variables.set('fixed', FloatTools.toFixed);

		
		input.addEventListener(Event.CHANGE, change);
		stage.addEventListener(KeyboardEvent.KEY_DOWN, kd);
		
		stage.tabChildren = false;
	}
	
	static function kd(event:KeyboardEvent) {
		if (event.keyCode == Keyboard.TAB) {
			input.text = input.text.substr(0, input.caretIndex) + "\t" + input.text.substr(input.caretIndex);
			input.setSelection(input.caretIndex+1, input.caretIndex+1);
		}
	}
	
	static function change(_) {
		error.text = '';
		if (input.text == '') {
			reload();
			return;
		}
		input.setTextFormat(styleDefault, 0, input.length);
		try {
			var program:Expr = parser.parseString(StringTools.trim(StringTools.replace(input.text, '\r', '\n')));
			reload();
			try {
				error.text = interp.execute(program);
			} catch (e:ErrorDef) {
				error.text = Std.string(e);
			} catch (e:Dynamic) {
				//error.text = Std.string(e);
			}
			try {
				colorize(input, program);
			} catch(_:Dynamic) {}
		} catch (e:Error) {
			error.text = parser.line + ': ' + Std.string(e.e);
			try {
				if (e.pmax >= input.text.length)
					input.setTextFormat(styleError, e.pmin-1, e.pmax);
				else 
					input.setTextFormat(styleError, e.pmin, e.pmax + 1);
			} catch (_:Dynamic) {}
		}
		
		input.defaultTextFormat = styleDefault;
	}
	
	static function colorize(tf:TextField, expr:Expr) {
		switch (expr.e) {
			case EBlock(a) | EArrayDecl(a):
				for (e in a) colorize(tf, e);
			case EConst(_):
				tf.setTextFormat(styleConst, expr.pmin, expr.pmax + 1);
			case EVar(_, _, e):
				tf.setTextFormat(styleKeyword, expr.pmin, expr.pmin+3);
				colorize(tf, e);
			case EIf(cond, e1, e2):
				tf.setTextFormat(styleKeyword, expr.pmin, expr.pmin+2);
				colorize(tf, cond);
				colorize(tf, e1);
				if (e2 != null) {
					colorize(tf, e2);
					tf.setTextFormat(styleKeyword, e2.pmin-5, e2.pmin-1);
					
				}
			case EBinop(_, e1, e2) | EArray(e1, e2):
				colorize(tf, e1);
				colorize(tf, e2);
			case EWhile(e1, e2):
				tf.setTextFormat(styleKeyword, expr.pmin, expr.pmin+5);
				colorize(tf, e1);
				colorize(tf, e2);
			case EFor(_, e1, e2):
				tf.setTextFormat(styleKeyword, expr.pmin, expr.pmin+3);
				colorize(tf, e1);
				colorize(tf, e2);
				
			case EParent(e) | EUnop(_,_,e) | EField(e,_):
				colorize(tf, e);
			case ECall(e, params):
				colorize(tf, e);
				for (p in params)
					colorize(tf, p);
			case EBreak:
				tf.setTextFormat(styleKeyword, expr.pmin, expr.pmin + 5);
			case EContinue:
				tf.setTextFormat(styleKeyword, expr.pmin, expr.pmin + 8);
			case EFunction(_,e,_,_):
				tf.setTextFormat(styleKeyword, expr.pmin, expr.pmin + 8);
				colorize(tf, e);
			case EReturn(e):
				tf.setTextFormat(styleKeyword, expr.pmin, expr.pmin + 6);
				if (e != null) colorize(tf, e);
			case ENew(_, params):
				tf.setTextFormat(styleKeyword, expr.pmin, expr.pmin + 3);
				for (p in params)
					colorize(tf, p);
			case ETernary(cond, e1, e2):
				colorize(tf, cond);
				colorize(tf, e1);
				colorize(tf, e2);
			case EThrow(e):
				tf.setTextFormat(styleKeyword, expr.pmin, expr.pmin + 5);
				colorize(tf, e);
			case ETry(e1, _, _, e2):
				tf.setTextFormat(styleKeyword, expr.pmin, expr.pmin + 3);
				colorize(tf, e1);
				colorize(tf, e2);
			case EObject(a):
				for (el in a)
					colorize(tf, el.e);
			case EIdent(_):
		}
	}
	
	
	static function _update(f:Float) {
		if (update == null) return;
		try {
			update(f);
		} catch (e:Dynamic) {
			error.text = Std.string(e);
		}
	}
	
	static function reload() {
		output.text = '';
		update = null;
		if (Circle.obj != null) Circle.obj.__hide();
	}
	
	static function regUpdate(f:Float->Void) {
		update = f;
	}
	
	static function print(s:String) {
		output.appendText(s+'\n');
	}
	
	static function out(s:String) {
		output.text = s;
	}
	
}

class Circle {
	
	public static var obj:Circle;
	
	public static function create(x:Float, y:Float, r:Float) {
		if (obj == null)
			return obj = new Circle(x, y, r);
		else
			return obj.__update(x, y, r);
	}
	
	public var x(get, set):Float;
	public var y(get, set):Float;
	public var r(get, set):Float;
	var _x:Float;
	var _y:Float;
	var _r:Float;
	var sx:Float;
	var sy:Float;
	var sr:Float;
	var sprite:Sprite;
	
	function new(x:Float, y:Float, r:Float) {
		sx = _x = x;
		sy = _y = y;
		sr = _r = r;
		sprite = new Sprite();
		sprite.graphics.lineStyle(0, 0);
		sprite.graphics.drawCircle(0, 0, 1);
		sprite.x = x;
		sprite.y = y;
		sprite.width = sprite.height = r * 2;
		Main.drawZone.addChild(sprite);
	}
	
	public function __update(x:Float, y:Float, r:Float):Circle {
		__show();
		if (sx == x && sy == y && sr == r) return this;
		sprite.x = sx = x;
		sprite.y = sy = y;
		sr = r;
		sprite.width = sprite.height = r * 2;
		return this;
	}
	
	function get_x() return _x;
	function set_x(v:Float) return sprite.x = _x = v;
	
	function get_y() return _y;
	function set_y(v:Float) return sprite.y = _y = v;
	
	function get_r() return _r;
	function set_r(v:Float) return sprite.width = sprite.height = _r = v;
	
	public function __hide() {
		sprite.visible = false;
	}
	
	public function __show() {
		sprite.visible = true;
	}
}