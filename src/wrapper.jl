using Cxx
cxx"""

#include <iostream>
#include <boost/filesystem/operations.hpp>

#include "luxrays/core/utils.h"
#include "luxrays/utils/ocl.h"

#include "luxcore/luxcore.h"
using namespace std;
using namespace luxrays;
using namespace luxcore;

"""
try {
		luxcore::Init();

		cout << "LuxCore " << LUXCORE_VERSION_MAJOR << "." << LUXCORE_VERSION_MINOR << "\n" ;

		//----------------------------------------------------------------------
		// Build the scene to render
		//----------------------------------------------------------------------

		Scene *scene = new Scene();

		// Setup the camera
		scene->Parse(
				Property("scene.camera.lookat.orig")(1.f , 6.f , 3.f) <<
				Property("scene.camera.lookat.target")(0.f , 0.f , .5f) <<
				Property("scene.camera.fieldofview")(60.f));

		// Define texture maps
		const u_int size = 500;
		float *img = new float[size * size * 3];
		float *ptr = img;
		for (u_int y = 0; y < size; ++y) {
			for (u_int x = 0; x < size; ++x) {
				if ((x % 50 < 25) ^ (y % 50 < 25)) {
					*ptr++ = 1.f;
					*ptr++ = 0.f;
					*ptr++ = 0.f;
				} else {
					*ptr++ = 1.f;
					*ptr++ = 1.f;
					*ptr++ = 0.f;
				}
			}
		}

		scene->DefineImageMap("check_texmap", img, 1.f, 3, size, size);
		scene->Parse(
			Property("scene.textures.map.type")("imagemap") <<
			Property("scene.textures.map.file")("check_texmap") <<
			Property("scene.textures.map.gamma")(1.f)
			);

		// Setup materials
		scene->Parse(
			Property("scene.materials.whitelight.type")("matte") <<
			Property("scene.materials.whitelight.emission")(1000000.f, 1000000.f, 1000000.f) <<
			Property("scene.materials.mat_white.type")("matte") <<
			Property("scene.materials.mat_white.kd")("map") <<
			Property("scene.materials.mat_red.type")("matte") <<
			Property("scene.materials.mat_red.kd")(0.75f, 0.f, 0.f) <<
			Property("scene.materials.mat_glass.type")("glass") <<
			Property("scene.materials.mat_glass.kr")(0.9f, 0.9f, 0.9f) <<
			Property("scene.materials.mat_glass.kt")(0.9f, 0.9f, 0.9f) <<
			Property("scene.materials.mat_glass.exteriorior")(1.f) <<
			Property("scene.materials.mat_glass.interiorior")(1.4f) <<
			Property("scene.materials.mat_gold.type")("metal2") <<
			Property("scene.materials.mat_gold.preset")("gold")
			);

		// Create the ground
		CreateBox(scene, "ground", "mesh-ground", "mat_white", true, BBox(Point(-3.f,-3.f,-.1f), Point(3.f, 3.f, 0.f)));
		// Create the red box
		CreateBox(scene, "box01", "mesh-box01", "mat_red", false, BBox(Point(-.5f,-.5f, .2f), Point(.5f, .5f, 0.7f)));
		// Create the glass box
		CreateBox(scene, "box02", "mesh-box02", "mat_glass", false, BBox(Point(1.5f, 1.5f, .3f), Point(2.f, 1.75f, 1.5f)));
		// Create the light
		CreateBox(scene, "box03", "mesh-box03", "whitelight", false, BBox(Point(-1.75f, 1.5f, .75f), Point(-1.5f, 1.75f, .5f)));
		//Create a monkey from ply-file
		Properties props;
		props.SetFromString(
			"scene.objects.monkey.ply = samples/luxcorescenedemo/suzanne.ply\n"	// load the ply-file
			"scene.objects.monkey.material = mat_gold\n"		// set material
			"scene.objects.monkey.transformation = \
						0.4 0.0 0.0 0.0 \
						0.0 0.4 0.0 0.0 \
						0.0 0.0 0.4 0.0 \
					    0.0 2.0 0.3 1.0\n"						//scale and translate
			);
		scene->Parse(props);

		// Create a SkyLight & SunLight
		scene->Parse(
				Property("scene.lights.skyl.type")("sky") <<
				Property("scene.lights.skyl.dir")(0.166974f, 0.59908f, 0.783085f) <<
				Property("scene.lights.skyl.turbidity")(2.2f) <<
				Property("scene.lights.skyl.gain")(0.8f, 0.8f, 0.8f) <<
				Property("scene.lights.sunl.type")("sun") <<
				Property("scene.lights.sunl.dir")(0.166974f, 0.59908f, 0.783085f) <<
				Property("scene.lights.sunl.turbidity")(2.2f) <<
				Property("scene.lights.sunl.gain")(0.8f, 0.8f, 0.8f)
				);

		//----------------------------------------------------------------------
		// Do the render
		//----------------------------------------------------------------------

		RenderConfig *config = new RenderConfig(
				Property("renderengine.type")("PATHCPU") <<
				Property("sampler.type")("RANDOM") <<
				Property("opencl.platform.index")(-1) <<
				Property("opencl.cpu.use")(false) <<
				Property("opencl.gpu.use")(true) <<
				Property("batch.halttime")(10) <<
				Property("film.outputs.1.type")("RGB_TONEMAPPED") <<
				Property("film.outputs.1.filename")("image.png"),
				scene);
		RenderSession *session = new RenderSession(config);

		//----------------------------------------------------------------------
		// Start the rendering
		//----------------------------------------------------------------------

		session->Start();

		DoRendering(session);
		boost::filesystem::rename("image.png", "image0.png");

		//----------------------------------------------------------------------
		// Edit a texture
		//----------------------------------------------------------------------

		SLG_LOG("Editing a texture...");
		session->BeginSceneEdit();
		scene->Parse(
			Property("scene.textures.map.type")("constfloat3") <<
			Property("scene.textures.map.value")(0.f, 0.f, 1.f));
		session->EndSceneEdit();

		// And redo the rendering
		DoRendering(session);
		boost::filesystem::rename("image.png", "image1.png");

		//----------------------------------------------------------------------
		// Edit a material
		//----------------------------------------------------------------------

		SLG_LOG("Editing a material...");
		session->BeginSceneEdit();
		scene->Parse(
			Property("scene.materials.mat_white.type")("mirror") <<
			Property("scene.materials.mat_white.kr")(.9f, .9f, .9f));
		session->EndSceneEdit();

		// And redo the rendering
		DoRendering(session);
		boost::filesystem::rename("image.png", "image2.png");

		//----------------------------------------------------------------------
		// Edit an object
		//----------------------------------------------------------------------

		SLG_LOG("Editing a material and an object...");
		session->BeginSceneEdit();
		
		scene->Parse(
			Property("scene.materials.mat_white.type")("matte") <<
			Property("scene.materials.mat_white.kr")(.7f, .7f, .7f));
		CreateBox(scene, "box03", "mesh-box03", "mat_red", false, BBox(Point(-2.75f, 1.5f, .75f), Point(-.5f, 1.75f, .5f)));

		// Rotate the monkey: so he can look what is happen with the light source
		// Set the initial values
		Vector t(0.0f, 2.0f, 0.3f);
		Transform trans(Translate(t));
		Transform scale(Scale(0.4f, 0.4f, 0.4f));
		// Set rotate = 90
		Transform rotate(RotateZ(90));
		// Put all together and update object
		trans = trans * scale * rotate;
		scene->UpdateObjectTransformation("monkey", trans);

		session->EndSceneEdit();

		// And redo the rendering
		DoRendering(session);
		boost::filesystem::rename("image.png", "image3.png");

		//----------------------------------------------------------------------

		// Stop the rendering
		session->Stop();

		delete session;
		delete config;
		delete scene;

		SLG_LOG("Done.");

	} catch (cl::Error err) {
		SLG_LOG("OpenCL ERROR: " << err.what() << "(" << oclErrorString(err.err()) << ")");
		return EXIT_FAILURE;
	} catch (runtime_error err) {
		SLG_LOG("RUNTIME ERROR: " << err.what());
		return EXIT_FAILURE;
	} catch (exception err) {
		SLG_LOG("ERROR: " << err.what());
		return EXIT_FAILURE;
	}

	return EXIT_SUCCESS;
}

