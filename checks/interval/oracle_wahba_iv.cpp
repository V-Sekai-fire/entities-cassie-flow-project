#include "iv.hpp"
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <cmath>
#include <vector>
// Interval bounds for the Wahba polar-decomposition kernel's R (RFD 2269).
// R is the polar factor of H = sum_i q_i p_i^T. The enclosure is not the 24
// Newton-Schulz iterations replayed in interval form (that iteration diverges
// under interval widening); it is the exact-arithmetic result bounded by the
// polar-factor perturbation theorem. R_d is computed in double, its backward
// error dH = H - R_d P_d measured, and Higham's bound
//   ||R_true - R_d||_F <= 2 ||dH||_F / sigma_min(H)
// with 1/sigma_min(H) = sqrt(||M^{-1}||_2) <= sqrt(||M^{-1}||_F) gives a proven
// scalar delta widening every entry. The double residual ||X M X - I|| is a
// checked precondition: too large is a FAIL, never a skip (rule 3).
typedef double D;
static void mm(const D a[9],const D b[9],D o[9]){ for(int i=0;i<3;i++)for(int j=0;j<3;j++){ D s=0; for(int k=0;k<3;k++) s+=a[i*3+k]*b[k*3+j]; o[i*3+j]=s; } }
static void mtm(const D a[9],const D b[9],D o[9]){ for(int i=0;i<3;i++)for(int j=0;j<3;j++){ D s=0; for(int k=0;k<3;k++) s+=a[k*3+i]*b[k*3+j]; o[i*3+j]=s; } }
static D frob(const D a[9]){ D s=0; for(int k=0;k<9;k++) s+=a[k]*a[k]; return std::sqrt(s); }
int main(int argc,char**argv){
  const char* dir=argv[1]; char p[512]; std::vector<uint8_t> pb,qb,parb;
  auto rd=[&](const char*n,std::vector<uint8_t>&b){ snprintf(p,512,"%s/%s",dir,n); FILE*f=fopen(p,"rb"); fseek(f,0,SEEK_END); long s=ftell(f); fseek(f,0,SEEK_SET); b.resize(s); fread(b.data(),1,s,f); fclose(f); };
  rd("in_p.bin",pb); rd("in_q.bin",qb); rd("params.bin",parb);
  uint32_t n=*(uint32_t*)parb.data();
  D H[9]={0,0,0,0,0,0,0,0,0};
  for(uint32_t i=0;i<n;i++){ float pf[3],qf[3]; memcpy(pf,pb.data()+i*16,12); memcpy(qf,qb.data()+i*16,12);
    for(int r=0;r<3;r++)for(int c=0;c<3;c++) H[r*3+c]+=(D)qf[r]*(D)pf[c]; }
  D M[9]; mtm(H,H,M);
  D tr=M[0]+M[4]+M[8], s0=1.0/tr;
  D Y[9]={1,0,0,0,1,0,0,0,1}, Z[9]; for(int k=0;k<9;k++) Z[k]=s0*M[k];
  for(int it=0;it<40;it++){ D ZY[9]; mm(Z,Y,ZY); D T[9]; for(int k=0;k<9;k++) T[k]=0.5*((k%4==0?3.0:0.0)-ZY[k]);
    D Yn[9],Zn[9]; mm(Y,T,Yn); mm(T,Z,Zn); memcpy(Y,Yn,72); memcpy(Z,Zn,72); }
  D sq=std::sqrt(s0); D X[9]; for(int k=0;k<9;k++) X[k]=sq*Y[k];   // X = M^{-1/2}
  D XM[9],XMX[9]; mm(X,M,XM); mm(XM,X,XMX);
  D res=0; for(int k=0;k<9;k++){ D e=XMX[k]-(k%4==0?1.0:0.0); if(std::fabs(e)>res) res=std::fabs(e); }
  if(res>1e-9){ printf("FAIL wahba interval: X M X - I residual %.3e too large (degenerate fixture?)\n",res); return 1; }
  D Rd[9]; mm(H,X,Rd);                                            // R = H M^{-1/2}
  D Pd[9]; mtm(Rd,H,Pd);                                          // P = R^T H (symmetric SPD)
  D RP[9]; mm(Rd,Pd,RP); D dH[9]; for(int k=0;k<9;k++) dH[k]=H[k]-RP[k];
  D X2[9]; mm(X,X,X2);                                            // X^2 = M^{-1}
  D delta=2.0*frob(dH)*std::sqrt(frob(X2));                       // proven ||R_true-R_d||_F bound
  std::vector<float> lo(9),hi(9);
  for(int k=0;k<9;k++){ float c=(float)Rd[k]; float d=(float)up(delta);
    lo[k]=dn((float)(c-d)); hi[k]=up((float)(c+d)); }
  snprintf(p,512,"%s/lo.bin",dir); FILE*f=fopen(p,"wb"); fwrite(lo.data(),4,9,f); fclose(f);
  snprintf(p,512,"%s/hi.bin",dir); f=fopen(p,"wb"); fwrite(hi.data(),4,9,f); fclose(f);
  printf("wahba interval ok (n=%u, residual=%.2e, delta=%.2e)\n",n,res,delta); return 0;
}
