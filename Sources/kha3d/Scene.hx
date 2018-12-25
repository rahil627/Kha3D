package kha3d;

import kha.Framebuffer;
import kha.System;
import kha.Image;
import kha.math.FastMatrix4;
import kha.graphics4.Graphics;
import kha.graphics4.Usage;
import kha.graphics4.VertexBuffer;
import kha.graphics4.TextureUnit;
import kha.graphics4.ConstantLocation;
import kha.graphics4.CompareMode;
import kha.graphics4.VertexData;
import kha.graphics4.VertexStructure;
import kha.graphics4.PipelineState;
import kha.math.FastVector3;
import kha.Shaders;

class Scene {
	public static var meshes: Array<MeshObject> = [];
	public static var splines: Array<SplineMesh> = [];
	public static var lights: Array<FastVector3> = [];

	public static var instancedStructure: VertexStructure;
	static var instancedVertexBuffer: VertexBuffer;
	static var pipeline: PipelineState;
	static var mvp: ConstantLocation;
	static var mv: ConstantLocation;
	static var texUnit: TextureUnit;

	static var colors: Image;
	static var depth: Image;
	static var normals: Image;
	static var image: Image;

	public static function init() {
		instancedStructure = new VertexStructure();
		instancedStructure.add("meshpos", VertexData.Float3);

		instancedVertexBuffer = new VertexBuffer(meshes.length, instancedStructure, Usage.DynamicUsage, 1);

		pipeline = new PipelineState();
		pipeline.inputLayout = [meshes[0].mesh.structure, instancedStructure];
		pipeline.vertexShader = Shaders.mesh_vert;
		pipeline.fragmentShader = Shaders.mesh_frag;
		pipeline.depthWrite = true;
		pipeline.depthMode = CompareMode.Less;
		pipeline.cullMode = Clockwise;
		pipeline.compile();
		
		mvp = pipeline.getConstantLocation("mvp");
		mv = pipeline.getConstantLocation("mv");
		texUnit = pipeline.getTextureUnit("image");

		colors = depth = Image.createRenderTarget(System.windowWidth(), System.windowHeight(), RGBA32, Depth32Stencil8);
		normals = Image.createRenderTarget(System.windowWidth(), System.windowHeight(), RGBA32, NoDepthAndStencil);
		image = Image.createRenderTarget(System.windowWidth(), System.windowHeight(), RGBA32, NoDepthAndStencil);
	}

	static function setBuffers(g: Graphics): Void {
		g.setIndexBuffer(meshes[0].mesh.indexBuffer);
		g.setVertexBuffers([meshes[0].mesh.vertexBuffer, instancedVertexBuffer]);
	}

	static function draw(g: Graphics, instanceCount: Int): Void {
		g.drawIndexedVerticesInstanced(instanceCount, 0, meshes[0].mesh.indexBuffer.count());
	}

	public static function render(g: Graphics, mvp: FastMatrix4, mv: FastMatrix4, vp: FastMatrix4, image: Image): Void {
		var planes = Culling.perspectiveToPlanes(vp);

		var instanceIndex = 0;
		var b2 = instancedVertexBuffer.lock();
		for (mesh in meshes) {
			if (Culling.aabbInFrustum(planes, mesh.pos, mesh.pos)) {
				b2.set(instanceIndex * 3 + 0, mesh.pos.x);
				b2.set(instanceIndex * 3 + 1, mesh.pos.y);
				b2.set(instanceIndex * 3 + 2, mesh.pos.z);
				++instanceIndex;
			}
		}
		instancedVertexBuffer.unlock();

		g.setPipeline(pipeline);
		g.setMatrix(Scene.mvp, mvp);
		g.setMatrix(Scene.mv, mv);
		g.setTexture(texUnit, image);
		setBuffers(g);
		draw(g, instanceIndex);
	}

	public static function renderGBuffer(mvp: FastMatrix4, mv: FastMatrix4, vp: FastMatrix4, meshImage: Image, splineImage: Image, heightsImage: Image) {
		var g = colors.g4;
		g.begin([normals]);
		g.clear(0xff00ffff, Math.POSITIVE_INFINITY);
		HeightMap.render(g, mvp, mv);
		for (spline in splines) {
			spline.render(g, mvp, mv, splineImage, heightsImage);
		}
		Scene.render(g, mvp, mv, vp, meshImage);
		g.end();
	}

	public static function renderImage(suneye: FastVector3, sunat: FastVector3, mvp: FastMatrix4, inv: FastMatrix4, sunMvp: FastMatrix4) {
		var g = image.g4;
		g.begin();
		g.clear(0);
		var sunDir = suneye.sub(sunat);
		sunDir.normalize();
		Lights.render(g, colors, normals, depth, Shadows.shadowMap, inv, sunMvp, mvp, sunDir);
		g.end();
	}

	public static function renderView(frame: Framebuffer) {
		var g = frame.g4;
		g.begin();
		TextureViewer.render(g, colors, false, -1, -1, 1, 1);
		TextureViewer.render(g, depth, true, -1, 0, 1, 1);
		//TextureViewer.render(g, shadowMap, true, 0, 0, 1, 1);
		TextureViewer.render(g, normals, false, 0, -1, 1, 1);
		TextureViewer.render(g, image, false, 0, 0, 1, 1);
		g.end();
	}
}
