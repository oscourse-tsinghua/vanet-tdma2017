#include "mbr-neighbor-app.h"

#include "ns3/mbr_sumomap.h"

#include "ns3/log.h"
#include "ns3/boolean.h"
#include "ns3/random-variable-stream.h"
#include "ns3/inet-socket-address.h"
#include "ns3/trace-source-accessor.h"
#include "ns3/udp-socket-factory.h"
#include "ns3/udp-l4-protocol.h"
#include "ns3/udp-header.h"
#include "ns3/wifi-net-device.h"
#include "ns3/adhoc-wifi-mac.h"
#include "ns3/string.h"
#include "ns3/pointer.h"
#include <algorithm>
#include <limits>

using namespace ns3;
using namespace mbr;

NS_LOG_COMPONENT_DEFINE ("MbrNeighborApp");

// (Arbitrary) port for establishing socket to transmit WAVE BSMs
int MbrNeighborApp::wavePort = 9080;

NS_OBJECT_ENSURE_REGISTERED (MbrNeighborApp);

TypeId
MbrNeighborApp::GetTypeId (void)
{
  static TypeId tid = TypeId ("ns3::MbrNeighborApp")
    .SetParent<Application> ()
    .SetGroupName ("Wave")
    .AddConstructor<MbrNeighborApp> ()
    ;
  return tid;
}



MbrNeighborApp::MbrNeighborApp ():
	m_stop(0),
    m_TotalSimTime (Seconds (10)),
    m_wavePacketSize (200),
    m_numWavePackets(1),
    m_waveInterval (MilliSeconds (100)),
    m_gpsAccuracyNs (10000),
    m_beaconInterfaces (0),
    m_dataInterfaces (0),
    m_beaconDevices (0),
    m_dataDevices (0),
    m_nodesMoving (0),
    m_unirv (0),
    m_nodeId (0),
    m_txMaxDelay (MilliSeconds (10)),
    m_prevTxDelay(MilliSeconds (0))

{
  NS_LOG_FUNCTION (this);
  m_neighbors = new Neighbors(MilliSeconds (100));
}

MbrNeighborApp::~MbrNeighborApp ()
{
  NS_LOG_FUNCTION (this);
}

void
MbrNeighborApp::DoDispose (void)
{
  NS_LOG_FUNCTION (this);

  // chain up
  Application::DoDispose ();
}

