/* -*-  Mode: C++; c-file-style: "gnu"; indent-tabs-mode:nil; -*- */
/*
 * Copyright (c) 2014 North Carolina State University
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation;
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#include "mbr-neighbor-helper.h"
#include "ns3/mbr_sumomap.h"

#include "ns3/log.h"

NS_LOG_COMPONENT_DEFINE ("MbrNeighborHelper");

namespace ns3 {

std::vector<int> MbrNeighborHelper::nodesMoving;

MbrNeighborHelper::MbrNeighborHelper ()

{
  m_factory.SetTypeId ("ns3::MbrNeighborApp");
}

void
MbrNeighborHelper::SetAttribute (std::string name, const AttributeValue &value)
{
  m_factory.Set (name, value);
}

ApplicationContainer
MbrNeighborHelper::Install (Ptr<Node> node) const
{
  return ApplicationContainer (InstallPriv (node));
}

ApplicationContainer
MbrNeighborHelper::Install (Ipv4InterfaceContainer i) const
{
  ApplicationContainer apps;
  for (Ipv4InterfaceContainer::Iterator itr = i.Begin (); itr != i.End (); ++itr)
    {
      std::pair<Ptr<Ipv4>, uint32_t> interface = (*itr);
      Ptr<Ipv4> pp = interface.first;
      Ptr<Node> node = pp->GetObject<Node> ();
      apps.Add (InstallPriv (node));
    }

  return apps;
}

Ptr<Application>
MbrNeighborHelper::InstallPriv (Ptr<Node> node) const
{
  Ptr<Application> app = m_factory.Create<Application> ();
  node->AddApplication (app);

  return app;
}

void
MbrNeighborHelper::Install (Ipv4InterfaceContainer & i,
			Ipv4InterfaceContainer & iData,
			NetDeviceContainer &d,
			NetDeviceContainer &dData,
			Time startTime,
                        Time totalTime,          // seconds
                        uint32_t wavePacketSize, // bytes
                        Time waveInterval,       // seconds
			Time waveExpire,       // seconds
                        double gpsAccuracyNs,    // clock drift range in number of ns
                        Time txMaxDelay,        // max delay prior to transmit
			std::string netFileString,
			std::string osmFileString,
			bool openRelay)
{


  // install a MbrNeighborApp on each node
  ApplicationContainer mbrnbApps = Install (i);
  // start BSM app immediately (BsmApplication will
  // delay transmission of first BSM by 1.0 seconds)
  mbrnbApps.Start (startTime);
  mbrnbApps.Stop (totalTime);

  // for each app, setup the app parameters
  ApplicationContainer::Iterator aci;
  int nodeId = 0;
  for (aci = mbrnbApps.Begin (); aci != mbrnbApps.End (); ++aci)
    {
      Ptr<mbr::MbrNeighborApp> mbrnbApps = DynamicCast<mbr::MbrNeighborApp> (*aci);

      mbrnbApps->Setup (i,
		        iData,
		        d,
		        dData,
		        nodeId,
		        totalTime,
		        wavePacketSize,
		        waveInterval,
			waveExpire,
		        gpsAccuracyNs,
		        &nodesMoving,
		        txMaxDelay);
      nodeId++;
    }
  mbr::MbrSumo *map = mbr::MbrSumo::GetInstance();
  if (!map->isInitialized())
    {
	  map->Initialize(netFileString, osmFileString);
	  NS_LOG_UNCOND ("Sumo Map is loaded!");
    }
  if (openRelay) {
      NS_ASSERT(map->isMapLoaded());
      map->setInitialized(true);
      NS_LOG_UNCOND ("MBR relaying is opened!");
  }
}

int64_t
MbrNeighborHelper::AssignStreams (NodeContainer c, int64_t stream)
{
  int64_t currentStream = stream;
  Ptr<Node> node;
  for (NodeContainer::Iterator i = c.Begin (); i != c.End (); ++i)
    {
      node = (*i);
      for (uint32_t j = 0; j < node->GetNApplications (); j++)
        {
          Ptr<mbr::MbrNeighborApp> mbrnbApp = DynamicCast<mbr::MbrNeighborApp> (node->GetApplication (j));
          if (mbrnbApp)
            {
              currentStream += mbrnbApp->AssignStreams (currentStream);
            }
        }
    }
  return (currentStream - stream);
}

std::vector<int>&
MbrNeighborHelper::GetNodesMoving ()
{
  return nodesMoving;
}

} // namespace ns3
