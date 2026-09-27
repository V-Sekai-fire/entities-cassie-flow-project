#include <stdio.h>
#include <stdint.h>
#include <math.h>
// Deterministic inputs + the byte-exact CPU oracle for saxpby:
//   dst[i] = fmaf(alpha, x[i], beta * y[i])   (single-rounded fma, float32)
// GPU `fma(alpha,x,beta*y)` is correctly-rounded IEEE fma, so this matches bit-for-bit.
int main(void){
  const uint32_t n = 4096; const float alpha = 1.5f, beta = -0.25f;
  float x[4096], y[4096], dst[4096];
  uint32_t s = 0x12345678u;
  for(uint32_t i=0;i<n;i++){
    s = s*1664525u + 1013904223u; x[i] = ((int32_t)(s>>8))*1.0e-4f;
    s = s*1664525u + 1013904223u; y[i] = ((int32_t)(s>>8))*3.0e-5f;
    dst[i] = fmaf(alpha, x[i], beta*y[i]);
  }
  FILE*f;
  f=fopen("x.bin","wb"); fwrite(x,4,n,f); fclose(f);
  f=fopen("y.bin","wb"); fwrite(y,4,n,f); fclose(f);
  f=fopen("ref_dst.bin","wb"); fwrite(dst,4,n,f); fclose(f);
  // params: uint n; float alpha; float beta; pad to 16 (std140)
  uint8_t p[16]={0}; *(uint32_t*)(p)=n; *(float*)(p+4)=alpha; *(float*)(p+8)=beta;
  f=fopen("params.bin","wb"); fwrite(p,1,16,f); fclose(f);
  printf("gen: n=%u alpha=%g beta=%g\n", n, alpha, beta);
  return 0;
}
