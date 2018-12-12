/* -*- Mode:C++; c-file-style:"gnu"; indent-tabs-mode:nil; -*- */

#include "ns3/gpsr-module.h"
#include "ns3/core-module.h"
#include "ns3/network-module.h"
#include "ns3/internet-module.h"
#include "ns3/mobility-module.h"
#include "ns3/point-to-point-module.h"
#include "ns3/wifi-module.h"
#include "ns3/v4ping-helper.h"
#include "ns3/udp-echo-server.h"
#include "ns3/udp-echo-client.h"
#include "ns3/udp-echo-helper.h"

#include "ns3/applications-module.h"
#include "ns3/itu-r-1411-los-propagation-loss-model.h"
#include "ns3/ocb-wifi-mac.h"
#include "ns3/wifi-80211p-helper.h"
#include "ns3/wave-mac-helper.h"
#include "ns3/flow-monitor-module.h"
#include "ns3/config-store-module.h"
#include "ns3/integer.h"
//#include "ns3/wave-bsm-helper.h"
#include "ns3/wave-helper.h"
#include "ns3/topology.h"

#include "ns3/mbr-neighbor-helper.h"
#include "ns3/flow-monitor-helper.h"

#include "ns3/aodv-module.h"

#include "ns3/mbr_route.h"

#include "ns3/geoSVR-helper.h"

#include <iostream>
#include <cmath>
#include <stdlib.h>

using namespace ns3;
using namespace mbr;

#define AODV 1
#define GPSR 2
#define GEOSVR 3

NS_LOG_COMPONENT_DEFINE ("gpsr-mbr-test");

void ReceivePacket (Ptr<Socket> socket)
{
  NS_LOG_UNCOND ("Received one packet!");
}

static void GenerateTraffic (Ptr<Socket> socket, uint32_t pktSize,
                             uint32_t pktCount, Time pktInterval )
{
  if (pktCount > 0)
    {
      socket->Send (Create<Packet> (pktSize));
      Simulator::Schedule (pktInterval, &GenerateTraffic,
                                      socket, pktSize,pktCount-1, pktInterval);
    }
  else
    {
      socket->Close ();
    }
}


class GpsrExample
{
public:
  GpsrExample ();
  /// Configure script parameters, \return true on successful configuration
  bool Configure (int argc, char **argv);
  /// Run simulation
  void Run ();
  /// Report results
  void Report (std::ostream & os);

private:
  uint32_t bytesTotal;
  uint32_t packetsReceived;
  ///\name parameters
  //\{
  /// Number of nodes
  uint32_t m_nNodes;

  /// Simulation time, seconds
  double totalTime;
  /// Write per-device PCAP traces if true
  bool pcap;
  //\}
  uint32_t m_lossModel;
  std::string m_lossModelName;
  std::string m_phyMode;
  double m_txp;
  uint32_t m_pktSize;

  std::string m_traceFile;
  bool m_loadBuildings;
  uint32_t m_nSinks;

  uint32_t m_port;
  int m_mobility;
  int m_scenario;

  bool m_mbr;
  std::string m_netFileString;
  std::string m_osmFileString;
  bool m_openRelay;
  int32_t m_routingProtocol;
  std::string m_routingProtocolStr;

  std::string m_flowOutFile;
  std::string m_throughputOutFile;
  std::string m_distanceOutFile;
  std::string m_round;
  std::string m_outputPrefix;

  uint32_t m_relayedPktNum;
  double m_startTime;
  bool m_sub1g;
  bool m_rsu;
  bool m_tdma_enable;
  bool m_dtn_enable;

  NodeContainer m_nodesContainer;
  NetDeviceContainer beaconDevices;
  Ipv4InterfaceContainer beaconInterfaces;
  NetDeviceContainer dataDevices;
  Ipv4InterfaceContainer dataInterfaces;

  MbrNeighborHelper m_MbrNeighborHelper;
  std::map<int, int> m_distanceMap;


private:
  void CreateNodes ();
  void CreateDevices ();
  void InstallInternetStack ();
  void InstallApplications ();
  void SetupScenario();
  void SetupAdhocMobilityNodes();
  void SetupRoutingMessages (NodeContainer & c,
                             Ipv4InterfaceContainer & adhocTxInterfaces);
  Ptr<Socket> SetupRoutingPacketReceive (Ipv4Address addr, Ptr<Node> node);
  void ReceiveRoutingPacket (Ptr<Socket> socket);
  void CheckThroughput ();
  void OutputTrace();
  void OutputNeighbor();
};

void InstallRSU(NodeContainer &c, uint32_t size, Ptr<ListPositionAllocator> positionAlloc)
{
  NodeContainer rsu;
  rsu.Create(size);

  MobilityHelper mobility;
  mobility.SetPositionAllocator(positionAlloc);
  mobility.SetMobilityModel ("ns3::ConstantPositionMobilityModel");

  mobility.Install(rsu);
  c.Add(rsu);

}

int main (int argc, char **argv)
{
  GpsrExample test;
  if (! test.Configure(argc, argv))
    NS_FATAL_ERROR ("Configuration failed. Aborted.");

  test.Run ();
  test.Report (std::cout);
  return 0;
}

//-----------------------------------------------------------------------------
GpsrExample::GpsrExample () :
  bytesTotal(0),
  packetsReceived(0),
  // Number of Nodes
  m_nNodes (100),

  // Simulation time
  totalTime (30),
  // Generate capture files for each node
  pcap (true),
  m_lossModel (3),
  m_lossModelName (""),
  m_phyMode ("OfdmRate12MbpsBW10MHz"),
  m_txp (10),
  m_pktSize (1400),
  m_traceFile(""),
  m_loadBuildings(true),
  m_nSinks(1),
  m_port(9),
  m_mobility(2),
  m_scenario(2),
  m_mbr(false),
  m_netFileString(""),
  m_openRelay(false),
  m_routingProtocol(AODV),
  m_flowOutFile("flowmonitor-output.xml"),
  m_throughputOutFile("throughput-ouput.txt"),
  m_distanceOutFile("distance-ouput.txt"),
  m_relayedPktNum(0),
  m_startTime(0.0),
  m_sub1g(0),
  m_rsu(0),
  m_tdma_enable(0),
  m_dtn_enable(0)
{
}

