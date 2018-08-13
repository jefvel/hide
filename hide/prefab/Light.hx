package hide.prefab;

@:enum abstract LightKind(String) {
	var Point = "Point";
	var Directional = "Directional";

	inline function new(v) {
		this = v;
	}
}

typedef LightShadows = {
	var mode : h3d.pass.Shadows.RenderMode;
	var size : Int;
	var radius : Float;
	var power : Float;
	var bias : Float;
}

class Light extends Object3D {

	public var kind : LightKind = Point;
	public var color : Int = 0xffffff;
	public var range : Float = 10;
	public var size : Float = 1.0;
	public var power : Float = 1.0;
	public var shadows : LightShadows = getShadowsDefault();

	static function getShadowsDefault() : LightShadows {
		return {
			mode : None,
			size : 256,
			radius : 1,
			power : 30,
			bias : 0.1,
		};
	}

	public function new(?parent) {
		super(parent);
		type = "light";
	}

	override function save() {
		var obj : Dynamic = super.save();
		obj.kind = kind;
		obj.color = color;
		obj.range = range;
		obj.size = size;
		obj.power = power;
		if( shadows.mode != None ) {
			obj.shadows = Reflect.copy(shadows);
			obj.shadows.mode = shadows.mode.getName();
		}
		return obj;
	}

	override function load( obj : Dynamic ) {
		super.load(obj);
		kind = obj.kind;
		color = obj.color;
		range = obj.range;
		size = obj.size;
		power = obj.power;
		if( obj.shadows != null ) {
			var sh : Dynamic = Reflect.copy(obj.shadows);
			sh.mode = h3d.pass.Shadows.RenderMode.createByName(sh.mode);
			shadows = sh;
		} else
			shadows = getShadowsDefault();
	}

	override function applyPos( o : h3d.scene.Object ) {
		super.applyPos(o);
		o.setScale(1.0);
	}

	override function makeInstance(ctx:Context):Context {
		ctx = ctx.clone(this);

		var isPbr = Std.is(h3d.mat.MaterialSetup.current, h3d.mat.PbrMaterialSetup);
		if( !isPbr ) {
			switch( kind ) {
			case Point:
				ctx.local3d = new h3d.scene.PointLight(ctx.local3d);
			case Directional:
				ctx.local3d = new h3d.scene.DirLight(ctx.local3d);
			}
		} else {
			switch( kind ) {
			case Point:
				ctx.local3d = new h3d.scene.pbr.PointLight(ctx.local3d);
			case Directional:
				ctx.local3d = new h3d.scene.pbr.DirLight(ctx.local3d);
			}
		}
		ctx.local3d.name = name;
		updateInstance(ctx);
		loadBaked(ctx);
		return ctx;
	}

	function loadBaked( ctx : Context ) {
		var name = name+".li";
		var bytes = ctx.shared.loadBakedBytes(name);
		if( bytes == null ) return;
		var light = cast(ctx.local3d,h3d.scene.pbr.Light);
		var r = light.shadows.loadStaticData(bytes);
		#if editor
		if(!r) ctx.shared.saveBakedBytes(name,null);
		#end
	}

