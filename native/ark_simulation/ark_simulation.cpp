// SPDX-License-Identifier: AGPL-3.0-only
// Godot is an adapter, never an ECS component. No scene/resource/stock ownership.
#include "gdextension_interface.h"
#include "ark_abi_sizes.h"
#include "third_party/flecs/flecs.h"
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <stdexcept>
#include <thread>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace {
constexpr int MAX_JOBS = 10000;
constexpr double DURATION = 3.0, MAX_STEP = 0.1, MAX_COMPLETED = 1000000;
struct WorkState {
    bool enabled = false;
    int phase = 0, part = 0;
    double prepare = 0, repair = 0;
    uint32_t completed = 0;
    int last_part = 0;
};
struct WorkInput { bool eligible = false, transitioned = false; };

bool integer(double n, double min, double max) {
    return std::isfinite(n) && n >= min && n <= max && std::floor(n) == n;
}
bool valid_state(const std::vector<double>& a, size_t offset, WorkState& s) {
    if (a.size() != offset + 7 || !integer(a[offset], 0, 1) ||
        !integer(a[offset+1], 0, 2) || !integer(a[offset+2], 0, 2) ||
        !integer(a[offset+5], 0, MAX_COMPLETED) || !integer(a[offset+6], 0, 2)) return false;
    double prep = a[offset+3], repair = a[offset+4];
    if (!std::isfinite(prep) || !std::isfinite(repair) || prep < 0 || repair < 0 || prep > DURATION || repair > DURATION) return false;
    s = {a[offset] == 1, int(a[offset+1]), int(a[offset+2]), prep, repair, uint32_t(a[offset+5]), int(a[offset+6])};
    if ((s.completed == 0 && s.last_part != 0) || (s.completed > 0 && s.last_part == 0)) return false;
    if (s.phase == 0) return s.part == 0 && prep == 0 && repair == 0;
    if (s.part == 0 || s.completed >= MAX_COMPLETED) return false;
    return s.phase == 1 ? prep < DURATION && repair == 0 : prep == DURATION;
}
void append_state(std::vector<double>& out, const WorkState& s) {
    out.insert(out.end(), {double(s.enabled), double(s.phase), double(s.part), s.prepare, s.repair, double(s.completed), double(s.last_part)});
}
void cancel(WorkState& s) { s.phase = s.part = 0; s.prepare = s.repair = 0; }

