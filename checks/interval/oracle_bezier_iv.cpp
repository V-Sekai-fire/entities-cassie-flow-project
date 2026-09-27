#include "iv.hpp"
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <vector>
struct V3 { Iv x,y,z; };
static Iv dot(V3 a, V3 b){ return a.x*b.x + a.y*b.y + a.z*b.z; }
static V3 scale(Iv s, V3 v){ return {s*v.x, s*v.y, s*v.z}; }
static V3 add(V3 a, V3 b){ return {a.x+b.x, a.y+b.y, a.z+b.z}; }
static V3 sub(V3 a, V3 b){ return {a.x-b.x, a.y-b.y, a.z-b.z}; }
int main(int argc,char**argv){
  const char* dir = argv[1];
  auto rd=[&](const char*n,std::vector<uint8_t>&b){ char p[512]; snprintf(p,512,"%s/%s",dir,n); FILE*f=fopen(p,"rb"); fseek(f,0,SEEK_END); long s=ftell(f); fseek(f,0,SEEK_SET); b.resize(s); fread(b.data(),1,s,f); fclose(f); };
  std::vector<uint8_t> pb,ipb,iub; rd("params.bin",pb); rd("in_points.bin",ipb); rd("in_u.bin",iub);
  float ta[3],tb[3]; memcpy(ta,pb.data(),12); memcpy(tb,pb.data()+16,12); uint32_t count=*(uint32_t*)(pb.data()+28);
  auto pt=[&](uint32_t i){ float f[3]; memcpy(f,ipb.data()+i*16,12); return V3{Iv(f[0]),Iv(f[1]),Iv(f[2])}; };
  float* u=(float*)iub.data();
  V3 tanA{Iv(ta[0]),Iv(ta[1]),Iv(ta[2])}, tanB{Iv(tb[0]),Iv(tb[1]),Iv(tb[2])};
  V3 p0=pt(0), p3=pt(count-1);
  Iv c00(0.f),c01(0.f),c11(0.f),x0(0.f),x1(0.f);
  for(uint32_t i=0;i<count;i++){
    Iv ui(u[i]); Iv omu = Iv(1.f)-ui;
    Iv ka = Iv(3.f)*(omu*omu*ui), kb = Iv(3.f)*(ui*ui*omu);
    V3 a1=scale(ka,tanA), a2=scale(kb,tanB);
    c00=c00+dot(a1,a1); c01=c01+dot(a1,a2); c11=c11+dot(a2,a2);
    Iv wA = omu*omu*(Iv(1.f)+Iv(2.f)*ui), wB = ui*ui*(Iv(3.f)-Iv(2.f)*ui);
    V3 baseline=add(scale(wA,p0),scale(wB,p3)); V3 tmp=sub(pt(i),baseline);
    x0=x0+dot(a1,tmp); x1=x1+dot(a2,tmp);
  }
  Iv det=c00*c11 - c01*c01, det_x=c00*x1 - c01*x0, det_y=x0*c11 - x1*c01;
  Iv alpha_a=det_y/det, alpha_b=det_x/det;
  // chord length + epsilon; fallback when det~0 or either alpha below epsilon.
  V3 chord=sub(p3,p0);
  Iv seg_len = iv_sqrt(chord.x*chord.x + chord.y*chord.y + chord.z*chord.z);
  Iv eps = Iv(1.0e-5f)*seg_len;
  // determinate branch for this fixture: |det| not tiny, but alpha_b < eps (negative) -> fallback.
  bool fallback = (det.hi < 1.0e-12f && det.lo > -1.0e-12f) || (alpha_a.hi < eps.lo) || (alpha_b.hi < eps.lo);
  V3 P1{Iv(0.f),Iv(0.f),Iv(0.f)}, P2{Iv(0.f),Iv(0.f),Iv(0.f)};
  if (fallback){ Iv third = seg_len / Iv(3.0f); P1=add(p0,scale(third,tanA)); P2=add(p3,scale(third,tanB)); }
  else { P1=add(p0,scale(alpha_a,tanA)); P2=add(p3,scale(alpha_b,tanB)); }
  printf("alpha_a=[%.6f,%.6f] alpha_b=[%.6f,%.6f] det=[%.4e,%.4e]\n",alpha_a.lo,alpha_a.hi,alpha_b.lo,alpha_b.hi,det.lo,det.hi);
  V3 out[4]={p0,P1,P2,p3};
  float lo[12],hi[12];
  for(int k=0;k<4;k++){ Iv c[3]={out[k].x,out[k].y,out[k].z}; for(int j=0;j<3;j++){ lo[k*3+j]=c[j].lo; hi[k*3+j]=c[j].hi; } }
  char p[512]; FILE*f;
  snprintf(p,512,"%s/lo.bin",dir); f=fopen(p,"wb"); fwrite(lo,4,12,f); fclose(f);
  snprintf(p,512,"%s/hi.bin",dir); f=fopen(p,"wb"); fwrite(hi,4,12,f); fclose(f);
  printf("bezier interval widths (ulp-ish): "); for(int j=0;j<12;j++) printf("%.1e ",(double)hi[j]-lo[j]); printf("\n");
  return 0;
}
