extends RefCounted
## Exactly nine original CC0 Poly Haven maps; imported losslessly with mipmaps.
const ASSET_ROOT := "res://art/coast"
const SHADER_PATH := "res://shaders/ark_coast_textured.gdshader"

func build(asset_directory: String = ASSET_ROOT) -> Dictionary:
	var maps: Dictionary = {}
	var errors: Array[String] = []
	for asset in ["sparse_grass", "sand_03", "rock_boulder_dry"]:
		for role in ["diff", "nor_gl", "rough"]:
			var path := asset_directory.path_join(asset).path_join(asset + "_" + role + "_1k.jpg")
			if not ResourceLoader.exists(path, "Texture2D"):
				errors.append("Missing coast map: " + path)
				continue
			var texture := load(path) as Texture2D
			if texture == null or texture.get_size() != Vector2(1024, 1024):
				errors.append("Expected imported 1024x1024 map: " + path)
				continue
			maps[asset + ":" + role] = texture
	if not ResourceLoader.exists(SHADER_PATH, "Shader"):
		errors.append("Missing coast shader: " + SHADER_PATH)
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "materials": {}}
	var shader := load(SHADER_PATH) as Shader
	var terrain := ShaderMaterial.new()
	terrain.shader = shader
	for pair in [["grass","sparse_grass"], ["sand","sand_03"], ["rock","rock_boulder_dry"]]:
		for role in [["diff","diff"], ["normal","nor_gl"], ["rough","rough"]]:
			terrain.set_shader_parameter(pair[0] + "_" + role[0], maps[pair[1] + ":" + role[1]])
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(.73,.75,.72)
	rock.albedo_texture = maps["rock_boulder_dry:diff"]
	rock.normal_enabled = true
	rock.normal_texture = maps["rock_boulder_dry:nor_gl"]
	rock.normal_scale = .38
	rock.roughness_texture = maps["rock_boulder_dry:rough"]
	rock.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	rock.roughness = 1.0
	rock.metallic_specular = .28
	rock.uv1_triplanar = true
	rock.uv1_triplanar_sharpness = 4.0
	rock.uv1_scale = Vector3.ONE / 1.8
	rock.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color("65704b")
	grass.vertex_color_use_as_albedo = true
	grass.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass.roughness = 1.0
	return {"ok": true, "materials": {"terrain": terrain, "rock": rock, "grass": grass}, "source_files": 9, "status": "repo-native coast materials"}