	override function updateInstance( ctx : Context, ?propName : String ) {
		super.updateInstance(ctx, propName);

		var isPbr = Std.is(h3d.mat.MaterialSetup.current, h3d.mat.PbrMaterialSetup);
		if( !isPbr )
			return; // TODO

		var color = color | 0xff000000;
		var light = cast(ctx.local3d,h3d.scene.pbr.Light);
		light.setScale(1.0);

		switch( kind ) {
		case Point:
			var pl = Std.instance(light, h3d.scene.pbr.PointLight);
			pl.range = range;
			pl.size = size;
		default:
		}
		light.color.setColor(color);
		light.power = power;
		light.shadows.mode = shadows.mode;
		light.shadows.size = shadows.size;
		light.shadows.power = shadows.power;
		light.shadows.bias = shadows.bias * 0.1;
		light.shadows.blur.radius = shadows.radius;

		#if editor

		var debugPoint = ctx.local3d.find(c -> if(c.name == "_debugPoint") c else null);
		var debugDir = ctx.local3d.find(c -> if(c.name == "_debugDir") c else null);
		var mesh : h3d.scene.Mesh = null;
		var sel : h3d.scene.Object;

		if(kind == Point) {
			if(debugDir != null)
				debugDir.remove();

			var sizeSphere : h3d.scene.Sphere = null;
			var rangeSphere : h3d.scene.Sphere = null;
			if(debugPoint == null) {
				debugPoint = new h3d.scene.Object(ctx.local3d);
				debugPoint.name = "_debugPoint";

				mesh = new h3d.scene.Mesh(h3d.prim.Sphere.defaultUnitSphere(), debugPoint);
				mesh.ignoreBounds = true;

				var highlight = new h3d.scene.Object(debugPoint);
				highlight.name = "_highlight";
				highlight.visible = false;
				sizeSphere = new h3d.scene.Sphere(0xffffff, size, true, highlight);
				sizeSphere.ignoreBounds = true;
				sizeSphere.ignoreCollide = true;
				sizeSphere.material.mainPass.setPassName("overlay");

				rangeSphere = new h3d.scene.Sphere(0xffffff, range, true, highlight);
				rangeSphere.ignoreBounds = true;
				rangeSphere.name = "selection";
				rangeSphere.visible = false;
				rangeSphere.ignoreCollide = true;
				rangeSphere.material.mainPass.setPassName("overlay");
			}
			else {
				mesh = cast debugPoint.getChildAt(0);
				sizeSphere = cast debugPoint.getChildAt(1).getChildAt(0);
				rangeSphere = cast debugPoint.getChildAt(1).getChildAt(1);
			}
			debugPoint.setScale(1/range);
			mesh.setScale(hxd.Math.clamp(size, 0.1, 0.5));
			sizeSphere.radius = size;
			rangeSphere.radius = range;
			sel = rangeSphere;
		}
		else {
			if(debugPoint != null)
				debugPoint.remove();

			if(debugDir == null) {
				debugDir = new h3d.scene.Object(ctx.local3d);
				debugDir.name = "_debugDir";

				mesh = new h3d.scene.Mesh(h3d.prim.Sphere.defaultUnitSphere(), debugDir);
				mesh.ignoreBounds = true;
				mesh.scale(0.5);

				var g = new h3d.scene.Graphics(debugDir);
				g.lineStyle(1, 0xffffff);
				g.moveTo(0,0,0);
				g.lineTo(10,0,0);
				g.ignoreBounds = true;
				g.ignoreCollide = true;
				g.visible = false;
				g.material.mainPass.setPassName("overlay");
				sel = g;
			}
			else {
				mesh = cast debugDir.getChildAt(0);
				sel = debugDir.getChildAt(1);
			}

		}

		var mat = mesh.material;
		mat.mainPass.setPassName("overlay");
		mat.color.setColor(color);
		mat.shadows = false;

		var isSelected = sel.visible;
		if( debugPoint != null ) debugPoint.visible = isSelected || ctx.shared.editorDisplay;
		if( debugDir != null ) debugDir.visible = isSelected || ctx.shared.editorDisplay;
		sel.name = "__selection";
		// no "Mixed" in editor (prevent double shadowing)
		if( light.shadows.mode == Mixed ) light.shadows.mode = Static;
		// when selected, force Dynamic mode (realtime preview)
		if( isSelected && shadows.mode != None ) light.shadows.mode = Dynamic;

		#end
	}

	#if editor

	public function saveBaked( ctx : Context ) {
		var name = name+".li";
		var light = cast(ctx.shared.contexts.get(this).local3d,h3d.scene.pbr.Light);
		var data = light.shadows.saveStaticData();
		ctx.shared.saveBakedBytes(name, data);
	}

	override function setSelected( ctx : Context, b : Bool ) {
		var sel = ctx.local3d.getObjectByName("__selection");
		if( sel != null ) sel.visible = b;
		updateInstance(ctx);
	}

	override function edit( ctx : EditContext ) {
		super.edit(ctx);

		var group = new hide.Element('<div class="group" name="Light">
				<dl>
					<dt>Kind</dt><dd>
						<select field="kind">
							<option value="Point">Point</option>
							<option value="Directional">Directional</option>
						</select></dd>
					<dt>Color</dt><dd><input type="color" field="color"/></dd>
					<dt>Power</dt><dd><input type="range" min="0" max="10" field="power"/></dd>
				</dl>
			</div>
		');


		switch( kind ) {
		case Point:
			group.append(hide.comp.PropsEditor.makePropsList([
				{
					name: "size",
					t: PFloat(0, 5),
					def: 0
				},
				{
					name: "range",
					t: PFloat(1, 20),
					def: 10
				},
			]));
		default:
		}

		var props = ctx.properties.add(group,this, function(pname) {
			if( pname == "kind")
				ctx.rebuildPrefab(this);
			else
				ctx.onChange(this, pname);
		});

		var e = ctx.properties.add(new hide.Element('
			<div class="group" name="Shadows">
				<dl>
					<dt>Mode</dt><dd><select field="mode"></select></dd>
					<dt>Size</dt>
					<dd>
						<select field="size" type="number">
							<option value="64">64</option>
							<option value="128">128</option>
							<option value="256">256</option>
							<option value="512">512</option>
							<option value="1024">1024</option>
							<option value="2048">2048</option>
						</select>
					</dd>
					<dt>Blur Radius</dt><dd><input type="range" field="radius" min="0" max="20"/></dd>
					<dt>Power</dt><dd><input type="range" field="power" min="0" max="50"/></dd>
					<dt>Bias</dt><dd><input type="range" field="bias" min="0" max="1"/></dd>
				</dl>
			</div>
		'),shadows,function(pname) {
			ctx.onChange(this,pname);
			if( pname == "mode" ) ctx.rebuildProperties();
		});

		if( shadows.mode == None ) {
			e.find("dd").not(":first").remove();
			e.find("dt").not(":first").remove();
		}

	}

	override function getHideProps() : HideProps {
		return { icon : "sun-o", name : "Light" };
	}
	#end

	static var _ = hxd.prefab.Library.register("light", Light);
}