bool
GpsrExample::Configure (int argc, char **argv)
{
  // Enable GPSR logs by default. Comment this if too noisy
  // LogComponentEnable("GpsrRoutingProtocol", LOG_LEVEL_ALL);

  SeedManager::SetSeed(12345);
  CommandLine cmd;

  cmd.AddValue ("pcap", "Write PCAP traces.", pcap);
  cmd.AddValue ("size", "Number of nodes.", m_nNodes);
  cmd.AddValue ("time", "Simulation time, s.", totalTime);

  cmd.AddValue ("txp", "tx power db", m_txp);
  cmd.AddValue ("phyMode", "Wifi Phy mode for Data channel", m_phyMode);
  cmd.AddValue ("pktsize", "udp packet size", m_pktSize);

  cmd.AddValue ("buildings", "Load building (obstacles)", m_loadBuildings);
  cmd.AddValue ("sinks", "Number of routing sinks", m_nSinks);

  cmd.AddValue ("scen", "scenario", m_scenario);
  cmd.AddValue ("relay", "open relay", m_openRelay);
  cmd.AddValue ("mbrnb", "use MBR Neighbor", m_mbr);

  cmd.AddValue ("routing", "name of routing protocol", m_routingProtocolStr);

  cmd.AddValue ("flowout", "Flowmonitor output file name", m_flowOutFile);
  cmd.AddValue ("throughputout", "Throughput output file name", m_throughputOutFile);

  cmd.AddValue ("round", "round for static scenario", m_round);
  cmd.AddValue ("outpre", "m_outputPrefix", m_outputPrefix);

  cmd.AddValue ("startTime", "Start time.", m_startTime);

  cmd.AddValue ("sub1g", "Open sub1G mode.", m_sub1g);
  cmd.AddValue ("rsu", "Install RSUs", m_rsu);

  cmd.AddValue ("tdma", "enable tdma", m_tdma_enable);
  cmd.AddValue ("dtn", "enable dtn", m_dtn_enable);

  cmd.Parse (argc, argv);

  if (m_routingProtocolStr == "aodv")
    m_routingProtocol = AODV;
  else if (m_routingProtocolStr == "gpsr")
    m_routingProtocol = GPSR;
  else if (m_routingProtocolStr == "geosvr")
    m_routingProtocol = GEOSVR;
  else
    {
      NS_LOG_UNCOND("Routing Protocol ERROR !!!!!!!!!!!");
      return false;
    }

  if (m_openRelay)
    m_mbr = true;

  return true;
}

uint32_t rreqTimeoutCount = 0;
void
IntTrace (uint32_t oldValue, uint32_t newValue)
{
//  std::cout << "Traced " << oldValue << " to " << newValue << std::endl;
  rreqTimeoutCount++;
}
uint32_t gpsrRecPktTrace = 0;
void
GpsrRecPktTrace (Ptr<Packet> p)
{
    gpsrRecPktTrace++;
}
uint32_t gpsrDropPktTrace = 0;
void
GpsrDropPktTrace (Ptr<Packet> p)
{
  gpsrDropPktTrace++;
}

//uint32_t lossPktNum = 0;
//void
//LossPktTrace (Ptr<const Packet> p)
//{
//  uint32_t size = p->GetSize();
//  if (size > 1000)
//    lossPktNum++;
//}

void GpsrExample::OutputNeighbor()
{
  uint32_t nodeid = 317;
  Ptr<mbr::MbrNeighborApp> nbapp;
  Ptr<Node> node = m_nodesContainer.Get(nodeid);
  for (uint32_t j = 0; j < node->GetNApplications (); j++)
	{
	  nbapp = DynamicCast<mbr::MbrNeighborApp> (node->GetApplication(j));
	  if (nbapp)
	    break;
	}
  NS_ASSERT(nbapp);
  Vector pos;
  Ptr<MobilityModel> MM = node->GetObject<MobilityModel> ();
  pos.x = MM->GetPosition ().x;
  pos.y = MM->GetPosition ().y;
  std::cout << "This Position: " << pos.x<<" "<< pos.y << std::endl;
  for (int i = 1; i < nbapp->getNb()->GetTableSize(); i++)
    {
      pos = nbapp->getNb()->GetCartesianPosition(i);
      std::cout<< pos.x<<" "<< pos.y << std::endl;
    }
  fflush(stdout);

}
/**
 * $node_(1) set X_ 611.98
$node_(1) set Y_ 600.52
$node_(1) set Z_ 0
 */
void GpsrExample::OutputTrace()
{
  std::vector<uint32_t> v1;
  for (uint32_t i=0; i<m_nodesContainer.GetN(); i++)
    v1.push_back(i);
  std::random_shuffle(v1.begin(), v1.end());
  std::random_shuffle(v1.begin(), v1.end());
  std::random_shuffle(v1.begin(), v1.end());

  for (uint32_t j=0; j<m_nodesContainer.GetN(); j++)
    {
      uint32_t n= v1.back();
      v1.pop_back();
      Ptr<Node> i = m_nodesContainer.Get(n);
      Vector p = (i->GetObject<MobilityModel>())->GetPosition ();
      NS_LOG_UNCOND ("$node_("<< j << ") set X_ " << p.x);
      NS_LOG_UNCOND ("$node_("<< j << ") set Y_ " << p.y);
      NS_LOG_UNCOND ("$node_("<< j << ") set Z_ 0");
    }



//  Vector p;
//  for (NodeContainer::Iterator i = m_nodesContainer.Begin (); i != m_nodesContainer.End (); ++i)
//    {
//      p = ((*i)->GetObject<MobilityModel>())->GetPosition ();
//      NS_LOG_UNCOND ("$node_("<< (*i)->GetId() << ") set X_ " << p.x);
//      NS_LOG_UNCOND ("$node_("<< (*i)->GetId() << ") set Y_ " << p.y);
//      NS_LOG_UNCOND ("$node_("<< (*i)->GetId() << ") set Z_ 0");
////      NS_LOG_UNCOND ("positionAlloc->Add (Vector (" << p.x <<"," <<p.y<<","<<"0));");
//    }
}


