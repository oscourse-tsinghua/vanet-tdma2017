/* -*- Mode:C++; c-file-style:"gnu"; indent-tabs-mode:nil; -*- */
/*
 * Copyright (c) 2009 IITP RAS
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
 * Based on
 *      NS-2 AODV model developed by the CMU/MONARCH group and optimized and
 *      tuned by Samir Das and Mahesh Marina, University of Cincinnati;
 *
 *      AODV-UU implementation by Erik Nordström of Uppsala University
 *      http://core.it.uu.se/core/index.php/AODV-UU
 *
 * Authors: Elena Buchatskaia <borovkovaes@iitp.ru>
 *          Pavel Boyko <boyko@iitp.ru>
 */
#ifndef MBRHEADER_H
#define MBRHEADER_H

#include <iostream>
#include "ns3/header.h"
#include "ns3/enum.h"
#include "ns3/ipv4-address.h"
#include <map>
#include "ns3/nstime.h"

namespace ns3 {
namespace mbr {


/**
* \ingroup mbr
* \brief MBR hello packet header
  \verbatim
  0                   1                   2                   3
  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |     Type      |R|A|    Reserved     |Prefix Sz|   Hop Count   |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                     Destination IP address                    |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                  Destination Sequence Number                  |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                    Originator IP address                      |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                           Lifetime                            |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                                                        		  |
  +							geohash								  +
  |                                                               |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |     mac0      |     mac1      |     mac2      |     mac3      |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |     mac4      |     mac5      |     	direction      		  |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                           latitude                            |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                           longitude                           |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  \endverbatim
*/
class MbrHeader : public Header
{
public:
  /// c-tor
	MbrHeader (uint8_t prefixSize = 0, uint8_t hopCount = 0, Ipv4Address dst =
                Ipv4Address (), uint32_t dstSeqNo = 0, Ipv4Address origin =
                Ipv4Address (), Time lifetime = MilliSeconds (0),
				uint64_t geohash=0, uint8_t *mac = NULL, uint16_t direction=0,
				float latitude=0, float longitude=0.0);
  // Header serialization/deserialization
  static TypeId GetTypeId ();
  TypeId GetInstanceTypeId () const;
  uint32_t GetSerializedSize () const;
  void Serialize (Buffer::Iterator start) const;
  uint32_t Deserialize (Buffer::Iterator start);
  void Print (std::ostream &os) const;

  // Fields
  void SetHopCount (uint8_t count) { m_hopCount = count; }
  uint8_t GetHopCount () const { return m_hopCount; }
  void SetDst (Ipv4Address a) { m_dst = a; }
  Ipv4Address GetDst () const { return m_dst; }
  void SetDstSeqno (uint32_t s) { m_dstSeqNo = s; }
  uint32_t GetDstSeqno () const { return m_dstSeqNo; }
  void SetOrigin (Ipv4Address a) { m_origin = a; }
  Ipv4Address GetOrigin () const { return m_origin; }
  void SetLifeTime (Time t);
  Time GetLifeTime () const;



  // Flags
  void SetAckRequired (bool f);
  bool GetAckRequired () const;
  void SetPrefixSize (uint8_t sz);
  uint8_t GetPrefixSize () const;

  /// Configure RREP to be a Hello message
  void SetHello (Ipv4Address src, uint32_t srcSeqNo, Time lifetime);

  bool operator== (MbrHeader const & o) const;

	uint16_t getDirection() const {
		return m_direction;
	}

	void setDirection(uint16_t direction) {
		m_direction = direction;
	}

	uint64_t getGeohash() const {
		return m_geohash;
	}

	void setGeohash(uint64_t geohash) {
		m_geohash = geohash;
	}

	float getLatitude() const {
		return m_latitude;
	}

	void setLatitude(float latitude) {
		m_latitude = latitude;
	}

	float getLongitude() const {
		return m_longitude;
	}

	void setLongitude(float longitude) {
		m_longitude = longitude;
	}

	const uint8_t* getMac() const {
		return m_mac;
	}

private:
  uint8_t       m_flags;                  ///< A - acknowledgment required flag
  uint8_t       m_prefixSize;         ///< Prefix Size
  uint8_t             m_hopCount;         ///< Hop Count
  Ipv4Address   m_dst;              ///< Destination IP Address
  uint32_t      m_dstSeqNo;         ///< Destination Sequence Number
  Ipv4Address     m_origin;           ///< Source IP Address

  uint64_t		m_geohash;
  uint8_t 		m_mac[6];
  uint16_t		m_direction;
  float		m_latitude;
  float		m_longitude;

  uint32_t      m_lifeTime;         ///< Lifetime (in milliseconds)
};

std::ostream & operator<< (std::ostream & os, MbrHeader const &);


}
}
#endif /* MBRHEADER_H */
