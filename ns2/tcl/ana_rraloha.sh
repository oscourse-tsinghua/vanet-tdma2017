echo "ADHOC MAC"                                               
gawk -v node_count=100 -f ~/lpf.awk nsg2_100n_rraloha_1.tr     
gawk -v node_count=150 -f ~/lpf.awk nsg2_150n_rraloha_1.tr     
gawk -v node_count=200 -f ~/lpf.awk nsg2_200n_rraloha_1.tr     
gawk -v node_count=250 -f ~/lpf.awk nsg2_250n_rraloha_1.tr     
gawk -v node_count=300 -f ~/lpf.awk nsg2_300n_rraloha_1.tr     
gawk -v node_count=350 -f ~/lpf.awk nsg2_350n_rraloha_1.tr     
gawk -v node_count=400 -f ~/lpf.awk nsg2_400n_rraloha_1.tr     
echo "AE"                                                      
gawk -v node_count=100 -f ~/lpf.awk nsg2_100n_rraloha_srp_1.tr 
gawk -v node_count=150 -f ~/lpf.awk nsg2_150n_rraloha_srp_1.tr 
gawk -v node_count=200 -f ~/lpf.awk nsg2_200n_rraloha_srp_1.tr 
gawk -v node_count=250 -f ~/lpf.awk nsg2_250n_rraloha_srp_1.tr 
gawk -v node_count=300 -f ~/lpf.awk nsg2_300n_rraloha_srp_1.tr 
gawk -v node_count=350 -f ~/lpf.awk nsg2_350n_rraloha_srp_1.tr 
gawk -v node_count=400 -f ~/lpf.awk nsg2_400n_rraloha_srp_1.tr
