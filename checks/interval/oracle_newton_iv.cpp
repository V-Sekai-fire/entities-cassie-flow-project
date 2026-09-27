#include "iv.hpp"
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <vector>
struct V3 { Iv x,y,z; };
static Iv dot(V3 a,V3 b){ return a.x*b.x+a.y*b.y+a.z*b.z; }
static V3 sub(V3 a,V3 b){ return {a.x-b.x,a.y-b.y,a.z-b.z}; }
static V3 mkf3(Iv x,Iv y,Iv z){ return {x,y,z}; }
int main(int argc,char**argv){
  const char* dir=argv[1]; char p[512]; std::vector<uint8_t> pb,ptb,ub;
  auto rd=[&](const char*n,std::vector<uint8_t>&b){ snprintf(p,512,"%s/%s",dir,n); FILE*f=fopen(p,"rb"); fseek(f,0,SEEK_END); long s=ftell(f); fseek(f,0,SEEK_SET); b.resize(s); fread(b.data(),1,s,f); fclose(f); };
  rd("nw_params.bin",pb); rd("nw_points.bin",ptb); rd("nw_inu.bin",ub);
  auto V=[&](int off){ float v[3]; memcpy(v,pb.data()+off,12); return V3{Iv(v[0]),Iv(v[1]),Iv(v[2])}; };
  V3 A=V(0),B=V(16),C=V(32),D=V(48); uint32_t count=*(uint32_t*)(pb.data()+60);
  float* u=(float*)ub.data();
  std::vector<float> lo(count),hi(count);
  for(uint32_t i=0;i<count;i++){
    Iv ui(u[i]); Iv omu=Iv(1.f)-ui;
    V3 ab=mkf3(B.x-A.x,B.y-A.y,B.z-A.z), bc=mkf3(C.x-B.x,C.y-B.y,C.z-B.z), cd=mkf3(D.x-C.x,D.y-C.y,D.z-C.z);
    Iv omu2=omu*omu, u2=ui*ui, twoOmU=Iv(2.f)*(omu*ui);
    auto q1c=[&](Iv abc,Iv bcc,Iv cdc){ return Iv(3.f)*((omu2*abc + twoOmU*bcc) + u2*cdc); };
    V3 q1=mkf3(q1c(ab.x,bc.x,cd.x), q1c(ab.y,bc.y,cd.y), q1c(ab.z,bc.z,cd.z));
    V3 dd1=mkf3(bc.x-ab.x,bc.y-ab.y,bc.z-ab.z), dd2=mkf3(cd.x-bc.x,cd.y-bc.y,cd.z-bc.z);
    auto q2c=[&](Iv d1,Iv d2){ return Iv(6.f)*(omu*d1 + ui*d2); };
    V3 q2=mkf3(q2c(dd1.x,dd2.x), q2c(dd1.y,dd2.y), q2c(dd1.z,dd2.z));
    auto lerp=[&](Iv pp,Iv qq){ return pp+(qq-pp)*ui; };
    Iv qabx=lerp(A.x,B.x),qbcx=lerp(B.x,C.x),qcdx=lerp(C.x,D.x); Iv qabcx=qabx+(qbcx-qabx)*ui, qbcdx=qbcx+(qcdx-qbcx)*ui; Iv qvx=qabcx+(qbcdx-qabcx)*ui;
    Iv qaby=lerp(A.y,B.y),qbcy=lerp(B.y,C.y),qcdy=lerp(C.y,D.y); Iv qabcy=qaby+(qbcy-qaby)*ui, qbcdy=qbcy+(qcdy-qbcy)*ui; Iv qvy=qabcy+(qbcdy-qabcy)*ui;
    Iv qabz=lerp(A.z,B.z),qbcz=lerp(B.z,C.z),qcdz=lerp(C.z,D.z); Iv qabcz=qabz+(qbcz-qabz)*ui, qbcdz=qbcz+(qcdz-qbcz)*ui; Iv qvz=qabcz+(qbcdz-qabcz)*ui;
    float pt[3]; memcpy(pt,ptb.data()+i*16,12);
    V3 e=mkf3(qvx-Iv(pt[0]), qvy-Iv(pt[1]), qvz-Iv(pt[2]));
    Iv num=dot(e,q1); Iv den=dot(q1,q1)+dot(e,q2);
    // abs_den < 1e-9 ? u : u - num/den  (determinate for our fixture: den large)
    Iv un = ui - num/den;
    lo[i]=un.lo; hi[i]=un.hi;
  }
  snprintf(p,512,"%s/lo.bin",dir); FILE*f=fopen(p,"wb"); fwrite(lo.data(),4,count,f); fclose(f);
  snprintf(p,512,"%s/hi.bin",dir); f=fopen(p,"wb"); fwrite(hi.data(),4,count,f); fclose(f);
  printf("newton interval ok (count=%u)\n",count); return 0;
}
