#include "iv.hpp"
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <vector>
struct V3 { Iv x,y,z; };
static V3 lerp(V3 p, V3 q, Iv u){ return { p.x+(q.x-p.x)*u, p.y+(q.y-p.y)*u, p.z+(q.z-p.z)*u }; }
int main(int argc,char**argv){
  const char* dir=argv[1]; char path[512]; std::vector<uint8_t> pb;
  snprintf(path,512,"%s/cj_params.bin",dir); FILE*f=fopen(path,"rb"); fseek(f,0,SEEK_END); long s=ftell(f); fseek(f,0,SEEK_SET); pb.resize(s); fread(pb.data(),1,s,f); fclose(f);
  auto V=[&](int off){ float v[3]; memcpy(v,pb.data()+off,12); return V3{Iv(v[0]),Iv(v[1]),Iv(v[2])}; };
  V3 a=V(0),b=V(16),c=V(32),d=V(48); Iv u(*(float*)(pb.data()+60));
  V3 ab=lerp(a,b,u), bc=lerp(b,c,u), cd=lerp(c,d,u);
  V3 abc=lerp(ab,bc,u), bcd=lerp(bc,cd,u), abcd=lerp(abc,bcd,u);
  V3 out[8]={a,ab,abc,abcd, abcd,bcd,cd,d};
  float lo[24],hi[24];
  for(int k=0;k<8;k++){ Iv cc[3]={out[k].x,out[k].y,out[k].z}; for(int j=0;j<3;j++){lo[k*3+j]=cc[j].lo;hi[k*3+j]=cc[j].hi;} }
  snprintf(path,512,"%s/lo.bin",dir); f=fopen(path,"wb"); fwrite(lo,4,24,f); fclose(f);
  snprintf(path,512,"%s/hi.bin",dir); f=fopen(path,"wb"); fwrite(hi,4,24,f); fclose(f);
  printf("casteljau interval ok\n"); return 0;
}
