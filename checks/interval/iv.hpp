#pragma once
#include <cmath>
#include <algorithm>
// Rigorous float32 interval: [lo,hi] provably contains the real result.
// Each op computes the float32 endpoints then widens 1 ULP outward
// (nextafterf), so a correctly-rounded round-to-nearest evaluation of the
// same expression on ANY conformant device lies inside the interval.
struct Iv {
  float lo, hi;
  Iv(float v):lo(v),hi(v){}
  Iv(float l,float h):lo(l),hi(h){}
};
static inline float dn(float x){ return std::nextafterf(x, -INFINITY); }
static inline float up(float x){ return std::nextafterf(x,  INFINITY); }
static inline Iv operator+(Iv a, Iv b){ return Iv(dn(a.lo+b.lo), up(a.hi+b.hi)); }
static inline Iv operator-(Iv a, Iv b){ return Iv(dn(a.lo-b.hi), up(a.hi-b.lo)); }
static inline Iv operator*(Iv a, Iv b){
  float p[4]={a.lo*b.lo,a.lo*b.hi,a.hi*b.lo,a.hi*b.hi};
  return Iv(dn(*std::min_element(p,p+4)), up(*std::max_element(p,p+4)));
}
static inline Iv operator/(Iv a, Iv b){
  float p[4]={a.lo/b.lo,a.lo/b.hi,a.hi/b.lo,a.hi/b.hi};
  return Iv(dn(*std::min_element(p,p+4)), up(*std::max_element(p,p+4)));
}
static inline Iv iv_sqrt(Iv a){ return Iv(dn(std::sqrt(a.lo)), up(std::sqrt(a.hi))); }
