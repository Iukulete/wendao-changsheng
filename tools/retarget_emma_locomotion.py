"""Retarget Quaternius UAL Standard T-pose-relative animations to Emma.
Input: official UAL1_Standard.glb, original user VRM, sampled JSON output.
Only authored bone rotations and pelvis sway are transferred; no actor motion.
"""
import argparse,bisect,json,math,struct
from pathlib import Path

def mul(a,b):
 x,y,z,w=a;X,Y,Z,W=b
 return [w*X+x*W+y*Z-z*Y,w*Y-x*Z+y*W+z*X,w*Z+x*Y-y*X+z*W,w*W-x*X-y*Y-z*Z]
def inv(q):return [-q[0],-q[1],-q[2],q[3]]
def norm(q):
 n=math.sqrt(sum(x*x for x in q));return [x/n for x in q]
def rotate(q,v):return mul(mul(q,[*v,0]),inv(q))[:3]
def slerp(a,b,t):
 dot=sum(x*y for x,y in zip(a,b))
 if dot<0:b=[-x for x in b];dot=-dot
 if dot>0.9995:return norm([x+(y-x)*t for x,y in zip(a,b)])
 angle=math.acos(max(-1,min(1,dot)));den=math.sin(angle)
 return [(math.sin((1-t)*angle)*x+math.sin(t*angle)*y)/den for x,y in zip(a,b)]
def load(path):
 raw=Path(path).read_bytes();n=struct.unpack_from('<I',raw,12)[0]
 return json.loads(raw[20:20+n]),raw[28+n:]
