extends RefCounted
## Fixed initial prototype tradeoffs. No quality/reward multiplier or resource ownership.
const IDS := ["basic","light","resilient"]
const PROFILES := {
	"basic":{"id":"basic","title":"基础竿","bite_window":1.8,"stress_limit":0.45,"reel_scale":1.0,"summary":"手感均衡，原有操作不变。"},
	"light":{"id":"light","title":"轻竿","bite_window":2.2,"stress_limit":0.30,"reel_scale":1.0,"summary":"提竿窗口较宽，但持续绷线更易脱鱼。"},
	"resilient":{"id":"resilient","title":"韧竿","bite_window":1.8,"stress_limit":0.70,"reel_scale":0.85,"summary":"持续绷线容错较长，但收线较慢。"},
}
static func profile(id: String) -> Dictionary:
	return PROFILES[id].duplicate(true) if id in IDS else {}