class Kernel {
    ecs_world_t* world = nullptr;
    ecs_entity_t state_id = 0, input_id = 0, system = 0;
    // These are stable game IDs, NOT Flecs entity IDs and never persisted as ECS handles.
    std::unordered_map<uint64_t, ecs_entity_t> residents;
    double delta = 0;
    static void step(ecs_iter_t* it) {
        auto* self = static_cast<Kernel*>(it->ctx);
        auto* states = static_cast<WorkState*>(ecs_field_w_size(it, sizeof(WorkState), 0));
        auto* inputs = static_cast<WorkInput*>(ecs_field_w_size(it, sizeof(WorkInput), 1));
        for (int32_t row = 0; row < it->count; ++row) {
            auto& s = states[row]; auto& input = inputs[row];
            input.transitioned = false;
            if (input.eligible && s.enabled && s.phase != 0) {
                if (s.phase == 1) {
                    s.prepare = std::min(DURATION, s.prepare + self->delta);
                    if (s.prepare >= DURATION) { s.phase = 2; input.transitioned = true; }
                } else s.repair = std::min(DURATION, s.repair + self->delta);
            }
            input.eligible = false;
        }
    }
    ecs_entity_t component(size_t size, size_t alignment) {
        ecs_component_desc_t d{}; d.type.size = int32_t(size); d.type.alignment = int32_t(alignment);
        return ecs_component_init(world, &d);
    }
    WorkState* state(ecs_entity_t e) { return static_cast<WorkState*>(ecs_get_mut_id(world, e, state_id)); }
    WorkInput* input(ecs_entity_t e) { return static_cast<WorkInput*>(ecs_get_mut_id(world, e, input_id)); }
    void run_step(double dt) {
        delta = std::min(dt, MAX_STEP);
        // Manual, bounded tick: no wall clock, catch-up, scene access, or hidden workers.
        ecs_run(world, system, 0, nullptr);
    }
public:
    Kernel() {
        world = ecs_init();
        if (!world) throw std::runtime_error("Flecs world unavailable");
        state_id = component(sizeof(WorkState), alignof(WorkState));
        input_id = component(sizeof(WorkInput), alignof(WorkInput));
        ecs_system_desc_t d{}; d.query.terms[0].id = state_id; d.query.terms[1].id = input_id;
        d.callback = step; d.ctx = this; system = ecs_system_init(world, &d);
        if (!state_id || !input_id || !system) { ecs_fini(world); world = nullptr; throw std::runtime_error("Flecs system unavailable"); }
    }
    ~Kernel() { if (world) ecs_fini(world); }
    Kernel(const Kernel&) = delete;
    Kernel& operator=(const Kernel&) = delete;
    std::vector<double> dispatch(const std::vector<double>& a) {
        if (a.size() < 3 || a[0] != 1 || !integer(a[1], 0, 7)) return {};
        int op = int(a[1]);
        if (op == 7) {
            // One ABI crossing for a batch. Validate ALL IDs/gates before mutating.
            if (a.size() < 4 || a[2] != 0 || (a.size()-4)%2 != 0 || a.size() > 4+MAX_JOBS*2 || !std::isfinite(a[3]) || a[3] <= 0) return {};
            std::unordered_set<uint64_t> seen;
            for (size_t i = 4; i < a.size(); i += 2) {
                if (!integer(a[i], 1, 1e9) || !integer(a[i+1], 0, 1)) return {};
                auto id = uint64_t(a[i]);
                if (!residents.count(id) || !seen.insert(id).second) return {};
            }
            std::vector<double> out; out.reserve(3+(a.size()-4)/2*9);
            out.insert(out.end(), {1, 1, double(seen.size())});
            for (size_t i = 4; i < a.size(); i += 2) input(residents.at(uint64_t(a[i])))->eligible = a[i+1] == 1;
            run_step(a[3]);
            for (size_t i = 4; i < a.size(); i += 2) {
                auto e = residents.at(uint64_t(a[i]));
                out.insert(out.end(), {a[i], double(input(e)->transitioned)}); append_state(out, *state(e));
            }
            return out;
        }
        if (!integer(a[2], 1, 1e9)) return {};
        const size_t expected = op == 6 ? 10 : (op == 1 || op == 2 || op == 3) ? 4 : 3;
        if (a.size() != expected) return {};
        auto id = uint64_t(a[2]); auto found = residents.find(id);
        if (found == residents.end()) {
            if (op != 0 || residents.size() >= MAX_JOBS) return {};
            auto e = ecs_new(world); WorkState s{}; WorkInput gate{};
            ecs_set_id(world, e, state_id, sizeof(s), &s); ecs_set_id(world, e, input_id, sizeof(gate), &gate);
            found = residents.emplace(id, e).first;
        }
        auto e = found->second; auto* s = state(e); bool accepted = false, transitioned = false;
        if (op == 0) accepted = true;
        else if (op == 1 && integer(a[3], 0, 1)) { s->enabled = a[3] == 1; accepted = true; }
        else if (op == 2 && integer(a[3], 1, 2) && s->enabled && s->phase == 0 && s->completed < MAX_COMPLETED) {
            s->phase = 1; s->part = int(a[3]); accepted = true;
        } else if (op == 3 && std::isfinite(a[3]) && a[3] > 0 && s->enabled && s->phase != 0) {
            input(e)->eligible = true; run_step(a[3]); transitioned = input(e)->transitioned; accepted = true;
        } else if (op == 4 && s->phase == 2 && s->repair == DURATION) {
            ++s->completed; s->last_part = s->part; cancel(*s); accepted = true;
        } else if (op == 5) { cancel(*s); accepted = true;
        } else if (op == 6) {
            WorkState candidate{}; if (valid_state(a, 3, candidate)) { *s = candidate; accepted = true; }
        }
        std::vector<double> out{1, double(accepted), double(transitioned)}; append_state(out, *s); return out;
    }
};

