// SPDX-License-Identifier: AGPL-3.0-only
// Public Godot 4.7 C ABI only. Workers never see Godot objects or engine APIs.
#include "gdextension_interface.h"
#include "ark_abi_sizes.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <condition_variable>
#include <cstdint>
#include <limits>
#include <mutex>
#include <thread>
#include <vector>
namespace {
constexpr double TAU = 6.28318530717958647692;
struct alignas(16) Value { unsigned char data[ARK_ABI_STORAGE_BYTES]{}; };
GDExtensionClassLibraryPtr library;
#define DECL(type, name) type name
DECL(GDExtensionInterfaceStringNameNewWithUtf8Chars,sn_new);
DECL(GDExtensionInterfaceStringNewWithUtf8Chars,str_new);
DECL(GDExtensionInterfaceVariantGetPtrDestructor,destroy);
DECL(GDExtensionInterfaceVariantGetPtrConstructor,construct);
DECL(GDExtensionInterfaceGetVariantFromTypeConstructor,from_type);
DECL(GDExtensionInterfaceGetVariantToTypeConstructor,to_type);
DECL(GDExtensionInterfaceVariantGetType,variant_type);
DECL(GDExtensionInterfaceVariantGetPtrBuiltinMethod,builtin);
DECL(GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst,read_index);
DECL(GDExtensionInterfacePackedFloat64ArrayOperatorIndex,write_index);
DECL(GDExtensionInterfaceClassdbConstructObject3,new_object);
DECL(GDExtensionInterfaceObjectSetInstance,set_instance);
DECL(GDExtensionInterfaceClassdbRegisterExtensionClass6,register_class);
DECL(GDExtensionInterfaceClassdbRegisterExtensionClassMethod,register_method);
DECL(GDExtensionInterfaceClassdbUnregisterExtensionClass,unregister_class);
DECL(GDExtensionInterfaceClassdbGetMethodBind,method_bind);
DECL(GDExtensionInterfaceObjectMethodBindPtrcall,ptrcall);
GDExtensionMethodBindPtr notification;
GDExtensionPtrBuiltInMethod array_size,array_resize;
const auto PACKED=GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY;
Value classname,parentname;
bool registered=false;
std::thread::id main_thread;
double wrap(double value,double period) { value=std::fmod(value,period);return value<0.0?value+period:value; }

struct Pool {
    std::mutex mutex;
    std::condition_variable ready,finished;
    std::array<std::thread,2> workers;
    bool stop=false,gerstner=false;
    uint64_t generation=0;
    unsigned pending=0;
    const std::vector<double>* input=nullptr;
    std::vector<double>* output=nullptr;
    static bool height2(const std::vector<double>& a,double x,double z,double pa,double pb,double& height) {
        double qx=x,qz=z;
        auto evaluate=[&](double& rx,double& rz,double& xx,double& xz,double& zz) {
            rx=qx-x;rz=qz-z;xx=1.0;xz=0.0;zz=1.0;height=a[2];
            for(int w=0;w<2;++w) {
                size_t o=3+7*w;
                double dx=a[o],dz=a[o+1],k=a[o+2],amp=a[o+3],q=a[o+4];
                double phase=k*(dx*qx+dz*qz)+(w==0?pa:pb),s=std::sin(phase),c=std::cos(phase);
                double displacement=q*amp*c,derivative=q*amp*k*s;
                rx+=displacement*dx;rz+=displacement*dz;
                xx-=derivative*dx*dx;xz-=derivative*dx*dz;zz-=derivative*dz*dz;
                height+=amp*s;
            }
        };
        double rx,rz,xx,xz,zz;
        for(int iteration=0;iteration<8;++iteration) {
            evaluate(rx,rz,xx,xz,zz);
            if(rx*rx+rz*rz<=1e-18)return std::isfinite(height);
            double det=xx*zz-xz*xz;
            if(!std::isfinite(det)||det<=1e-12)return false;
            qx-=(zz*rx-xz*rz)/det;qz-=(xx*rz-xz*rx)/det;
        }
        evaluate(rx,rz,xx,xz,zz);
        return std::isfinite(height)&&rx*rx+rz*rz<=1e-10;
    }
    static void run(const std::vector<double>& a,std::vector<double>& output,size_t begin,size_t end,bool model2) {
        const size_t prefix=model2?17:3;
        for(size_t i=begin;i<end;++i) {
            size_t o=prefix+5*i;
            double x=a[o],y=a[o+1],z=a[o+2],draft=a[o+3],v=a[o+4];
            double time=a[0],remaining=a[1],pa=model2?a[8]:0.0,pb=model2?a[15]:0.0;
            while(remaining>1e-9) {
                double dt=std::min(1.0/60.0,remaining);time=wrap(time+dt,TAU*100.0);
                double height;
                if(model2) {
                    pa=wrap(pa+a[9]*dt,TAU);pb=wrap(pb+a[16]*dt,TAU);
                    if(!height2(a,x,z,pa,pb,height)) { y=std::numeric_limits<double>::quiet_NaN();break; }
                } else {
                    height=a[2]+.035*std::sin(x*.21+time*.42)*std::cos(z*.16-time*.31)+.018*std::sin((x+z)*.11+time*.23);
                }
                v=std::clamp(v+((height+draft-y)*9.0-v*6.0)*dt,-.35,.35);
                y=static_cast<float>(y+v*dt);remaining-=dt;
            }
            output[2*i]=y;output[2*i+1]=v;
        }
    }
    void start() {
        if(workers[0].joinable())return;
        stop=false;
        try {
            for(unsigned index=0;index<2;++index)workers[index]=std::thread([this,index] {
                uint64_t seen=0;
                std::unique_lock<std::mutex> lock(mutex);
                while(true) {
                    ready.wait(lock,[&]{return stop||generation!=seen;});if(stop)return;
                    seen=generation;const auto* a=input;auto* out=output;bool model=gerstner;
                    size_t n=out->size()/2,begin=n*index/2,end=n*(index+1)/2;
                    lock.unlock();run(*a,*out,begin,end,model);lock.lock();
                    if(--pending==0)finished.notify_one();
                }
            });
        } catch(...) {
            {std::lock_guard<std::mutex> lock(mutex);stop=true;}
            ready.notify_all();for(auto& worker:workers)if(worker.joinable())worker.join();throw;
        }
    }
    void compute(const std::vector<double>& a,std::vector<double>& out,bool parallel,bool model2) {
        if(!parallel||out.empty()){run(a,out,0,out.size()/2,model2);return;}
        start();std::unique_lock<std::mutex> lock(mutex);
        input=&a;output=&out;gerstner=model2;pending=2;++generation;ready.notify_all();
        finished.wait(lock,[&]{return pending==0;});input=nullptr;output=nullptr;
    }
    ~Pool(){ {std::lock_guard<std::mutex> lock(mutex);stop=true;}ready.notify_all();for(auto& worker:workers)if(worker.joinable())worker.join(); }
};
bool valid_packet(const std::vector<double>& a,bool model2) {
    if(a.empty())return false;
    for(double value:a)if(!std::isfinite(value))return false;
    if(a[0]<0.0||a[1]<0.0||a[1]>10.0||std::abs(a[2])>10000.0)return false;
    size_t prefix=model2?17:3;
    for(size_t i=prefix;i<a.size();i+=5)
        if(std::abs(a[i])>1e6||std::abs(a[i+2])>1e6||std::abs(a[i+1])>10000.0||std::abs(a[i+3])>10000.0||std::abs(a[i+4])>.35)return false;
    if(model2) {
        double sum=0;
        for(size_t o:{size_t(3),size_t(10)}) {
            double dx=a[o],dz=a[o+1],k=a[o+2],amp=a[o+3],q=a[o+4],phase=a[o+5],omega=a[o+6];
            if(std::abs(dx*dx+dz*dz-1.0)>1e-6||k<=0||k>2||amp<0||amp>.25||q<0||q>10||phase<0||phase>=TAU||std::abs(omega)>5)return false;
            sum+=std::abs(q*amp*k);
        }
        if(sum>.5)return false;
    }
    return true;
}
void compute(void* userdata,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt argc,GDExtensionVariantPtr result,GDExtensionCallError* error) noexcept {
    if(std::this_thread::get_id()!=main_thread){error->error=GDEXTENSION_CALL_ERROR_INVALID_METHOD;return;}
    bool model2=userdata!=nullptr;int prefix=model2?17:3;
    Value output;construct(PACKED,0)(&output,nullptr);error->error=GDEXTENSION_CALL_OK;
    try {
        if(argc==2&&instance&&variant_type(args[0])==PACKED&&variant_type(args[1])==GDEXTENSION_VARIANT_TYPE_INT) {
            Value input;to_type(PACKED)(&input,const_cast<void*>(args[0]));
            int64_t count=0,mode=0;array_size(&input,nullptr,&count,0);to_type(GDEXTENSION_VARIANT_TYPE_INT)(&mode,const_cast<void*>(args[1]));
            std::vector<double> copied;
            if(count>=prefix&&count<=prefix+50000&&(count-prefix)%5==0&&(mode==0||mode==1)) {
                auto* first=read_index(&input,0);
                try{copied.assign(first,first+count);}catch(...){destroy(PACKED)(&input);throw;}
            }
            destroy(PACKED)(&input);
            if(valid_packet(copied,model2)) {
                std::vector<double> values((copied.size()-prefix)/5*2);
                static_cast<Pool*>(instance)->compute(copied,values,mode==1,model2);
                for(double v:values)if(!std::isfinite(v))throw 0;
                double time=copied[0],remaining=copied[1],steps=0,pa=model2?copied[8]:0,pb=model2?copied[15]:0;
                while(remaining>1e-9) {
                    double dt=std::min(1.0/60.0,remaining);time=wrap(time+dt,TAU*100.0);++steps;remaining-=dt;
                    if(model2){pa=wrap(pa+copied[9]*dt,TAU);pb=wrap(pb+copied[16]*dt,TAU);}
                }
                int result_prefix=model2?4:2;int64_t n=static_cast<int64_t>(values.size())+result_prefix,status=0;
                const void* resize_args[]={&n};array_resize(&output,resize_args,&status,1);
                if(status==0){auto* dest=write_index(&output,0);dest[0]=time;dest[1]=steps;if(model2){dest[2]=pa;dest[3]=pb;}std::copy(values.begin(),values.end(),dest+result_prefix);}
            }
        }
    } catch(...) {destroy(PACKED)(&output);construct(PACKED,0)(&output,nullptr);}
    from_type(PACKED)(result,&output);destroy(PACKED)(&output);
}
GDExtensionObjectPtr create(void*,GDExtensionBool notify) {
    if(std::this_thread::get_id()!=main_thread)return nullptr;
    try {
        auto* pool=new Pool;auto object=new_object(&parentname);if(!object){delete pool;return nullptr;}
        set_instance(object,&classname,pool);
        if(notify){const int64_t what=0;const GDExtensionBool reversed=false;const void* args[]={&what,&reversed};ptrcall(notification,object,args,nullptr);}
        return object;
    }catch(...){return nullptr;}
}
void release(void*,GDExtensionClassInstancePtr instance){delete static_cast<Pool*>(instance);}
void initialize(void*,GDExtensionInitializationLevel level) {
    if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;
    main_thread=std::this_thread::get_id();sn_new(&classname,"ArkWaterBatch");sn_new(&parentname,"RefCounted");
    Value name,name2,size_name,resize_name,empty_name,empty_string,input_name,mode_name,object_name,notify_name;
    sn_new(&name,"compute");sn_new(&name2,"compute_gerstner");sn_new(&size_name,"size");sn_new(&resize_name,"resize");sn_new(&empty_name,"");str_new(&empty_string,"");sn_new(&input_name,"input");sn_new(&mode_name,"mode");sn_new(&object_name,"Object");sn_new(&notify_name,"notification");
    array_size=builtin(PACKED,&size_name,3173160232);array_resize=builtin(PACKED,&resize_name,848867239);notification=method_bind(&object_name,&notify_name,4023243586);
    if(array_size&&array_resize&&notification) {
        GDExtensionClassCreationInfo6 info{};info.is_exposed=true;info.create_instance_func=create;info.free_instance_func=release;
        register_class(library,&classname,&parentname,&info);registered=true;
        GDExtensionPropertyInfo ret{PACKED,&empty_name,&empty_name,0,&empty_string,6};
        GDExtensionPropertyInfo arguments[]={{PACKED,&input_name,&empty_name,0,&empty_string,6},{GDEXTENSION_VARIANT_TYPE_INT,&mode_name,&empty_name,0,&empty_string,6}};
        GDExtensionClassMethodArgumentMetadata metadata[]={GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT64};
        GDExtensionClassMethodInfo method{};method.name=&name;method.call_func=compute;method.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;method.has_return_value=true;method.return_value_info=&ret;method.argument_count=2;method.arguments_info=arguments;method.arguments_metadata=metadata;
        register_method(library,&classname,&method);method.name=&name2;method.method_userdata=&registered;register_method(library,&classname,&method);
    }
    for(Value* v:{&name,&name2,&size_name,&resize_name,&empty_name,&input_name,&mode_name,&object_name,&notify_name})destroy(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(v);
    destroy(GDEXTENSION_VARIANT_TYPE_STRING)(&empty_string);
}
void deinitialize(void*,GDExtensionInitializationLevel level){if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;if(registered)unregister_class(library,&classname);registered=false;destroy(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(&classname);destroy(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(&parentname);}
}
#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif
extern "C" EXPORT GDExtensionBool ark_water_library_init(GDExtensionInterfaceGetProcAddress proc,GDExtensionClassLibraryPtr lib,GDExtensionInitialization* init) {
    library=lib;
#define LOAD(name,type,symbol) name=reinterpret_cast<type>(proc(symbol));if(!name)return false
    LOAD(sn_new,GDExtensionInterfaceStringNameNewWithUtf8Chars,"string_name_new_with_utf8_chars");
    LOAD(str_new,GDExtensionInterfaceStringNewWithUtf8Chars,"string_new_with_utf8_chars");
    LOAD(destroy,GDExtensionInterfaceVariantGetPtrDestructor,"variant_get_ptr_destructor");
    LOAD(construct,GDExtensionInterfaceVariantGetPtrConstructor,"variant_get_ptr_constructor");
    LOAD(from_type,GDExtensionInterfaceGetVariantFromTypeConstructor,"get_variant_from_type_constructor");
    LOAD(to_type,GDExtensionInterfaceGetVariantToTypeConstructor,"get_variant_to_type_constructor");
    LOAD(variant_type,GDExtensionInterfaceVariantGetType,"variant_get_type");
    LOAD(builtin,GDExtensionInterfaceVariantGetPtrBuiltinMethod,"variant_get_ptr_builtin_method");
    LOAD(read_index,GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst,"packed_float64_array_operator_index_const");
    LOAD(write_index,GDExtensionInterfacePackedFloat64ArrayOperatorIndex,"packed_float64_array_operator_index");
    LOAD(new_object,GDExtensionInterfaceClassdbConstructObject3,"classdb_construct_object3");
    LOAD(set_instance,GDExtensionInterfaceObjectSetInstance,"object_set_instance");
    LOAD(register_class,GDExtensionInterfaceClassdbRegisterExtensionClass6,"classdb_register_extension_class6");
    LOAD(register_method,GDExtensionInterfaceClassdbRegisterExtensionClassMethod,"classdb_register_extension_class_method");
    LOAD(unregister_class,GDExtensionInterfaceClassdbUnregisterExtensionClass,"classdb_unregister_extension_class");
    LOAD(method_bind,GDExtensionInterfaceClassdbGetMethodBind,"classdb_get_method_bind");
    LOAD(ptrcall,GDExtensionInterfaceObjectMethodBindPtrcall,"object_method_bind_ptrcall");
    for(auto type:{PACKED,GDEXTENSION_VARIANT_TYPE_STRING,GDEXTENSION_VARIANT_TYPE_STRING_NAME})if(!destroy(type))return false;
    if(!construct(PACKED,0)||!from_type(PACKED)||!to_type(PACKED)||!to_type(GDEXTENSION_VARIANT_TYPE_INT))return false;
    init->minimum_initialization_level=GDEXTENSION_INITIALIZATION_SCENE;init->initialize=initialize;init->deinitialize=deinitialize;init->userdata=nullptr;return true;
}