void
GpsrExample::Run ()
{
  //Config::SetDefault ("ns3::WifiRemoteStationManager::RtsCtsThreshold", UintegerValue (1)); // enable rts cts all the time.
  SetupScenario();

  CreateNodes ();
  SetupAdhocMobilityNodes();
  CreateDevices ();
  InstallInternetStack ();
  InstallApplications ();

  if(m_routingProtocol == GPSR)
    {
      GpsrHelper gpsr;
      gpsr.Install (m_mbr);
    }
  if(m_routingProtocol == GEOSVR)
    {
      GeosvrHelper geosvr;
      geosvr.Install (m_mbr);
    }

  SetupRoutingMessages(m_nodesContainer, dataInterfaces);
  
  //	Flow	monitor
  Ptr<FlowMonitor>	flowMonitor;
  FlowMonitorHelper	flowHelper;
  flowMonitor = flowHelper.InstallAll();

  std::cout << "Starting simulation for " << totalTime << " s ...\n";

//  if (m_mbr)
//    {
//      Config::ConnectWithoutContext ("/NodeList/*/DeviceList/*/$ns3::WifiNetDevice/Mac/RelayedPktNum", MakeCallback (&IntTrace));
//    }
//  Config::ConnectWithoutContext ("/NodeList/*/DeviceList/0/$ns3::WifiNetDevice/Phy/PhyRxDrop", MakeCallback (&LossPktTrace));

  Config::ConnectWithoutContext ("/NodeList/*/$ns3::gpsr::RoutingProtocol/RecoveryCount", MakeCallback (&GpsrRecPktTrace));
  Config::ConnectWithoutContext ("/NodeList/*/$ns3::gpsr::RoutingProtocol/DropPkt", MakeCallback (&GpsrDropPktTrace));
  Config::ConnectWithoutContext ("/NodeList/*/$ns3::aodv::RoutingProtocol/RreqTimeoutCount", MakeCallback (&IntTrace));

  mbr::MbrRoute::setRelayedPktNum(0);
  mbr::MbrRoute::setNoNeighborPktNum(0);

  CheckThroughput();

//  Simulator::Schedule (Seconds (2.0), &GpsrExample::OutputTrace, this);
//  Simulator::Schedule (Seconds (4.0), &GpsrExample::OutputNeighbor, this);

  Simulator::Stop (Seconds (totalTime));
  Simulator::Run ();

  flowMonitor->SerializeToXmlFile(m_flowOutFile,true,true);
/*
  for (std::map<int,int>::iterator it = m_distanceMap.begin(); it != m_distanceMap.end(); it++)
    {
      std::ofstream out (m_distanceOutFile, std::ios::app);

      out <<std::setw(6)<< it->first << "  "
          <<std::setw(6)<< it->second << " "
          << std::endl;
      out.close ();
    }
*/

  Simulator::Destroy ();
}

void
GpsrExample::Report (std::ostream &)
{
}

void
GpsrExample::CreateNodes ()
{
  std::cout << "Creating " << (unsigned)m_nNodes << " nodes " << "\n";
  m_nodesContainer.Create (m_nNodes);
  // Name nodes
  for (uint32_t i = 0; i < m_nNodes; ++i)
     {
       std::ostringstream os;
       // Set the Node name to the corresponding IP host address
       os << "node-" << i+1;
       Names::Add (os.str (), m_nodesContainer.Get (i));
     }

}

void
GpsrExample::CreateDevices ()
{
  if (m_lossModel == 1)
    {
      m_lossModelName = "ns3::FriisPropagationLossModel";
    }
  else if (m_lossModel == 2)
    {
      m_lossModelName = "ns3::ItuR1411LosPropagationLossModel";
    }
  else if (m_lossModel == 3)
    {
      m_lossModelName = "ns3::TwoRayGroundPropagationLossModel";
    }
  else if (m_lossModel == 4)
    {
      m_lossModelName = "ns3::LogDistancePropagationLossModel";
    }
  else
    {
      // Unsupported propagation loss model.
      // Treating as ERROR

    }
  double freq = 5.9e9;

//  NqosWifiMacHelper wifiMac = NqosWifiMacHelper::Default ();
//  wifiMac.SetType ("ns3::AdhocWifiMac");
//  YansWifiPhyHelper wifiPhy = YansWifiPhyHelper::Default ();
//  YansWifiChannelHelper wifiChannel = YansWifiChannelHelper::Default ();
//  wifiPhy.SetChannel (wifiChannel.Create ());
//  WifiHelper wifi;
//  wifi.SetStandard (WIFI_PHY_STANDARD_80211b);
//  wifi.SetRemoteStationManager ("ns3::ConstantRateWifiManager", "DataMode", StringValue ("DsssRate11Mbps"), "RtsCtsThreshold", UintegerValue (1560));
//  beaconDevices = wifi.Install (wifiPhy, wifiMac, m_nodesContainer);

  /**
   * Data channel
   */

  YansWifiChannelHelper wifiChannel2;
  wifiChannel2.SetPropagationDelay ("ns3::ConstantSpeedPropagationDelayModel");
  if (m_lossModel == 3)
    {
      // two-ray requires antenna height (else defaults to Friss)
      wifiChannel2.AddPropagationLoss (m_lossModelName, "Frequency", DoubleValue (freq), "HeightAboveZ", DoubleValue (1.5));
    }
  else
    {
      wifiChannel2.AddPropagationLoss (m_lossModelName, "Frequency", DoubleValue (freq));
    }

  uint32_t rdis;
  rdis = 200;
  if (m_loadBuildings == 1) {
    wifiChannel2.AddPropagationLoss ("ns3::ObstacleShadowingPropagationLossModel", "ForBeacon", UintegerValue(0), "MaxDistance", UintegerValue(rdis));
    //wifiChannel2.AddPropagationLoss ("ns3::NakagamiPropagationLossModel");
  }
  else
    wifiChannel2.AddPropagationLoss ("ns3::NakagamiPropagationLossModel");
  Ptr<YansWifiChannel> channel = wifiChannel2.Create ();
  YansWifiPhyHelper wifiPhy2 =  YansWifiPhyHelper::Default ();
  wifiPhy2.SetChannel (channel);
  wifiPhy2.SetPcapDataLinkType (YansWifiPhyHelper::DLT_IEEE802_11);
  NqosWaveMacHelper wifi80211pMac = NqosWaveMacHelper::Default ();
  Wifi80211pHelper wifi80211p = Wifi80211pHelper::Default ();

  if (m_tdma_enable)
  // Setup 802.11p stuff
	  wifi80211p.SetRemoteStationManager ("ns3::ConstantRateWifiManager",
                                       "DataMode",StringValue (m_phyMode),
                                       "ControlMode",StringValue (m_phyMode),
				       "NonUnicastMode", StringValue ("OfdmRate12MbpsBW10MHz"));
  else
	  wifi80211p.SetRemoteStationManager ("ns3::ConstantRateWifiManager",
                                       "DataMode",StringValue (m_phyMode),
                                       "ControlMode",StringValue (m_phyMode),
				       "NonUnicastMode", StringValue ("OfdmRate3MbpsBW10MHz"));
  // Set Tx Power
  wifiPhy2.Set ("TxPowerStart",DoubleValue (m_txp));
  wifiPhy2.Set ("TxPowerEnd", DoubleValue (m_txp));

  dataDevices = wifi80211p.Install (wifiPhy2, wifi80211pMac, m_nodesContainer, m_tdma_enable);

//  WifiHelper wifi;
//  WifiMacHelper wifiMac;
//  wifiMac.SetType ("ns3::AdhocWifiMac");
//  YansWifiPhyHelper wifiPhydata = YansWifiPhyHelper::Default ();
//  YansWifiChannelHelper wifiChanneldata = YansWifiChannelHelper::Default ();
//  wifiPhydata.SetChannel (wifiChanneldata.Create ());
//  dataDevices = wifi.Install (wifiPhydata, wifiMac, m_nodesContainer);
//



  /**
    * Beacon channel
    */
  if (m_mbr)
    {
      YansWifiChannelHelper wifiChannel;
      wifiChannel.SetPropagationDelay ("ns3::ConstantSpeedPropagationDelayModel");
      // two-ray requires antenna height (else defaults to Friss)
      wifiChannel.AddPropagationLoss (m_lossModelName, "Frequency", DoubleValue (freq), "HeightAboveZ", DoubleValue (1.5));
      if (m_sub1g)
	rdis = 270; //
      else
	rdis = 200;
      wifiChannel.AddPropagationLoss ("ns3::ObstacleShadowingPropagationLossModel", "ForBeacon", UintegerValue(m_sub1g), "MaxDistance", UintegerValue(rdis));
      Ptr<YansWifiChannel> channel0 = wifiChannel.Create ();
      YansWifiPhyHelper wifiPhy =  YansWifiPhyHelper::Default ();
      wifiPhy.SetChannel (channel0);
      wifiPhy.SetPcapDataLinkType (YansWifiPhyHelper::DLT_IEEE802_11);
      NqosWaveMacHelper wifi80211pMacBeacon = NqosWaveMacHelper::Default ();
      Wifi80211pHelper wifi80211pBeacon = Wifi80211pHelper::Default ();

      // Setup 802.11p stuff
      wifi80211pBeacon.SetRemoteStationManager ("ns3::ConstantRateWifiManager",
					  "DataMode",StringValue ("OfdmRate3MbpsBW10MHz"),
					  "ControlMode",StringValue ("OfdmRate3MbpsBW10MHz"),
					  "NonUnicastMode", StringValue ("OfdmRate3MbpsBW10MHz"));
      // Set Tx Power
      wifiPhy.Set ("TxPowerStart",DoubleValue (m_txp));
      wifiPhy.Set ("TxPowerEnd", DoubleValue (m_txp));

      beaconDevices = wifi80211pBeacon.Install (wifiPhy, wifi80211pMacBeacon, m_nodesContainer);
    }



  // Enable Captures, if necessary
  if (pcap)
    {
//      wifiPhy.EnablePcapAll (std::string ("gpsr-pcap"));
//      wifiPhy2.EnablePcapAll (std::string ("gpsr-pcap"));
    }

}

