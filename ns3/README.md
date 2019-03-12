

## Compile
 1. Copy all files into <NS-3 installation directory>/src: <ns-allinone-3.26>/ns-3.26/src/
 2. ./waf
 
## Test
 1. Copy ./satmac/routing-mbr-compare.cc to <ns-allinone-3.26>/ns-3.26/scratch
 2. ./waf
 3. Use m_tdma_enable to control the switch between TDMA(SATMAC) and CSMA/CA(802.11p). 