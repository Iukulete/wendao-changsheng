extends SceneTree
const Water = preload("res://scripts/adapters/ark_analytic_water.gd")
const WARMUP = 12
const SAMPLES = 30

func memory() -> Dictionary:
 var result = {"engine_static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)), "rss_kib": null, "high_water_rss_kib": null}
 var status = FileAccess.open("/proc/self/status", FileAccess.READ)
 if status != null:
  for line in status.get_as_text().split("\n"):
   for field in [["VmRSS:","rss_kib"],["VmHWM:","high_water_rss_kib"]]:
    if line.begins_with(field[0]):
     result[field[1]] = int(line.substr(line.find(":")+1).strip_edges().split(" ",false)[0])
 return result

func summarize(values: Array) -> Dictionary:
 var sorted = values.duplicate()
 sorted.sort()
 return {"p50_ms": sorted[14], "p95_ms": sorted[28], "p99_ms": sorted[29], "max_ms": sorted[29], "mean_ms": values.reduce(func(a,b): return a+b,0.0)/float(values.size())}

func make_water(model: int, count: int):
 var water = Water.new()
 if model == 2:
  assert(water.enable_gerstner())
 for i in range(count):
  assert(water.register_float("float_%05d" % i,Vector3((i%64)*1.25-40.0,0.0,(i/64)*1.5-24.0),1.05))
 return water

func compare(a: Dictionary, b: Dictionary) -> Dictionary:
 var dy = 0.0
 var dv = 0.0
 for id in a["floats"]:
  dy=maxf(dy,absf(a["floats"][id]["position"]["y"]-b["floats"][id]["position"]["y"]))
  dv=maxf(dv,absf(a["floats"][id]["velocity_y"]-b["floats"][id]["velocity_y"]))
 return {"max_y_difference":dy,"max_velocity_difference":dv,"time_difference":absf(a["time_seconds"]-b["time_seconds"]),"ok":dy<=0.00001 and dv<=0.000001 and absf(a["time_seconds"]-b["time_seconds"])<=0.00000001}

func _initialize():
 var extension=OS.get_environment("ARK_WATER_EXTENSION")
 var rows=[]
 var all_ok=true
 var test_index=0
 for model in [1,2]:
  for count in [1,2,256,2048]:
   for delta in [1.0/60.0,0.25]:
    # Rotate execution order to avoid always assigning warmed host state to native.
    var modes=["gdscript","native_single","native_multi"]
    var snapshots={}
    var trial_rows=[]
    for index in range(3):
     var mode=modes[(index+test_index)%3]
     var water=make_water(model,count)
     assert(water.configure_backend(mode,extension))
     for warm in range(WARMUP):
      assert(water.advance(delta)["ok"])
     var before=memory()
     var samples=[]
     for sample in range(SAMPLES):
      var begin=Time.get_ticks_usec()
      var outcome=water.advance(delta)
      var elapsed=Time.get_ticks_usec()-begin
      assert(outcome["ok"])
      assert(water.backend==mode)
      samples.append(float(elapsed)/1000.0)
     var after=memory()
     snapshots[mode]=water.snapshot()
     var row={"model":model,"awake_floats":count,"rendered_objects":0,"delta_seconds":delta,"backend":mode,"samples_ms":samples,"summary":summarize(samples),"memory_before":before,"memory_after":after}
     trial_rows.append(row)
     water.shutdown()
     water=null
    for row in trial_rows:
     row["parity_to_gdscript"]=compare(snapshots["gdscript"],snapshots[row["backend"]])
     all_ok=all_ok and row["parity_to_gdscript"]["ok"]
     rows.append(row)
    test_index+=1
 var report={"engine":Engine.get_version_info(),"cpu":OS.get_processor_name(),"os":OS.get_name(),"warmup_per_backend":WARMUP,"samples_per_backend":SAMPLES,"units":"ms full production adapter advance including validation/packing/dispatch/wait/commit","p99_note":"nearest-rank p99 is max for n=30; not tail characterization","memory_note":"RSS/HWM are whole benchmark process cumulative including engine and earlier trials, not isolated per backend allocations","scope":"headless actual numeric float authority; not rendered GPU, whole gameplay frame, NPC scale or Windows evidence","rows":rows,"parity_all_ok":all_ok}
 var output=FileAccess.open(OS.get_environment("ARK_BENCHMARK_JSON"),FileAccess.WRITE)
 assert(output!=null)
 output.store_string(JSON.stringify(report,"\t"))
 output.close()
 print("NATIVE_WRAPPER_BENCHMARK_FINISHED parity=",all_ok," rows=",rows.size())
 quit(0 if all_ok else 1)
