# 问题范围
只讨论基础时隙的申请与维护，不讨论一个节点申请多个时隙用作应用数据收发的情况。
# 调研情况
TDMA-VANET要解决的问题是两个：join collision 和 merge collision。在VANET中，由于车辆运动快，merge collision的影响会比较大。根据最新的文献，主流的做法是考虑车辆的运行方向，将一帧分为左右两部分；不同方向的车辆会到不同的部分去申请时隙以避免merge collision。但这个做法一个不好的地方就是不能很好的适应车流不均衡的情况（不同的方向车辆密度差距大），为了解决这个问题，一些工作试图通过引入更多的判断信息来动态规划不同方向车辆可以申请的时隙数量。在这些工作中，时隙分配的基础依然是RR-ALOHA。在其中，每个节点在一帧开头时广播当前帧的时隙占用情况（FI报文）；每个节点收到FI后就能够直接知晓两跳范围内所有节点的时隙占用情况。每个节点需要保证的是自己所选择的时隙在两跳范围内的节点中是独占的。
# 刘瑞霖的方案简述
刘瑞霖的时隙分配方案的思路和上述不同，在他的设计中每个节点在广播FI的基础上广播在每个时隙上，两跳邻居的占用的数量（这个信息是由原FI报文直接累加出来的）。根据增强版的FI报文，节点可以将收到的“两跳节点占用情况Count2hop”（每个时隙占用8位）进行累加，计算出每个时隙的三跳邻居占用数量Count3hop。算法根据Count3hop的值来对每一个时隙进行评价，Count3hop的值越低代表该时隙被隐藏节点所占用的可能性更小。由于存在重复计算，Count3hop的值会比实际情况要偏大，但由于算法只进行相对值的对比，所以偏大的值实际上不会对时隙评价产生影响。有了对每个时隙的评价后，节点会选择评价最优（根据Count3hop）的两跳邻居未占用（根据原始FI）时隙作为自己的基础时隙（BCH）。在选择好基础时隙后，节点可以根据时隙评价的变化情况实时对自己的BCH做出调整，以此来最大程度避免时隙冲突。
# 加入的一些新设计
## 行驶方向的引入
刘瑞霖方案中没有使用到车辆的方向信息，我认为这是不合理的。存在如下的情况：假设有时隙A和时隙B，他们的Count3hop值一致；有两个方向的车辆。假设实际占用时隙A的节点刚好都是由东向西，而占用时隙B的节点都是由西向东。则对于一辆由东向西的车辆来说，申请时隙A明显要比申请时隙B要好（因为方向一致，所以时隙的占用情况更加稳定，时隙碰撞的可能性也会降低）。这个问题是刘瑞霖方案中没有考虑的。
我的基本思路是将车辆方向信息加入两跳节点占用情况Count2hop中，节点可以分别计算一个时隙在两个方向的车辆的Count3hop；并给一个时隙两个评价值分别针对两个方向。具体的做法是，将原Count2hop的8位拆成4+4位分别代表两个方向。要注意的是4位最大表示的数是15，由于这个值是每个时隙都有的，我认为15应该是足够的。
## 算法开销的降低
由于在FI的基础上额外引入了8位的Count2hop，这意味着算法开销的进一步扩大。当一帧为100ms，包含100个时隙时，每个FI包的开销在RR-ALOHA的基础上增加8*100/8 = 100字节。则对于1ms一个的时隙来说，总开销约为23 * 100 / 8 = 287.5字节，开销额外增加53 %。在之前的测试中，以12M的速度发287字节时间需要约300us，则总开销占带宽的30%以上。这是一个很可观的数字。
我的改进思路是将一个帧进一步分为两个小帧，每个节点只能选择其中一个小帧内的时隙进行申请；并且只需要广播当前小帧内所有时隙的占用情况。这样的设计会使算法开销减半。目前还没有想到会不会产生其他的负面效果。

## 多信道的加入
两种方案，一种是只用一个接口，每50ms切换控制信道和服务信道；***在车辆密度较大时以一定概率（密度越大概率越大）禁止车辆切换到服务信道，即将SCHI也拓展成为CCHI
另一种方案是使用两个接口，一个始终对准CCHI。
【从协议上来看这两种方式并没有太大的区别】

# 实验方案
## 实际系统
 1. 固定时隙中的延迟、带宽利用情况（一帧3时隙，3个节点）