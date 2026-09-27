#include "iv.hpp"
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <vector>
int main(int argc,char**argv){ const char* d=argv[1]; char p[512];
  auto rd=[&](const char*n,std::vector<uint8_t>&b){ snprintf(p,512,"%s/%s",d,n); FILE*f=fopen(p,"rb"); fseek(f,0,SEEK_END); long s=ftell(f); fseek(f,0,SEEK_SET); b.resize(s); fread(b.data(),1,s,f); fclose(f); };
  std::vector<uint8_t> xb,yb,pb; rd("x.bin",xb); rd("y.bin",yb); rd("params.bin",pb);
  uint32_t n=xb.size()/4; float* x=(float*)xb.data(); float* y=(float*)yb.data();
  float alpha=*(float*)(pb.data()+4), beta=*(float*)(pb.data()+8);
  std::vector<float> lo(n),hi(n);
  for(uint32_t i=0;i<n;i++){ Iv r=Iv(alpha)*Iv(x[i])+Iv(beta)*Iv(y[i]); lo[i]=r.lo; hi[i]=r.hi; }
  FILE*f; snprintf(p,512,"%s/lo.bin",d); f=fopen(p,"wb"); fwrite(lo.data(),4,n,f); fclose(f);
  snprintf(p,512,"%s/hi.bin",d); f=fopen(p,"wb"); fwrite(hi.data(),4,n,f); fclose(f);
  printf("saxpby iv n=%u\n",n); return 0; }