void
GpsrExample::InstallInternetStack ()
{
  InternetStackHelper stack;
  switch (m_routingProtocol)
  {
    case (AODV):
    {
      AodvHelper aodv;
      aodv.Set("Mbr", UintegerValue (m_mbr));
      aodv.Set("HelloInterval", TimeValue (Seconds (0.5)));
      //aodv.Set("TtlThreshold", UintegerValue (40));
      //aodv.Set("TtlStart", UintegerValue (3));
      aodv.Set("TtlStart", UintegerValue (1));
      aodv.Set("TtlIncrement", UintegerValue (2));
      aodv.Set("NodeTraversalTime", TimeValue (MilliSeconds (100)));
      aodv.Set("RreqRetries", UintegerValue (20));
      aodv.Set("RreqRateLimit", UintegerValue (30));

      aodv.Set("AllowedHelloLoss", UintegerValue (3));
      aodv.Set("DestinationOnly", BooleanValue (true));
      //Ptr<OutputStreamWrapper> routingStream = Create<OutputStreamWrapper> ("aodv.routes", std::ios::out);

      //AsciiTraceHelper ascii;
      //Ptr<OutputStreamWrapper> routingStream = ascii.CreateFileStream ("routing_table");
      //aodv.PrintRoutingTableAllAt (Seconds (8), routingStream);

      // you can configure AODV attributes here using aodv.Set(name, value)
      stack.SetRoutingHelper (aodv); // has effect on the next Install ()
      stack.Install (m_nodesContainer);
      break;
    }
    case (GPSR):
    {
      GpsrHelper gpsr;
      gpsr.Set("HelloInterval", TimeValue (Seconds (0.25)));
      // you can configure GPSR attributes here using gpsr.Set(name, value)
      stack.SetRoutingHelper (gpsr);
      stack.Install (m_nodesContainer);
      break;
    }
    case (GEOSVR):
    {
      GeosvrHelper geosvr;
      //geosvr.Set("HelloInterval", TimeValue (Seconds (0.25)));
      geosvr.Set("Range", DoubleValue(200));
      geosvr.Set("DTN", BooleanValue(m_dtn_enable));
      // you can configure GPSR attributes here using gpsr.Set(name, value)
      stack.SetRoutingHelper (geosvr);
      stack.Install (m_nodesContainer);
      break;
    }
  }


  Ipv4AddressHelper addressAdhocData;
  addressAdhocData.SetBase ("10.1.0.0", "255.255.0.0");
  dataInterfaces = addressAdhocData.Assign (dataDevices);

  Ipv4AddressHelper address;
  address.SetBase ("10.2.0.0", "255.255.0.0");
  beaconInterfaces = address.Assign (beaconDevices);
}

void
GpsrExample::InstallApplications ()
{
  if (!m_mbr)
    return;

  m_MbrNeighborHelper.Install(beaconInterfaces,
			      dataInterfaces,
			      beaconDevices,
			      dataDevices,
			      Seconds(((m_startTime-4)<0)?0:(m_startTime-4)),//Seconds(10),//
			      Seconds (totalTime),//Seconds(4),//
			      100,//m_wavePacketSize,
			      Seconds (0.25),//m_waveInterval
			      Seconds (1),//m_waveExpire
			      // GPS accuracy (i.e, clock drift), in number of ns
			      40,//m_gpsAccuracyNs,
			      // tx max delay before transmit, in ms
			      MilliSeconds (10),//m_txMaxDelayMs
			      m_netFileString,
			      m_osmFileString,
			      m_openRelay);
  // fix random number streams
  m_MbrNeighborHelper.AssignStreams (m_nodesContainer, 0);


}