def parents(d):return {c:i for i,n in enumerate(d['nodes']) for c in n.get('children',[])}
def accessor(d,blob,i):
 a=d['accessors'][i];v=d['bufferViews'][a['bufferView']]
 assert a['componentType']==5126
 width={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']];start=v.get('byteOffset',0)+a.get('byteOffset',0)
 stride=v.get('byteStride',width*4)
 return [list(struct.unpack_from('<'+'f'*width,blob,start+j*stride)) for j in range(a['count'])]
def channels(d,blob,clip):
 result={}
 for c in clip['channels']:
  s=clip['samplers'][c['sampler']];assert s.get('interpolation','LINEAR')=='LINEAR'
  result[c['target']['node'],c['target']['path']]=([x[0] for x in accessor(d,blob,s['input'])],accessor(d,blob,s['output']))
 return result
def pose(d,par,ch,time):
 local={}
 for i,n in enumerate(d['nodes']):
  q=n.get('rotation',[0,0,0,1]);p=n.get('translation',[0,0,0]);scale=n.get('scale',[1,1,1])
  for prop in ('rotation','translation','scale'):
   if (i,prop) not in ch:continue
   times,values=ch[i,prop];j=max(0,min(len(times)-2,bisect.bisect_right(times,time)-1))
   t=max(0,min(1,(time-times[j])/max(1e-8,times[min(j+1,len(times)-1)]-times[j])))
   a=values[j];b=values[min(j+1,len(values)-1)]
   value=slerp(a,b,t) if prop=='rotation' else [x+(y-x)*t for x,y in zip(a,b)]
   if prop=='rotation':q=value
   elif prop=='translation':p=value
   else:scale=value
  local[i]=(q,p,scale)
 world={}
 def visit(i):
  if i in world:return world[i]
  q,p,s=local[i]
  if i in par:
   Q,P,S=visit(par[i]);p=[x+y for x,y in zip(P,rotate(Q,[x*y for x,y in zip(p,S)]))];q=mul(Q,q);s=[x*y for x,y in zip(s,S)]
  world[i]=(norm(q),p,s);return world[i]
 for i in local:visit(i)
 return world

def main(source,vrm,out):
 d,blob=load(source);target,_=load(vrm);sp=parents(d);tp=parents(target)
 source_names={n['name']:i for i,n in enumerate(d['nodes'])};anims={a['name']:a for a in d['animations']}
 reference=pose(d,sp,channels(d,blob,anims['A_TPose']),0)
 target_rest=pose(target,tp,{},0)
 human={b['bone']:b['node'] for b in target['extensions']['VRM']['humanoid']['humanBones']}
 mapping={'hips':'pelvis','spine':'spine_01','chest':'spine_02','upperChest':'spine_03','neck':'neck_01','head':'Head'}
 for side,mark in [('left','l'),('right','r')]:
  for a,b in [('UpperLeg','thigh'),('LowerLeg','calf'),('Foot','foot'),('Toes','ball'),('UpperArm','upperarm'),('LowerArm','lowerarm'),('Hand','hand')]:mapping[side+a]=b+'_'+mark
  for finger in ['Thumb','Index','Middle','Ring','Little']:
   for j,section in enumerate(['Proximal','Intermediate','Distal'],1):mapping[side+finger+section]=('pinky' if finger=='Little' else finger.lower())+'_%02d_'%j+mark
 mapping={human[k]:source_names[v] for k,v in mapping.items() if k in human}
 correction=[0,1,0,0] # Source left is +X; VRM0 left is -X; both Y-up.
 root=human['hips'];source_root=source_names['pelvis']
 ratio=target_rest[root][1][1]/reference[source_root][1][1]
 rm_path=Path(source).with_name(Path(source).stem+'_RM.glb')
 rm_d,rm_b=load(rm_path);rm_par=parents(rm_d)
 rm_root=next(i for i,n in enumerate(rm_d['nodes']) if n['name']=='root')
 output={'author':'Quaternius','license':'CC0-1.0','source':'https://quaternius.com/packs/universalanimationlibrary.html','clips':{}}
 for name in ['Idle_Loop','Walk_Loop','Jog_Fwd_Loop','Swim_Idle_Loop','Swim_Fwd_Loop']:
  ch=channels(d,blob,anims[name]);duration=max(max(v[0]) for v in ch.values());frames=max(2,round(duration*60))
  tracks={i:[] for i in mapping};positions=[]
  for f in range(frames+1):
   t=duration*f/frames;world=pose(d,sp,ch,t);desired={}
   for ti,si in mapping.items():
    delta=mul(world[si][0],inv(reference[si][0]));delta=mul(mul(correction,delta),inv(correction))
    desired[ti]=norm(mul(delta,target_rest[ti][0]))
   cache={}
   def global_q(i):
    if i in cache:return cache[i]
    if i in desired:q=desired[i]
    else:q=mul(global_q(tp[i]) if i in tp else [0,0,0,1],target['nodes'][i].get('rotation',[0,0,0,1]))
    cache[i]=q;return q
   for ti in mapping:
    q=norm(mul(inv(global_q(tp[ti])) if ti in tp else [0,0,0,1],desired[ti]));tracks[ti].append(q)
   offset=rotate(correction,[a-b for a,b in zip(world[source_root][1],reference[source_root][1])])
   positions.append([x+y*ratio for x,y in zip(target_rest[root][1],offset)])
  rm_clip=next(a for a in rm_d['animations'] if a['name']==name);rm_ch=channels(rm_d,rm_b,rm_clip)
  rm_start=pose(rm_d,rm_par,rm_ch,0)[rm_root][1];rm_end=pose(rm_d,rm_par,rm_ch,duration)[rm_root][1]
  native_speed=math.dist(rm_start,rm_end)/duration*ratio*1.08
  output['clips'][name]={'reference_speed':native_speed,'duration':duration,'frames':frames,'bones':{target['nodes'][i]['name']:v for i,v in tracks.items()},'root':target['nodes'][root]['name'],'positions':positions}
 Path(out).write_text(json.dumps(output,separators=(',',':')),encoding='utf-8')
 print('Retargeted authored Idle/Walk:',len(mapping),'bones; clips:',[(k,round(v['duration'],3)) for k,v in output['clips'].items()])
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('source');p.add_argument('vrm');p.add_argument('out');a=p.parse_args();main(a.source,a.vrm,a.out)
