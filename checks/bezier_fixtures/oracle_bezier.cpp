#include "../../../godot-cassie/modules/cassie/src/solver/slang_dispatch/curve_generate_bezier_dispatch.h"
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <cmath>
#include <vector>
int main(){
  const uint32_t count=8; float pts[24], u[8];
  for(uint32_t i=0;i<count;i++){ float t=(float)i/(count-1);
    pts[i*3+0]=cosf(t*1.2f); pts[i*3+1]=sinf(t*1.2f); pts[i*3+2]=t*0.3f; }
  u[0]=0.f; float acc=0.f;
  for(uint32_t i=1;i<count;i++){ float dx=pts[i*3]-pts[(i-1)*3], dy=pts[i*3+1]-pts[(i-1)*3+1], dz=pts[i*3+2]-pts[(i-1)*3+2];
    acc+=sqrtf(dx*dx+dy*dy+dz*dz); u[i]=acc; }
  for(uint32_t i=0;i<count;i++) u[i]/=acc;
  float ta[3]={-sinf(0.f),cosf(0.f),0.3f}, tb[3]={-sinf(1.2f),cosf(1.2f),0.3f}, ctrl[12]={0};
  cassie_slang_dispatch::curve_generate_bezier(ta,tb,count,pts,u,ctrl);
  uint8_t params[48]={0}; memcpy(params,ta,12); memcpy(params+16,tb,12); *(uint32_t*)(params+28)=count;
  FILE*f;
  f=fopen("params.bin","wb"); fwrite(params,1,48,f); fclose(f);
  std::vector<uint8_t> ip(count*16,0); for(uint32_t i=0;i<count;i++) memcpy(&ip[i*16],&pts[i*3],12);
  f=fopen("in_points.bin","wb"); fwrite(ip.data(),1,ip.size(),f); fclose(f);
  f=fopen("in_u.bin","wb"); fwrite(u,4,count,f); fclose(f);
  f=fopen("ref_ctrl.bin","wb"); fwrite(ctrl,4,12,f); fclose(f);
  printf("bezier oracle: count=%u P0=(%g,%g,%g) P3=(%g,%g,%g)\n",count,ctrl[0],ctrl[1],ctrl[2],ctrl[9],ctrl[10],ctrl[11]);
  return 0;
}