void
GpsrExample::SetupScenario()
{
  if (m_scenario == 1)
    {
      m_traceFile = "src/wave/examples/Raleigh_Downtown50.ns2";
      m_lossModel = 3; // two-ray ground
      m_nSinks = 10;
      m_nNodes = 50;
      totalTime = 30;
      m_mobility = 1;
      if (m_loadBuildings != 0)
	{
	  std::string bldgFile = "src/wave/examples/Raleigh_Downtown.buildings.xml";
	  NS_LOG_UNCOND ("Loading buildings file " << bldgFile);
	  Topology::LoadBuildings(bldgFile);
	}
    }
  else if (m_scenario == 2)
    {
      m_mobility = 2; //static relay
      m_nNodes = 4;
      totalTime = 10;
      m_nSinks = 1;
      m_lossModel = 3; // two-ray ground

      m_netFileString = "src/wave/examples/9gong/output.net.xml";
      m_osmFileString = "";
      if (m_loadBuildings != 0)
        {
          std::string bldgFile = "src/wave/examples/9gong/buildings.xml";
          NS_LOG_UNCOND ("Loading buildings file " << bldgFile);
          Topology::LoadBuildings(bldgFile);
        }

    }
  else if (m_scenario == 3)
    {
      m_traceFile = "/home/wu/workspace/ns-3/ns-3.26/src/wave/examples/20170827/20170827.ns2";

      m_mobility = 1;
      m_nNodes = 344;
      totalTime = 30;
      m_nSinks = 40;
      m_lossModel = 3; // two-ray ground
      //m_mbr = true;
      m_netFileString = "/home/wu/workspace/ns-3/ns-3.26/src/wave/examples/20170827/output.net.xml";
      if (m_loadBuildings != 0)
        {
          std::string bldgFile = "/home/wu/workspace/ns-3/ns-3.26/src/wave/examples/20170827/buildings.xml";
          NS_LOG_UNCOND ("Loading buildings file " << bldgFile);
          Topology::LoadBuildings(bldgFile);
        }

    }
  else if (m_scenario == 4)
    {
      m_traceFile = "";
      m_mobility = 3;
      m_nNodes = 26;
      totalTime = 10;
      //m_nSinks = 1;
      m_lossModel = 3; // two-ray ground
      //m_mbr = true;
      m_netFileString = "/home/wu/workspace/ns-3/ns-3.26/src/wave/examples/20170831/output.net.xml";
      if (m_loadBuildings != 0)
        {
          std::string bldgFile = "/home/wu/workspace/ns-3/ns-3.26/src/wave/examples/20170831/buildings.xml";
          NS_LOG_UNCOND ("Loading buildings file " << bldgFile);
          Topology::LoadBuildings(bldgFile);
        }

    }
  else if (m_scenario == 5)
    {
      m_traceFile = "src/wave/examples/newyork/newyorkmobility.ns2";

      m_mobility = 1;
      //m_nNodes = 50;
      //totalTime = 30;
      //m_nSinks = 25;
      m_lossModel = 3; // two-ray ground
      //m_mbr = true;
      m_netFileString = "src/wave/examples/newyork/output.net.xml";
      m_osmFileString = "src/wave/examples/newyork/output.osm";
      if (m_loadBuildings != 0)
        {
          std::string bldgFile = "src/wave/examples/newyork/buildings.xml";
          NS_LOG_UNCOND ("Loading buildings file " << bldgFile);
          Topology::LoadBuildings(bldgFile);
        }

      if (m_startTime < 1)
	m_startTime = 1;
    }
  else if (m_scenario == 6)
    {
      m_traceFile = "src/wave/examples/9gong/9gong-30mps.ns2";

      char snodes[5];
      sprintf(snodes, "%d", m_nNodes);
      m_flowOutFile = m_outputPrefix;
      m_flowOutFile.append(m_routingProtocolStr);
      if(m_openRelay)
	{
	  m_flowOutFile.append("-relay-");
	}
      else
	{
	  m_flowOutFile.append("-norelay-");
	}
      m_flowOutFile.append(snodes);
      m_flowOutFile.append("nodes-r");
      m_flowOutFile.append(m_round);
      m_flowOutFile.append("-flow.xml");


      m_throughputOutFile = m_outputPrefix;
      m_throughputOutFile.append(m_routingProtocolStr);
       if(m_openRelay)
 	{
	   m_throughputOutFile.append("-relay-");
 	}
       else
 	{
	   m_throughputOutFile.append("-norelay-");
 	}
      m_throughputOutFile.append(snodes);
      m_throughputOutFile.append("nodes-r");
      m_throughputOutFile.append(m_round);
      m_throughputOutFile.append(".txt");

      m_distanceOutFile = m_outputPrefix;
      m_distanceOutFile.append(m_routingProtocolStr);
       if(m_openRelay)
 	{
	   m_distanceOutFile.append("-relay-");
 	}
       else
 	{
	   m_distanceOutFile.append("-norelay-");
 	}
       m_distanceOutFile.append(snodes);
       m_distanceOutFile.append("nodes-r");
       m_distanceOutFile.append(m_round);
       m_distanceOutFile.append("-distance.txt");


      m_mobility = 1;
      //m_nNodes = 50;
      //totalTime = 30;
      //m_nSinks = 25;
      m_lossModel = 3; // two-ray ground
      //m_mbr = true;
      m_netFileString = "src/wave/examples/9gong/output.net.xml";
      m_osmFileString = "";
      if (m_loadBuildings != 0)
        {
          std::string bldgFile = "src/wave/examples/9gong/buildings.xml";
          NS_LOG_UNCOND ("Loading buildings file " << bldgFile);
          Topology::LoadBuildings(bldgFile);
        }

      if (m_startTime < 1)
	m_startTime = 1;
    }
  else if (m_scenario == 7)
    {
      m_traceFile = "src/wave/examples/9gong/static.ns2";

      m_mobility = 1;
//      m_nNodes = 466;
      //totalTime = 30;
      //m_nSinks = 1;
      m_lossModel = 3; // two-ray ground
      //m_mbr = true;
      m_netFileString = "src/wave/examples/9gong/output.net.xml";
      m_osmFileString = "";
      if (m_loadBuildings != 0)
        {
          std::string bldgFile = "src/wave/examples/9gong/non-buildings.xml";
          NS_LOG_UNCOND ("Loading buildings file " << bldgFile);
          Topology::LoadBuildings(bldgFile);
        }

      if (m_startTime < 1)
	m_startTime = 1;
    }
  else if (m_scenario == 8)
    {
      m_traceFile = "src/wave/examples/9gong/static-";
      m_traceFile.append(m_round);//1, 2, 3
      m_traceFile.append(".ns2");

      char snodes[5];
      sprintf(snodes, "%d", m_nNodes);
      m_flowOutFile = m_outputPrefix;
      m_flowOutFile.append(m_routingProtocolStr);
      if(m_openRelay)
	{
	  m_flowOutFile.append("-relay-");
	}
      else
	{
	  m_flowOutFile.append("-norelay-");
	}
      m_flowOutFile.append(snodes);
      m_flowOutFile.append("nodes-r");
      m_flowOutFile.append(m_round);
      m_flowOutFile.append("-flow.xml");


      m_throughputOutFile = m_outputPrefix;
      m_throughputOutFile.append(m_routingProtocolStr);
       if(m_openRelay)
 	{
	   m_throughputOutFile.append("-relay-");
 	}
       else
 	{
	   m_throughputOutFile.append("-norelay-");
 	}
      m_throughputOutFile.append(snodes);
      m_throughputOutFile.append("nodes-r");
      m_throughputOutFile.append(m_round);
      m_throughputOutFile.append(".txt");


      m_distanceOutFile = m_outputPrefix;
      m_distanceOutFile.append(m_routingProtocolStr);
       if(m_openRelay)
 	{
	   m_distanceOutFile.append("-relay-");
 	}
       else
 	{
	   m_distanceOutFile.append("-norelay-");
 	}
       m_distanceOutFile.append(snodes);
       m_distanceOutFile.append("nodes-r");
       m_distanceOutFile.append(m_round);
       m_distanceOutFile.append("-distance.txt");


      m_mobility = 1;
//      m_nNodes = 466;
      //totalTime = 30;
      //m_nSinks = 1;
      m_lossModel = 3; // two-ray ground
      //m_mbr = true;
      m_netFileString = "src/wave/examples/9gong/output.net.xml";
      m_osmFileString = "";
      if (m_loadBuildings != 0)
        {
          std::string bldgFile = "src/wave/examples/9gong/buildings.xml";
          NS_LOG_UNCOND ("Loading buildings file " << bldgFile);
          Topology::LoadBuildings(bldgFile);
        }

      if (m_startTime < 1)
	m_startTime = 1;
    }
  else if (m_scenario == 9)
    {
      m_traceFile = "src/wave/examples/9gong/9gong.ns2";

      char snodes[5];
      sprintf(snodes, "%d", m_nNodes);
      m_flowOutFile = m_outputPrefix;
      m_flowOutFile.append(m_routingProtocolStr);
      if(m_openRelay)
	{
	  m_flowOutFile.append("-relay-");
	}
      else
	{
	  m_flowOutFile.append("-norelay-");
	}
      m_flowOutFile.append(snodes);
      m_flowOutFile.append("nodes-r");
      m_flowOutFile.append(m_round);
      m_flowOutFile.append("-flow.xml");


      m_throughputOutFile = m_outputPrefix;
      m_throughputOutFile.append(m_routingProtocolStr);
       if(m_openRelay)
 	{
	   m_throughputOutFile.append("-relay-");
 	}
       else
 	{
	   m_throughputOutFile.append("-norelay-");
 	}
      m_throughputOutFile.append(snodes);
      m_throughputOutFile.append("nodes-r");
      m_throughputOutFile.append(m_round);
      m_throughputOutFile.append(".txt");

      m_distanceOutFile = m_outputPrefix;
      m_distanceOutFile.append(m_routingProtocolStr);
       if(m_openRelay)
 	{
	   m_distanceOutFile.append("-relay-");
 	}
       else
 	{
	   m_distanceOutFile.append("-norelay-");
 	}
       m_distanceOutFile.append(snodes);
       m_distanceOutFile.append("nodes-r");
       m_distanceOutFile.append(m_round);
       m_distanceOutFile.append("-distance.txt");


      m_mobility = 1;
      //m_nNodes = 50;
      //totalTime = 30;
      //m_nSinks = 25;
      m_lossModel = 3; // two-ray ground
      //m_mbr = true;
      m_netFileString = "src/wave/examples/9gong/output.net.xml";
      m_osmFileString = "";
      if (m_loadBuildings != 0)
        {
          std::string bldgFile = "src/wave/examples/9gong/buildings.xml";
          NS_LOG_UNCOND ("Loading buildings file " << bldgFile);
          Topology::LoadBuildings(bldgFile);
        }

      if (m_startTime < 1)
	m_startTime = 1;
    }
}
void
GpsrExample::SetupAdhocMobilityNodes ()
{
  if (m_mobility == 1)
    {
      // Create Ns2MobilityHelper with the specified trace log file as parameter
      Ns2MobilityHelper ns2 = Ns2MobilityHelper (m_traceFile);
      ns2.Install (); // configure movements for each node, while reading trace file
    }
  else if (m_mobility == 2)
    {
      MobilityHelper mobility;
      Ptr<ListPositionAllocator> positionAlloc = CreateObject<ListPositionAllocator> ();
      positionAlloc->Add (Vector (0, 100, 0));
      positionAlloc->Add (Vector (0, 150, 0));
      positionAlloc->Add (Vector (0, 100, 0));
      positionAlloc->Add (Vector (0, 150, 0));



      mobility.SetPositionAllocator(positionAlloc);
      mobility.SetMobilityModel ("ns3::ConstantPositionMobilityModel");
      mobility.Install (m_nodesContainer);
    }
  else if (m_mobility == 3)
    {
      MobilityHelper mobility;
      Ptr<ListPositionAllocator> positionAlloc = CreateObject<ListPositionAllocator> ();
      positionAlloc->Add (Vector (3, 550, 0)); //0

      positionAlloc->Add (Vector (0, 586, 0));
      positionAlloc->Add (Vector (30, 588, 0));

      positionAlloc->Add (Vector (85, 593, 0));
      positionAlloc->Add (Vector (154, 596, 0));
      positionAlloc->Add (Vector (249, 600, 0));
      positionAlloc->Add (Vector (293, 608, 0));

      //positionAlloc->Add (Vector (310, 607, 0));//plus0

      positionAlloc->Add (Vector (325, 612, 0));
      positionAlloc->Add (Vector (373, 612, 0));//re 8
      positionAlloc->Add (Vector (375, 576, 0));
      positionAlloc->Add (Vector (375, 568, 0));//plus1
      //positionAlloc->Add (Vector (375, 558, 0));//plus2

      positionAlloc->Add (Vector (375, 544, 0));
      positionAlloc->Add (Vector (386, 453, 0));
      positionAlloc->Add (Vector (396, 398, 0));
      positionAlloc->Add (Vector (401, 333, 0)); //13
      positionAlloc->Add (Vector (408, 240, 0));
      positionAlloc->Add (Vector (415, 106, 0));

      positionAlloc->Add (Vector (416, 60, 0));
      positionAlloc->Add (Vector (417, 25, 0));

      positionAlloc->Add (Vector (455, 21, 0));
      positionAlloc->Add (Vector (540, 22, 0));
      positionAlloc->Add (Vector (610, 22, 0));
      positionAlloc->Add (Vector (675, 20, 0));  //21

      positionAlloc->Add (Vector (725, 14, 0));
      positionAlloc->Add (Vector (797, 21, 0));

      positionAlloc->Add (Vector (795, 57, 0));
      positionAlloc->Add (Vector (780, 120, 0)); //25

      mobility.SetPositionAllocator(positionAlloc);
      mobility.SetMobilityModel ("ns3::ConstantPositionMobilityModel");
      mobility.Install (m_nodesContainer);
    }
  else if (m_mobility == 4)
    {
      MobilityHelper mobility;
      // place two nodes at specific positions (100,0) and (0,100)
      Ptr<ListPositionAllocator> positionAlloc = CreateObject<ListPositionAllocator> ();
//      positionAlloc->Add (Vector (301, 721, 0)); //0
//      positionAlloc->Add (Vector (916, 316, 0));

      mobility.SetPositionAllocator(positionAlloc);
      mobility.SetMobilityModel ("ns3::ConstantPositionMobilityModel");
      mobility.Install (m_nodesContainer);
    }

  if (m_rsu)
    {
      //Install RSUs
      Ptr<ListPositionAllocator> positionAlloc = CreateObject<ListPositionAllocator> ();
      positionAlloc->Add (Vector (1, 895, 0));
      positionAlloc->Add (Vector (304, 893, 0));
      positionAlloc->Add (Vector (605, 900, 0));
      positionAlloc->Add (Vector (901, 897, 0));
      positionAlloc->Add (Vector (2, 602, 0));
      positionAlloc->Add (Vector (302, 604, 0));
      positionAlloc->Add (Vector (602, 602, 0));
      positionAlloc->Add (Vector (908, 598, 0));
      positionAlloc->Add (Vector (7, 309, 0));
      positionAlloc->Add (Vector (307, 310, 0));
      positionAlloc->Add (Vector (610, 313, 0));
      positionAlloc->Add (Vector (915, 314, 0));
      positionAlloc->Add (Vector (15, 1, 0));
      positionAlloc->Add (Vector (313, 7, 0));
      positionAlloc->Add (Vector (615, 5, 0));
      positionAlloc->Add (Vector (915, 11, 0));

      InstallRSU(m_nodesContainer, 16, positionAlloc);
    }
}