// Application Methods
void MbrNeighborApp::StartApplication () // Called at time specified by Start
{
  NS_LOG_FUNCTION (this);

  // setup generation of WAVE BSM messages
  Time waveInterPacketInterval = m_waveInterval;

  // BSMs are not transmitted for the first second
  Time startTime = Seconds (1.0);
  // total length of time transmitting WAVE packets
  Time totalTxTime = m_TotalSimTime - startTime;
  // total WAVE packets needing to be sent
  m_numWavePackets = (uint32_t) (totalTxTime.GetDouble () / m_waveInterval.GetDouble ());

  TypeId tid = TypeId::LookupByName ("ns3::UdpSocketFactory");

  // every node broadcasts WAVE BSM to potentially all other nodes
  Ptr<Socket> recvSink = Socket::CreateSocket (GetNode (m_nodeId), tid);
  recvSink->SetRecvCallback (MakeCallback (&MbrNeighborApp::ReceiveWavePacket, this));

  std::pair<Ptr<Ipv4>, uint32_t> interface = m_beaconInterfaces->Get (m_nodeId);
  Ptr<Ipv4> pp = interface.first;
  //first interface id indicate loop (127.0.0.1)
  Ipv4InterfaceAddress iface = pp->GetAddress(interface.second, 0);

  InetSocketAddress local = InetSocketAddress ( iface.GetLocal(), wavePort);//InetSocketAddress (Ipv4Address::GetAny (), wavePort);
  recvSink->Bind (local);
  recvSink->BindToNetDevice (GetNetDevice (m_nodeId));
  recvSink->SetAllowBroadcast (true);

  // dest is broadcast address
  InetSocketAddress remote = InetSocketAddress (Ipv4Address ("255.255.255.255"), wavePort);
  recvSink->Connect (remote);

  // Transmission start time for each BSM:
  // We assume that the start transmission time
  // for the first packet will be on a ns-3 time
  // "Second" boundary - e.g., 1.0 s.
  // However, the actual transmit time must reflect
  // additional effects of 1) clock drift and
  // 2) transmit delay requirements.
  // 1) Clock drift - clocks are not perfectly
  // synchronized across all nodes.  In a VANET
  // we assume all nodes sync to GPS time, which
  // itself is assumed  accurate to, say, 40-100 ns.
  // Thus, the start transmission time must be adjusted
  // by some value, t_drift.
  // 2) Transmit delay requirements - The US
  // minimum performance requirements for V2V
  // BSM transmission expect a random delay of
  // +/- 5 ms, to avoid simultanous transmissions
  // by all vehicles congesting the channel.  Thus,
  // we need to adjust the start trasmission time by
  // some value, t_tx_delay.
  // Therefore, the actual transmit time should be:
  // t_start = t_time + t_drift + t_tx_delay
  // t_drift is always added to t_time.
  // t_tx_delay is supposed to be +/- 5ms, but if we
  // allow negative numbers the time could drift to a value
  // BEFORE the interval start time (i.e., at 100 ms
  // boundaries, we do not want to drift into the
  // previous interval, such as at 95 ms.  Instead,
  // we always want to be at the 100 ms interval boundary,
  // plus [0..10] ms tx delay.
  // Thus, the average t_tx_delay will be
  // within the desired range of [0..10] ms of
  // (t_time + t_drift)

  // WAVE devices sync to GPS time
  // and all devices would like to begin broadcasting
  // their safety messages immediately at the start of
  // the CCH interval.  However, if all do so, then
  // significant collisions occur.  Thus, we assume there
  // is some GPS sync accuracy on GPS devices,
  // typically 40-100 ns.
  // Get a uniformly random number for GPS sync accuracy, in ns.
  Time tDrift = NanoSeconds (m_unirv->GetInteger (0, m_gpsAccuracyNs));

  // When transmitting at a default rate of 10 Hz,
  // the subsystem shall transmit every 100 ms +/-
  // a random value between 0 and 5 ms. [MPR-BSMTX-TXTIM-002]
  // Source: CAMP Vehicle Safety Communications 4 Consortium
  // On-board Minimum Performance Requirements
  // for V2V Safety Systems Version 1.0, December 17, 2014
  // max transmit delay (default 10ms)
  // get value for transmit delay, as number of ns
  uint32_t d_ns = static_cast<uint32_t> (m_txMaxDelay.GetInteger ());
  // convert random tx delay to ns-3 time
  // see note above regarding centering tx delay
  // offset by 5ms + a random value.
  Time txDelay = NanoSeconds (m_unirv->GetInteger (0, d_ns));
  m_prevTxDelay = txDelay;

  Time txTime = startTime + tDrift + txDelay;
  // schedule transmission of first packet
  Simulator::ScheduleWithContext (recvSink->GetNode ()->GetId (),
                                  txTime, &MbrNeighborApp::GenerateWaveTraffic, this,
                                  recvSink, m_wavePacketSize, m_numWavePackets, waveInterPacketInterval, m_nodeId);
}

void MbrNeighborApp::StopApplication () // Called at time specified by Stop
{
  NS_LOG_FUNCTION (this);
  m_stop = 1;
}

void
MbrNeighborApp::Setup (Ipv4InterfaceContainer & i,
				  Ipv4InterfaceContainer & iData,
				  NetDeviceContainer & beaconDevices,
				  NetDeviceContainer & dataDevices,
				  int nodeId,
				  Time totalTime,
				  uint32_t wavePacketSize, // bytes
				  Time waveInterval,
				  Time waveExpire,
				  double gpsAccuracyNs,
				  std::vector<int> * nodesMoving,
				  Time txMaxDelay)
{
  NS_LOG_FUNCTION (this);

  m_unirv = CreateObject<UniformRandomVariable> ();

  m_TotalSimTime = totalTime;
  m_wavePacketSize = wavePacketSize;
  m_waveInterval = waveInterval;
  m_waveExpire = waveExpire;
  m_gpsAccuracyNs = gpsAccuracyNs;

  m_nodesMoving = nodesMoving;


  m_beaconInterfaces = &i;
  m_dataInterfaces = &iData;
  m_beaconDevices = &beaconDevices;
  m_dataDevices = &dataDevices;
  m_nodeId = nodeId;
  m_txMaxDelay = txMaxDelay;
}

