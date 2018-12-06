#ifndef MBR_NEIGHBOR_APP_H
#define MBR_NEIGHBOR_APP_H

#include "mbr-header.h"
#include "neighbor.h"
#include "ns3/application.h"

#include "ns3/random-variable-stream.h"
#include "ns3/internet-stack-helper.h"


namespace ns3 {
namespace mbr {

class MbrNeighborApp : public Application
{
public:
	static TypeId GetTypeId (void);

	/**
	* \brief Constructor
	* \return none
	*/
	MbrNeighborApp ();
	virtual ~MbrNeighborApp();

	void Setup (Ipv4InterfaceContainer & i,
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
			  Time txDelay);

	/**
	* Assign a fixed random variable stream number to the random variables
	* used by this model.  Return the number of streams (possibly zero) that
	* have been assigned.  The Install() method should have previously been
	* called by the user.
	*
	* \param stream first stream index to use
	* \return the number of stream indices assigned by this helper
	*/
	int64_t AssignStreams (int64_t streamIndex);

	Neighbors* getNb() const {
		return m_neighbors;
	}

	/**
	* (Arbitrary) port number that is used to create a socket for transmitting WAVE BSMs.
	*/
	static int wavePort;

//  /**
//   * \brief Run
//   * \return none
//   */
//  void Run ();
//
//
//	/**
//	* \brief Gets the topology instance
//	* \return the topology instance
//	*/
//	static MbrNeighbor * GetInstance();
//
//  void Initialize();


protected:
  virtual void DoDispose (void);



private:
  // inherited from Application base class.
  virtual void StartApplication (void);    // Called at time specified by Start
  virtual void StopApplication (void);     // Called at time specified by Stop

  /**
   * \brief Creates and transmits a WAVE BSM packet
   * \param socket socket to use for transmission
   * \param pktSize the size, in bytes, of the WAVE BSM packet
   * \param pktCount the number of remaining WAVE BSM packets to be transmitted
   * \param pktInterval the interval, in seconds, until the next packet
   * should be transmitted
   * \return none
   */
  void GenerateWaveTraffic (Ptr<Socket> socket, uint32_t pktSize,
                            uint32_t pktCount, Time pktInterval,
                            uint32_t sendingNodeId);

  /**
   * \brief Receive a WAVE BSM packet
   * \param socket the receiving socket
   * \return none
   */
  void ReceiveWavePacket (Ptr<Socket> socket);

  /**
   * \brief Handle the receipt of a WAVE BSM packet from sender to receiver
   * \param txNode the sending node
   * \param rxNode the receiving node
   * \return none
   */
  void HandleReceivedBsmPacket (Ptr<Node> txNode,
                                Ptr<Node> rxNode);

  /**
   * \brief Get the node for the desired id
   * \param id the id of the desired node
   * \return ptr to the desired node
   */
  Ptr<Node> GetNode (int id);

  /**
   * \brief Get the net device for the desired id
   * \param id the id of the desired net device
   * \return ptr to the desired net device
   */
  Ptr<NetDevice> GetNetDevice (int id);
  Ptr<NetDevice> GetNetDeviceOfDataInf (int id);

  int m_stop;
  Time m_TotalSimTime;
  uint32_t m_wavePacketSize; // bytes
  uint32_t m_numWavePackets;
  Time m_waveInterval;
  Time m_waveExpire;
  double m_gpsAccuracyNs;
  Ipv4InterfaceContainer * m_beaconInterfaces;
  Ipv4InterfaceContainer * m_dataInterfaces;
  NetDeviceContainer * m_beaconDevices;
  NetDeviceContainer * m_dataDevices;

  std::vector<int> * m_nodesMoving;
  Ptr<UniformRandomVariable> m_unirv;
  int m_nodeId;
  // When transmitting at a default rate of 10 Hz,
  // the subsystem shall transmit every 100 ms +/-
  // a random value between 0 and 5 ms. [MPR-BSMTX-TXTIM-002]
  // Source: CAMP Vehicle Safety Communications 4 Consortium
  // On-board Minimum Performance Requirements
  // for V2V Safety Systems Version 1.0, December 17, 2014
  // max transmit delay (default 10ms)
  Time m_txMaxDelay;
  Time m_prevTxDelay;
  /// Handle neighbors
  Neighbors* m_neighbors;

  /**
   * \brief Get the topology instance (create if necessary)
   * \return the topology instance
   */
//  static MbrNeighbor ** PeekMbrNeighborInstance();
//  void SendHello ();
//
//  /// Raw unicast socket per each IP interface, map socket -> iface address (IP + mask)
//  std::map< Ptr<Socket>, Ipv4InterfaceAddress > m_socketAddresses;

};
} //namespace mbr
} // namespace ns3

#endif  // MBR_NEIGHBOR_APP_H