void
GpsrExample::SetupRoutingMessages (NodeContainer & c,
                           Ipv4InterfaceContainer & adhocTxInterfaces)
{
  // Setup routing transmissions
  OnOffHelper onoff1 ("ns3::UdpSocketFactory",Address (),true, dataDevices);
  onoff1.SetAttribute ("OnTime", StringValue ("ns3::ConstantRandomVariable[Constant=1.0]"));
  onoff1.SetAttribute ("OffTime", StringValue ("ns3::ConstantRandomVariable[Constant=0.0]"));

  Ptr<UniformRandomVariable> var = CreateObject<UniformRandomVariable> ();
  int64_t stream = 2;
  var->SetStream (stream);
  if (m_scenario == 9)
    {
      Ptr<Socket> sink = SetupRoutingPacketReceive (adhocTxInterfaces.GetAddress (158), c.Get (158));
      AddressValue remoteAddress (InetSocketAddress (adhocTxInterfaces.GetAddress (158), m_port));
      onoff1.SetAttribute ("Remote", remoteAddress);
      onoff1.SetAttribute ("PacketSize", UintegerValue (m_pktSize));
      onoff1.SetAttribute ("DataRate", DataRateValue(DataRate ("50kb/s")));

      ApplicationContainer temp = onoff1.Install (c.Get (208));
      temp.Start (Seconds (m_startTime));//temp.Start (Seconds (var->GetValue (1.0,2.0)));
      temp.Stop (Seconds (totalTime));
    }
  else if (m_scenario == 6)
    {
      for (uint32_t i = atoi(m_round.c_str()); i < m_nSinks + atoi(m_round.c_str()); i++)
		{

		  Ptr<Socket> sink = SetupRoutingPacketReceive (adhocTxInterfaces.GetAddress (i), c.Get (i));


		  AddressValue remoteAddress (InetSocketAddress (adhocTxInterfaces.GetAddress (i), m_port));
		  onoff1.SetAttribute ("Remote", remoteAddress);
		  onoff1.SetAttribute ("PacketSize", UintegerValue (m_pktSize));
		  onoff1.SetAttribute ("DataRate", DataRateValue(DataRate ("50kb/s")));

		  ApplicationContainer temp = onoff1.Install (c.Get (i + m_nSinks));
		  temp.Start (Seconds (m_startTime));//var->GetValue (1.0,2.0)));
		  temp.Stop (Seconds (totalTime));
		}
    }
  else if (m_scenario != 4 && m_scenario!=2)
    {
      for (uint32_t i = 0; i < m_nSinks; i++)
	{

	  Ptr<Socket> sink = SetupRoutingPacketReceive (adhocTxInterfaces.GetAddress (i), c.Get (i));


	  AddressValue remoteAddress (InetSocketAddress (adhocTxInterfaces.GetAddress (i), m_port));
	  onoff1.SetAttribute ("Remote", remoteAddress);
	  onoff1.SetAttribute ("PacketSize", UintegerValue (m_pktSize));
	  onoff1.SetAttribute ("DataRate", DataRateValue(DataRate ("50kb/s")));

	  ApplicationContainer temp = onoff1.Install (c.Get (i + m_nSinks));
	  temp.Start (Seconds (m_startTime));//var->GetValue (1.0,2.0)));
	  temp.Stop (Seconds (totalTime));
	}
    }
  else
    {

		  Ptr<Socket> sink = SetupRoutingPacketReceive (adhocTxInterfaces.GetAddress (0), c.Get (0));
		  AddressValue remoteAddress (InetSocketAddress (adhocTxInterfaces.GetAddress (0), m_port));
		  onoff1.SetAttribute ("Remote", remoteAddress);
		  onoff1.SetAttribute ("PacketSize", UintegerValue (m_pktSize));
		  onoff1.SetAttribute ("DataRate", DataRateValue(DataRate ("5000kb/s")));
		  ApplicationContainer temp = onoff1.Install (c.Get (1));
		  temp.Start (Seconds (m_startTime));//var->GetValue (1.0,2.0)));
		  temp.Stop (Seconds (totalTime));

		  OnOffHelper onoff2 ("ns3::UdpSocketFactory",Address (),true, dataDevices);;
		  Ptr<Socket> sink2 = SetupRoutingPacketReceive (adhocTxInterfaces.GetAddress (2), c.Get (2));
		  AddressValue remoteAddress2 (InetSocketAddress (adhocTxInterfaces.GetAddress (2), m_port));
		  onoff2.SetAttribute ("Remote", remoteAddress2);
		  onoff2.SetAttribute ("PacketSize", UintegerValue (m_pktSize));
		  onoff2.SetAttribute ("DataRate", DataRateValue(DataRate ("10000kb/s")));
		  ApplicationContainer temp2 = onoff2.Install (c.Get (3));
		  temp2.Start (Seconds (m_startTime));//var->GetValue (1.0,2.0)));
		  temp2.Stop (Seconds (totalTime));

		  OnOffHelper onoff3 ("ns3::UdpSocketFactory",Address (),true, dataDevices);;
		  SetupRoutingPacketReceive (adhocTxInterfaces.GetAddress (1), c.Get (1));
		  AddressValue remoteAddress3 (InetSocketAddress (adhocTxInterfaces.GetAddress (1), m_port));
		  onoff1.SetAttribute ("Remote", remoteAddress3);
		  onoff1.SetAttribute ("PacketSize", UintegerValue (m_pktSize));
		  onoff1.SetAttribute ("DataRate", DataRateValue(DataRate ("5000kb/s")));
		  ApplicationContainer temp3 = onoff1.Install (c.Get (0));
		  temp3.Start (Seconds (m_startTime));//var->GetValue (1.0,2.0)));
		  temp3.Stop (Seconds (totalTime));

		  OnOffHelper onoff4 ("ns3::UdpSocketFactory",Address (),true, dataDevices);;
		  Ptr<Socket> sink4 = SetupRoutingPacketReceive (adhocTxInterfaces.GetAddress (3), c.Get (3));
		  AddressValue remoteAddress4 (InetSocketAddress (adhocTxInterfaces.GetAddress (3), m_port));
		  onoff4.SetAttribute ("Remote", remoteAddress4);
		  onoff4.SetAttribute ("PacketSize", UintegerValue (m_pktSize));
		  onoff4.SetAttribute ("DataRate", DataRateValue(DataRate ("10000kb/s")));
		  ApplicationContainer temp4 = onoff4.Install (c.Get (2));
		  temp4.Start (Seconds (m_startTime));//var->GetValue (1.0,2.0)));
		  temp4.Stop (Seconds (totalTime));


/*	Ptr<Socket> sink = SetupRoutingPacketReceive (adhocTxInterfaces.GetAddress (m_nSinks), c.Get (m_nSinks));
	AddressValue remoteAddress (InetSocketAddress (adhocTxInterfaces.GetAddress (m_nSinks), m_port));
	onoff1.SetAttribute ("Remote", remoteAddress);
	onoff1.SetAttribute ("PacketSize", UintegerValue (m_pktSize));
	onoff1.SetAttribute ("DataRate", DataRateValue(DataRate ("50kb/s")));

	ApplicationContainer temp = onoff1.Install (c.Get (4));
	temp.Start (Seconds (m_startTime));//temp.Start (Seconds (var->GetValue (1.0,2.0)));
	temp.Stop (Seconds (totalTime));
*/
//      UdpEchoServerHelper echoServer (9);
//    // 0 --- 2 --- 1
//      ApplicationContainer serverApps = echoServer.Install (c.Get (9));
//      serverApps.Start (Seconds (1.0));
//      serverApps.Stop (Seconds (totalTime));
//
//      UdpEchoClientHelper echoClient (adhocTxInterfaces.GetAddress (9), 9); //Data interface
//      echoClient.SetAttribute ("MaxPackets", UintegerValue (1));
//      echoClient.SetAttribute ("Interval", TimeValue (Seconds (1.0)));
//      echoClient.SetAttribute ("PacketSize", UintegerValue (1424));
//
//      ApplicationContainer clientApps = echoClient.Install (c.Get (4));
//      clientApps.Start (Seconds (m_startTime));
//      clientApps.Stop (Seconds (totalTime));
    }
}
Ptr<Socket>
GpsrExample::SetupRoutingPacketReceive (Ipv4Address addr, Ptr<Node> node)
{
  TypeId tid = TypeId::LookupByName ("ns3::UdpSocketFactory");
  Ptr<Socket> sink = Socket::CreateSocket (node, tid);
  InetSocketAddress local = InetSocketAddress (addr, m_port);
  sink->Bind (local);
  sink->SetRecvCallback (MakeCallback (&GpsrExample::ReceiveRoutingPacket, this));

  return sink;
}

