echo "ADJ_ALL"
gawk -v node_count=100 -f ~/lpf.awk nsg2_100n_adjall_1.tr 
gawk -v node_count=150 -f ~/lpf.awk nsg2_150n_adjall_1.tr 
gawk -v node_count=200 -f ~/lpf.awk nsg2_200n_adjall_1.tr 
gawk -v node_count=250 -f ~/lpf.awk nsg2_250n_adjall_1.tr 
gawk -v node_count=300 -f ~/lpf.awk nsg2_300n_adjall_1.tr 
gawk -v node_count=350 -f ~/lpf.awk nsg2_350n_adjall_1.tr
gawk -v node_count=400 -f ~/lpf.awk nsg2_400n_adjall_1.tr
