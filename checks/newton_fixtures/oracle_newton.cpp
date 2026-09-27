#include "../../../godot-cassie/modules/cassie/src/solver/slang_dispatch/curve_newton_dispatch.h"
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <cmath>
#include <vector>
int main(){
  const uint32_t count=6; float a[3]={0,0,0},b[3]={1,2,0},c[3]={2,2,0},d[3]={3,0,0};
  float pts[18],u[6];
  for(uint32_t i=0;i<count;i++){ float t=(float)i/(count-1);
    pts[i*3+0]=t*3.0f+0.05f*sinf(t*6.0f); pts[i*3+1]=2.0f*t*(1-t)*3.0f; pts[i*3+2]=0.0f; u[i]=t; }
  float uo[6];
  cassie_slang_dispatch::curve_newton_reparameterize(a,b,c,d,count,pts,u,uo);
  uint8_t p[64]={0}; memcpy(p,a,12);memcpy(p+16,b,12);memcpy(p+32,c,12);memcpy(p+48,d,12); *(uint32_t*)(p+60)=count;
  FILE*f; f=fopen("nw_params.bin","wb"); fwrite(p,1,64,f); fclose(f);
  std::vector<uint8_t> ip(count*16,0); for(uint32_t i=0;i<count;i++) memcpy(&ip[i*16],&pts[i*3],12);
  f=fopen("nw_points.bin","wb"); fwrite(ip.data(),1,ip.size(),f); fclose(f);
  f=fopen("nw_inu.bin","wb"); fwrite(u,4,count,f); fclose(f);
  f=fopen("nw_ref.bin","wb"); fwrite(uo,4,count,f); fclose(f);
  printf("newton: u0=%g u5=%g\n",uo[0],uo[5]); return 0;
}
