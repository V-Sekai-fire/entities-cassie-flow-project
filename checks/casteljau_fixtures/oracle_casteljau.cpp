#include "../../../godot-cassie/modules/cassie/src/solver/slang_dispatch/curve_casteljau_dispatch.h"
#include <cstdio>
#include <cstdint>
#include <cstring>
int main(){
  float a[3]={0,0,0},b[3]={1,2,0},c[3]={2,2,0},d[3]={3,0,0}; float u=0.375f;
  float o[8][3];
  cassie_slang_dispatch::curve_casteljau(a,b,c,d,u, o[0],o[1],o[2],o[3], o[4],o[5],o[6],o[7]);
  uint8_t p[64]={0}; memcpy(p,a,12); memcpy(p+16,b,12); memcpy(p+32,c,12); memcpy(p+48,d,12); *(float*)(p+60)=u;
  FILE*f; f=fopen("cj_params.bin","wb"); fwrite(p,1,64,f); fclose(f);
  f=fopen("cj_ref.bin","wb"); for(int k=0;k<8;k++) fwrite(o[k],4,3,f); fclose(f);
  printf("casteljau: la=(%g,%g,%g) rd=(%g,%g,%g)\n",o[0][0],o[0][1],o[0][2],o[7][0],o[7][1],o[7][2]);
  return 0;
}