void
GpsrExample::CheckThroughput ()
{
  double kbs = (bytesTotal * 8.0) / 1000;
  bytesTotal = 0;

  std::ofstream out (m_throughputOutFile, std::ios::app);

  out << (Simulator::Now ()).GetSeconds () << " "
      <<std::setw(6)<< kbs << " "
      <<std::setw(6)<< packetsReceived << " "
      <<std::setw(4)<< mbr::MbrRoute::getRelayedPktNum()  << " "
      << "noNb:" << mbr::MbrRoute::getNoNeighborPktNum()<< ","
      << "gpsrRec: " << gpsrRecPktTrace << ","
      << "aodvRreqFail:" << rreqTimeoutCount << ","
      << m_nSinks << ","
      << m_txp << ""
      << std::endl;


  out.close ();
  mbr::MbrRoute::setNoNeighborPktNum(0);
  mbr::MbrRoute::setRelayedPktNum(0);
  packetsReceived = 0;
  gpsrRecPktTrace = 0;
  rreqTimeoutCount = 0;
  Simulator::Schedule (Seconds (1.0), &GpsrExample::CheckThroughput, this);
}

static Vector
GetPosition(Ipv4Address adr)
{
  uint32_t n = NodeList().GetNNodes ();
  uint32_t i;
  Ptr<Node> node;

  //NS_LOG_UNCOND("Position of " << adr);

  for(i = 0; i < n; i++)
    {
      node = NodeList().GetNode (i);
      Ptr<Ipv4> ipv4 = node->GetObject<Ipv4> ();

      //NS_LOG_UNCOND("Have " << ipv4->GetAddress (1, 0).GetLocal ());
      if(ipv4->GetAddress (1, 0).GetLocal () == adr)
	{
	  return (*node->GetObject<MobilityModel>()).GetPosition ();
	}
    }
  Vector v;
  return v;
}
static double
CalDistance (const Vector &a, const Vector &b)
{
  NS_LOG_FUNCTION (a << b);
  double dx = b.x - a.x;
  double dy = b.y - a.y;
  double distance = std::sqrt (dx * dx + dy * dy);
  return distance;
}
void
GpsrExample::ReceiveRoutingPacket (Ptr<Socket> socket)
{
  Ptr<Packet> packet;
  Vector vsrc, vdst;
  int dis;
  Address srcAddress;
  while ((packet = socket->RecvFrom (srcAddress)))
    {
      Ipv4Address adr;
      InetSocketAddress ss(adr);
      ss.ConvertFrom(srcAddress);
      adr = ss.GetIpv4();

      bytesTotal += packet->GetSize ();
      packetsReceived += 1;
      NS_LOG_LOGIC ("Packet Received");
      vsrc = GetPosition(adr);
      vdst = socket->GetNode()->GetObject<MobilityModel>()->GetPosition ();
      dis = (int)CalDistance(vsrc, vdst);

      m_distanceMap[dis]++;
//      NS_LOG_UNCOND (PrintReceivedPacket (socket, packet, senderAddress));
    }
}
