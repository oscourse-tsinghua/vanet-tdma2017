echo "NOADJ"
gawk -v node_count=100 -f ~/lpf.awk nsg2_100n_100s_noadj_noss_1.tr
gawk -v node_count=150 -f ~/lpf.awk nsg2_150n_100s_noadj_noss_1.tr
gawk -v node_count=200 -f ~/lpf.awk nsg2_200n_100s_noadj_noss_1.tr
gawk -v node_count=250 -f ~/lpf.awk nsg2_250n_100s_noadj_noss_1.tr
gawk -v node_count=300 -f ~/lpf.awk nsg2_300n_100s_noadj_noss_1.tr
gawk -v node_count=350 -f ~/lpf.awk nsg2_350n_100s_noadj_noss_1.tr
gawk -v node_count=400 -f ~/lpf.awk nsg2_400n_100s_noadj_noss_1.tr
echo "ADJ-HALF"
gawk -v node_count=100 -f ~/lpf.awk nsg2_100n_100s_adj_1.tr
gawk -v node_count=150 -f ~/lpf.awk nsg2_150n_100s_adj_1.tr
gawk -v node_count=200 -f ~/lpf.awk nsg2_200n_100s_adj_1.tr
gawk -v node_count=250 -f ~/lpf.awk nsg2_250n_100s_adj_1.tr
gawk -v node_count=300 -f ~/lpf.awk nsg2_300n_100s_adj_1.tr
gawk -v node_count=350 -f ~/lpf.awk nsg2_350n_100s_adj_1.tr
gawk -v node_count=400 -f ~/lpf.awk nsg2_400n_100s_adj_1.tr