// Small public-C-ABI binding, following the existing ark_water bridge.
struct alignas(16) Value { unsigned char data[ARK_ABI_STORAGE_BYTES]{}; };
GDExtensionClassLibraryPtr library;
#define DECL(type, name) type name
DECL(GDExtensionInterfaceStringNameNewWithUtf8Chars, sn_new);
DECL(GDExtensionInterfaceStringNewWithUtf8Chars, str_new);
DECL(GDExtensionInterfaceVariantGetPtrDestructor, destroy);
DECL(GDExtensionInterfaceVariantGetPtrConstructor, construct);
DECL(GDExtensionInterfaceGetVariantFromTypeConstructor, from_type);
DECL(GDExtensionInterfaceGetVariantToTypeConstructor, to_type);
DECL(GDExtensionInterfaceVariantGetType, variant_type);
DECL(GDExtensionInterfaceVariantGetPtrBuiltinMethod, builtin);
DECL(GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst, read_index);
DECL(GDExtensionInterfacePackedFloat64ArrayOperatorIndex, write_index);
DECL(GDExtensionInterfaceClassdbConstructObject3, new_object);
DECL(GDExtensionInterfaceObjectSetInstance, set_instance);
DECL(GDExtensionInterfaceClassdbRegisterExtensionClass6, register_class);
DECL(GDExtensionInterfaceClassdbRegisterExtensionClassMethod, register_method);
DECL(GDExtensionInterfaceClassdbUnregisterExtensionClass, unregister_class);
DECL(GDExtensionInterfaceClassdbGetMethodBind, method_bind);
DECL(GDExtensionInterfaceObjectMethodBindPtrcall, ptrcall);
GDExtensionMethodBindPtr notification;
GDExtensionPtrBuiltInMethod array_size, array_resize;
constexpr auto PACKED = GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY;
Value classname, parentname;
bool registered = false;
std::thread::id main_thread;