void
MbrNeighborApp::GenerateWaveTraffic (Ptr<Socket> socket, uint32_t pktSize,
                                     uint32_t pktCount, Time pktInterval,
                                     uint32_t sendingNodeId)
{

	NS_LOG_FUNCTION (this);
	Vector pos;
	Ptr<MobilityModel> MM = socket->GetNode()->GetObject<MobilityModel> ();
	pos.x = MM->GetPosition ().x;
	pos.y = MM->GetPosition ().y;
	double lat,longi;
	MbrSumo *map = MbrSumo::GetInstance();
	//NS_ASSERT(map->isInitialized());
	NS_ASSERT(map->isMapLoaded());
	map->sumoCartesian2GPS(pos.x, pos.y, &longi, &lat);
	uint8_t mac[6];
	//((Mac48Address)(GetNetDevice(sendingNodeId)->GetAddress())).CopyTo(mac);
	/**
	 * Be careful of the Data inf. and Beacon inf.
	 */
	Ptr<NetDevice> s =  GetNetDeviceOfDataInf(sendingNodeId);//GetNetDevice(sendingNodeId);
	//Ptr<Node> a = GetNode(sendingNodeId);
	Address t = s->GetAddress();
	Mac48Address tmac = Mac48Address::ConvertFrom(t);
	tmac.CopyTo(mac);
	std::pair<Ptr<Ipv4>, uint32_t> interface = m_dataInterfaces->Get (sendingNodeId);
	Ptr<Ipv4> pp = interface.first;
	uint32_t interfaceidx = interface.second;
	Ipv4InterfaceAddress ip_origin = pp->GetAddress(interfaceidx, 0);

    MbrHeader helloHeader (/*prefix size=*/ 0, /*hops=*/ 0, /*dst=*/ ip_origin.GetLocal(), /*dst seqno=*/ 0,
                                             /*origin=*/ ip_origin.GetLocal(),/*lifetime=*/ MilliSeconds (0),
							/*geohash*/map->sumoCartesian2Geohash(pos.x, pos.y), mac, /*direction*/0,
							/*latitude*/(float)lat, /*longitude*/(float)longi);
    Ptr<Packet> packet = Create<Packet> ();
    SocketIpTtlTag tag;
    tag.SetTtl (1);
    packet->AddPacketTag (tag);
    packet->AddHeader (helloHeader);

    // send it!
    socket->Send (packet);

	// every BSM must be scheduled with a tx time delay
	// of +/- (5) ms.  See comments in StartApplication().
	// we handle this as a tx delay of [0..10] ms
	// from the start of the pktInterval boundary
	uint32_t d_ns = static_cast<uint32_t> (m_txMaxDelay.GetInteger ());
	Time txDelay = NanoSeconds (m_unirv->GetInteger (0, d_ns));

	// do not want the tx delay to be cumulative, so
	// deduct the previous delay value.  thus we adjust
	// to schedule the next event at the next pktInterval,
	// plus some new [0..10] ms tx delay
	Time txTime = pktInterval - m_prevTxDelay + txDelay;
	m_prevTxDelay = txDelay;

	if (!m_stop)
		Simulator::ScheduleWithContext (socket->GetNode ()->GetId (),
								  txTime, &MbrNeighborApp::GenerateWaveTraffic, this,
								  socket, pktSize, pktCount - 1, pktInterval,  socket->GetNode ()->GetId ());
}

void MbrNeighborApp::ReceiveWavePacket (Ptr<Socket> socket)
{
  NS_LOG_FUNCTION (this << socket);

  Address sourceAddress;
  Ptr<Packet> packet = socket->RecvFrom (sourceAddress);
  //InetSocketAddress inetSourceAddr = InetSocketAddress::ConvertFrom (sourceAddress);
  //Ipv4Address sender = inetSourceAddr.GetIpv4 ();

  MbrHeader mbrHeader;
  packet->RemoveHeader (mbrHeader);


  std::pair<Ptr<Ipv4>, uint32_t> interface = m_dataInterfaces->Get (m_nodeId);
  Ptr<Ipv4> pp = interface.first;
  uint32_t interfaceidx = interface.second;
  Ipv4InterfaceAddress ip_origin = pp->GetAddress(interfaceidx, 0);

  NS_LOG_LOGIC ("MBR Hello recv.. " << ip_origin.GetLocal() << " From " << mbrHeader.GetOrigin ());

  m_neighbors->Update (mbrHeader.GetOrigin (), m_waveExpire,/*Time (MilliSeconds(350)),*/
		  mbrHeader.getMac(), mbrHeader.getGeohash(), mbrHeader.getDirection(),
		  mbrHeader.getLongitude(), mbrHeader.getLatitude());

}

