#include "../../../godot-cassie/modules/cassie/src/solver/slang_dispatch/curve_rdp_dispatch.h"
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <vector>
int main(){
  const uint32_t n=10; float pts[30];
  // a near-straight run with two bumps so RDP drops the collinear middles
  float ys[10]={0,0.01f,0.0f,0.9f,0.5f,0.02f,0.0f,0.0f,0.6f,0.0f};
  for(uint32_t i=0;i<n;i++){ pts[i*3+0]=(float)i; pts[i*3+1]=ys[i]; pts[i*3+2]=0.0f; }
  std::vector<uint32_t> keep(n,0);
  float err=0.1f;
  uint32_t kept=cassie_slang_dispatch::curve_rdp_reduce(pts,n,err,keep.data());
  uint8_t p[8]={0}; *(uint32_t*)(p)=n; *(float*)(p+4)=err;
  FILE*f; f=fopen("rd_params.bin","wb"); fwrite(p,1,8,f); fclose(f);
  std::vector<uint8_t> ip(n*16,0); for(uint32_t i=0;i<n;i++) memcpy(&ip[i*16],&pts[i*3],12);
  f=fopen("rd_points.bin","wb"); fwrite(ip.data(),1,ip.size(),f); fclose(f);
  f=fopen("rd_keep_ref.bin","wb"); fwrite(keep.data(),4,n,f); fclose(f);
  f=fopen("rd_count_ref.bin","wb"); fwrite(&kept,4,1,f); fclose(f);
  printf("rdp: kept=%u of %u\n",kept,n); return 0;
}
