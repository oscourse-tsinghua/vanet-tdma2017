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

#ifndef MBR_NEIGHBOR_HELPER_H
#define MBR_NEIGHBOR_HELPER_H

#include <vector>
#include <string>
#include "ns3/mbr-neighbor-app.h"
#include "ns3/object-factory.h"
#include "ns3/application-container.h"
#include "ns3/nstime.h"
#include "ns3/internet-stack-helper.h"
#include "ns3/mobility-model.h"

#include "ns3/net-device-container.h"

namespace ns3 {
/**
 * \ingroup wave
 * \brief The WaveBsmHelper class manages
 * IEEE 1609 WAVE (Wireless Access in Vehicular Environments)
 * Basic Safety Messages (BSMs) and uses the WaveBsmStats class
 * to manage statistics about BSMs transmitted and received
 * The BSM is a ~200-byte packet that is
 * generally broadcast from every vehicle at a nominal rate of 10 Hz.
 */
class MbrNeighborHelper
{
public:
  /**
   * \brief Constructor
   * \return none
   */
	MbrNeighborHelper ();

  /**
   * Helper function used to set the underlying application attributes.
   *
   * \param name the name of the application attribute to set
   * \param value the value of the application attribute to set
   */
  void SetAttribute (std::string name, const AttributeValue &value);

  /**
   * Install an ns3::BsmApplication on each node of the input container
   * configured with all the attributes set with SetAttribute.
   *
   * \param i Ipv4InterfaceContainer of the set of interfaces on which an BsmApplication
   * will be installed on the nodes.
   * \returns Container of Ptr to the applications installed.
   */
  ApplicationContainer Install (Ipv4InterfaceContainer i) const;

  /**
   * Install an ns3::BsmApplication on the node configured with all the
   * attributes set with SetAttribute.
   *
   * \param node The node on which an BsmApplication will be installed.
   * \returns Container of Ptr to the applications installed.
   */
  ApplicationContainer Install (Ptr<Node> node) const;

  /**
   * \brief Installs BSM generation on devices for nodes
   * and their interfaces
   * \param i IPv4 interface container
   * \param totalTime total amount of time that BSM packets should be transmitted
   * \param wavePacketSize the size, in bytes, of a WAVE BSM
   * \param waveInterval the time, in seconds, between each WAVE BSM transmission,
   * typically 10 Hz (0.1 second)
   * \param gpsAccuracy the timing synchronization accuracy of GPS time, in seconds.
   * GPS time-sync is ~40-100 ns.  Universally synchronized time among all vehicles
   * will result in all vehicles transmitting safety messages simultaneously, leading
   * to excessive wireless collisions.
   * \param range the expected transmission range, in m.
   * \return none
   */
  void Install (Ipv4InterfaceContainer & i,
                Ipv4InterfaceContainer & iData,
		NetDeviceContainer &d,
		NetDeviceContainer &dData,
		Time startTime,
                Time totalTime,          // seconds
                uint32_t wavePacketSize, // bytes
                Time waveInterval,       // seconds
		Time waveExpire,	// seconds
                double gpsAccuracyNs,    // clock drift range in number of ns
                Time txMaxDelay,       // max delay prior to transmit
		std::string netFileString,
		std::string osmFileString,
		bool openRelay);

  /**
   * Assign a fixed random variable stream number to the random variables
   * used by this model.  Return the number of streams (possibly zero) that
   * have been assigned.  The Install() method should have previously been
   * called by the user.
   *
   * \param stream first stream index to use
   * \param c NodeContainer of the set of nodes for which the BsmApplication
   *          should be modified to use a fixed stream
   * \return the number of stream indices assigned by this helper
   */
  int64_t AssignStreams (NodeContainer c, int64_t stream);

  /**
   * \brief Returns the list of moving nove indicators
   * \return the list of moving node indicators
   */
  static std::vector<int>& GetNodesMoving ();

private:
  /**
   * Install an ns3::BsmApplication on the node
   *
   * \param node The node on which an BsmApplication will be installed.
   * \returns Ptr to the application installed.
   */
  Ptr<Application> InstallPriv (Ptr<Node> node) const;

  ObjectFactory m_factory; //!< Object factory.

  static std::vector<int> nodesMoving;
};

} // namespace ns3

#endif /* MBR_NEIGHBOR_HELPER_H*/