//void MbrNeighbor::HandleReceivedBsmPacket (Ptr<Node> txNode,
//                                              Ptr<Node> rxNode)
//{
//  NS_LOG_FUNCTION (this);
//
//  m_waveBsmStats->IncRxPktCount ();
//
//  Ptr<MobilityModel> rxPosition = rxNode->GetObject<MobilityModel> ();
//  NS_ASSERT (rxPosition != 0);
//  // confirm that the receiving node
//  // has also started moving in the scenario
//  // if it has not started moving, then
//  // it is not a candidate to receive a packet
//  int rxNodeId = rxNode->GetId ();
//  int receiverMoving = m_nodesMoving->at (rxNodeId);
//  if (receiverMoving == 1)
//    {
//      double rxDistSq = MobilityHelper::GetDistanceSquaredBetween (rxNode, txNode);
//      if (rxDistSq > 0.0)
//        {
//          int rangeCount = m_txSafetyRangesSq.size ();
//          for (int index = 1; index <= rangeCount; index++)
//            {
//              if (rxDistSq <= m_txSafetyRangesSq[index - 1])
//                {
//                  m_waveBsmStats->IncRxPktInRangeCount (index);
//                }
//            }
//        }
//    }
//}

//MbrNeighbor **
//MbrNeighbor::PeekMbrNeighborInstance (void)
//{
//  // ensure no topology exists
//  static MbrNeighbor *neighbor = 0;
//  return &neighbor;
//}
//
//MbrNeighbor *
//MbrNeighbor::GetInstance (void)
//{
//	MbrNeighbor **neighbor = PeekMbrNeighborInstance ();
//  /* Please, don't include any calls to logging macros in this function
//   * or pay the price, that is, stack explosions.
//   */
//  if (*neighbor == 0)
//    {
//      // create the topology
//      *neighbor = new MbrNeighbor();
//    }
//
//  return *neighbor;
//}
//
//void
//MbrNeighbor::Initialize()
//{
//
//}


int64_t
MbrNeighborApp::AssignStreams (int64_t streamIndex)
{
  NS_LOG_FUNCTION (this);

  NS_ASSERT (m_unirv);  // should be set by Setup() prevoiusly
  m_unirv->SetStream (streamIndex);

  return 1;
}

Ptr<Node>
MbrNeighborApp::GetNode (int id)
{
  NS_LOG_FUNCTION (this);

  std::pair<Ptr<Ipv4>, uint32_t> interface = m_beaconInterfaces->Get (id);
  Ptr<Ipv4> pp = interface.first;
  Ptr<Node> node = pp->GetObject<Node> ();

  return node;
}

Ptr<NetDevice>
MbrNeighborApp::GetNetDeviceOfDataInf (int id)
{
  NS_LOG_FUNCTION (this);

//  std::pair<Ptr<Ipv4>, uint32_t> interface = m_dataInterfaces->Get (id);
//  Ptr<Ipv4> pp = interface.first;
////  Ptr<NetDevice> device = pp->GetObject<NetDevice> ();
//  Ptr<NetDevice> device = pp->GetNetDevice(1);
//  Ptr<Node> node = pp->GetObject<Node> ();
//  Ptr<NetDevice> device = node->GetDevice(1);
  Ptr<NetDevice> device = m_dataDevices->Get(id);
  return device;
}

Ptr<NetDevice>
MbrNeighborApp::GetNetDevice (int id)
{
  NS_LOG_FUNCTION (this);

//  std::pair<Ptr<Ipv4>, uint32_t> interface = m_beaconInterfaces->Get (id);
//  Ptr<Ipv4> pp = interface.first;
//  Ptr<NetDevice> device = pp->GetNetDevice(1);
//  Ptr<Node> node = pp->GetObject<Node> ();
//  Ptr<NetDevice> device = node->GetDevice(0);

  Ptr<NetDevice> device = m_beaconDevices->Get(id);
  return device;
}