void dispatch(void*, GDExtensionClassInstancePtr instance, const GDExtensionConstVariantPtr* args, GDExtensionInt argc, GDExtensionVariantPtr result, GDExtensionCallError* error) noexcept {
    if (std::this_thread::get_id() != main_thread) { error->error = GDEXTENSION_CALL_ERROR_INVALID_METHOD; return; }
    Value output; construct(PACKED, 0)(&output, nullptr); error->error = GDEXTENSION_CALL_OK;
    try {
        if (argc == 1 && instance && variant_type(args[0]) == PACKED) {
            Value input; to_type(PACKED)(&input, const_cast<void*>(args[0]));
            int64_t count = 0; array_size(&input, nullptr, &count, 0);
            std::vector<double> copied;
            if (count >= 3 && count <= 4+MAX_JOBS*2) {
                auto* first = read_index(&input, 0);
                try { copied.assign(first, first+count); } catch (...) { destroy(PACKED)(&input); throw; }
            }
            destroy(PACKED)(&input);
            auto values = static_cast<Kernel*>(instance)->dispatch(copied);
            if (!values.empty()) {
                int64_t size = int64_t(values.size()), status = 0; const void* resize_args[]{&size};
                array_resize(&output, resize_args, &status, 1);
                if (status == 0) std::copy(values.begin(), values.end(), write_index(&output, 0));
            }
        }
    } catch (...) { destroy(PACKED)(&output); construct(PACKED, 0)(&output, nullptr); }
    from_type(PACKED)(result, &output); destroy(PACKED)(&output);
}
GDExtensionObjectPtr create(void*, GDExtensionBool notify) {
    if (std::this_thread::get_id() != main_thread) return nullptr;
    try {
        auto* kernel = new Kernel; auto object = new_object(&parentname);
        if (!object) { delete kernel; return nullptr; }
        set_instance(object, &classname, kernel);
        if (notify) { const int64_t what = 0; const GDExtensionBool reversed = false; const void* args[]{&what, &reversed}; ptrcall(notification, object, args, nullptr); }
        return object;
    } catch (...) { return nullptr; }
}
void release(void*, GDExtensionClassInstancePtr instance) { delete static_cast<Kernel*>(instance); }
void initialize(void*, GDExtensionInitializationLevel level) {
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    main_thread = std::this_thread::get_id(); sn_new(&classname, "ArkSimulationKernel"); sn_new(&parentname, "RefCounted");
    Value name, size_name, resize_name, empty_name, empty_string, input_name, object_name, notify_name;
    sn_new(&name, "dispatch"); sn_new(&size_name, "size"); sn_new(&resize_name, "resize"); sn_new(&empty_name, "");
    str_new(&empty_string, ""); sn_new(&input_name, "packet"); sn_new(&object_name, "Object"); sn_new(&notify_name, "notification");
    array_size = builtin(PACKED, &size_name, 3173160232); array_resize = builtin(PACKED, &resize_name, 848867239); notification = method_bind(&object_name, &notify_name, 4023243586);
    if (array_size && array_resize && notification) {
        GDExtensionClassCreationInfo6 info{}; info.is_exposed = true; info.create_instance_func = create; info.free_instance_func = release;
        register_class(library, &classname, &parentname, &info); registered = true;
        GDExtensionPropertyInfo ret{PACKED, &empty_name, &empty_name, 0, &empty_string, 6};
        GDExtensionPropertyInfo argument{PACKED, &input_name, &empty_name, 0, &empty_string, 6};
        GDExtensionClassMethodArgumentMetadata metadata = GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;
        GDExtensionClassMethodInfo method{}; method.name = &name; method.call_func = dispatch;
        method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL; method.has_return_value = true; method.return_value_info = &ret;
        method.argument_count = 1; method.arguments_info = &argument; method.arguments_metadata = &metadata;
        register_method(library, &classname, &method);
    }
    for (Value* v : {&name, &size_name, &resize_name, &empty_name, &input_name, &object_name, &notify_name}) destroy(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(v);
    destroy(GDEXTENSION_VARIANT_TYPE_STRING)(&empty_string);
}
void deinitialize(void*, GDExtensionInitializationLevel level) {
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    if (registered) unregister_class(library, &classname);
    registered = false;
    destroy(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(&classname); destroy(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(&parentname);
}
}
#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif
extern "C" EXPORT GDExtensionBool ark_simulation_library_init(GDExtensionInterfaceGetProcAddress proc, GDExtensionClassLibraryPtr lib, GDExtensionInitialization* init) {
    library = lib;
#define LOAD(name, type, symbol) name = reinterpret_cast<type>(proc(symbol)); if (!name) return false
    LOAD(sn_new, GDExtensionInterfaceStringNameNewWithUtf8Chars, "string_name_new_with_utf8_chars");
    LOAD(str_new, GDExtensionInterfaceStringNewWithUtf8Chars, "string_new_with_utf8_chars");
    LOAD(destroy, GDExtensionInterfaceVariantGetPtrDestructor, "variant_get_ptr_destructor");
    LOAD(construct, GDExtensionInterfaceVariantGetPtrConstructor, "variant_get_ptr_constructor");
    LOAD(from_type, GDExtensionInterfaceGetVariantFromTypeConstructor, "get_variant_from_type_constructor");
    LOAD(to_type, GDExtensionInterfaceGetVariantToTypeConstructor, "get_variant_to_type_constructor");
    LOAD(variant_type, GDExtensionInterfaceVariantGetType, "variant_get_type");
    LOAD(builtin, GDExtensionInterfaceVariantGetPtrBuiltinMethod, "variant_get_ptr_builtin_method");
    LOAD(read_index, GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst, "packed_float64_array_operator_index_const");
    LOAD(write_index, GDExtensionInterfacePackedFloat64ArrayOperatorIndex, "packed_float64_array_operator_index");
    LOAD(new_object, GDExtensionInterfaceClassdbConstructObject3, "classdb_construct_object3");
    LOAD(set_instance, GDExtensionInterfaceObjectSetInstance, "object_set_instance");
    LOAD(register_class, GDExtensionInterfaceClassdbRegisterExtensionClass6, "classdb_register_extension_class6");
    LOAD(register_method, GDExtensionInterfaceClassdbRegisterExtensionClassMethod, "classdb_register_extension_class_method");
    LOAD(unregister_class, GDExtensionInterfaceClassdbUnregisterExtensionClass, "classdb_unregister_extension_class");
    LOAD(method_bind, GDExtensionInterfaceClassdbGetMethodBind, "classdb_get_method_bind");
    LOAD(ptrcall, GDExtensionInterfaceObjectMethodBindPtrcall, "object_method_bind_ptrcall");
    for (auto type : {PACKED, GDEXTENSION_VARIANT_TYPE_STRING, GDEXTENSION_VARIANT_TYPE_STRING_NAME}) if (!destroy(type)) return false;
    if (!construct(PACKED, 0) || !from_type(PACKED) || !to_type(PACKED)) return false;
    init->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE; init->initialize = initialize; init->deinitialize = deinitialize; init->userdata = nullptr;
    return true;
}
