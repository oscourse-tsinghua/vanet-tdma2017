#include "satmac-packet.h"
#include "tdma-satmac.h"

#include "ns3/address-utils.h"
#include "ns3/packet.h"
#include "ns3/log.h"

NS_LOG_COMPONENT_DEFINE ("SatmacPacket");

namespace ns3 {
namespace satmac {

NS_OBJECT_ENSURE_REGISTERED (TypeHeader);

TypeHeader::TypeHeader (MessageType t = SATMACTYPE_FI)
  : m_type (t),
    m_valid (true)
{
}

TypeId
TypeHeader::GetTypeId ()
{
  static TypeId tid = TypeId ("ns3::sastmac::TypeHeader")
    .SetParent<Header> ()
    .AddConstructor<TypeHeader> ()
  ;
  return tid;
}

TypeId
TypeHeader::GetInstanceTypeId () const
{
  return GetTypeId ();
}

uint32_t
TypeHeader::GetSerializedSize () const
{
  return 1;
}

void
TypeHeader::Serialize (Buffer::Iterator i) const
{
  i.WriteU8 ((uint8_t) m_type);
}

uint32_t
TypeHeader::Deserialize (Buffer::Iterator start)
{
  Buffer::Iterator i = start;
  uint8_t type = i.ReadU8 ();
  m_valid = true;

  m_type = (MessageType) type;

  uint32_t dist = i.GetDistanceFrom (start);
  NS_ASSERT (dist == GetSerializedSize ());
  return dist;
}

void
TypeHeader::Print (std::ostream &os) const
{
  switch (m_type)
    {
    case SATMACTYPE_FI:
      {
        os << "FI";
        break;
      }
    default:
      os << "UNKNOWN_TYPE";
    }
}

bool
TypeHeader::operator== (TypeHeader const & o) const
{
  return (m_type == o.m_type && m_valid == o.m_valid);
}

std::ostream &
operator<< (std::ostream & os, TypeHeader const & h)
{
  h.Print (os);
  return os;
}

//-----------------------------------------------------------------------------
// FI
//-----------------------------------------------------------------------------
FiHeader::FiHeader ()
{
}

NS_OBJECT_ENSURE_REGISTERED (FiHeader);

FiHeader::FiHeader (uint32_t framelength, int global_sti, slot_tag *fi_local)
	:m_framelength(framelength), m_global_sti(global_sti)
{
	uint32_t  field_length;
	uint8_t buffer;
	int bit_pos=7, byte_pos=0;
	m_fi_size = (BIT_LENGTH_SLOT_TAG * m_framelength + BIT_LENGTH_STI + BIT_LENGTH_FRAMELEN)/8;
	if(((BIT_LENGTH_SLOT_TAG * m_framelength + BIT_LENGTH_STI + BIT_LENGTH_FRAMELEN) %8) != 0 ){
	  m_fi_size++;
	}

	m_buffer = new unsigned char[m_fi_size];
	memset(m_buffer, 0, m_fi_size);
	
	field_length = BIT_LENGTH_STI/8 ;
	
	if ( BIT_LENGTH_STI%8 != 0 ){
		buffer = (unsigned char)(m_global_sti>>( 8* field_length ));
		setvalue(buffer, BIT_LENGTH_STI%8, m_buffer, byte_pos, bit_pos);
	}
	
	for(int j = field_length-1 ; j >= 0 ; j-- ){
		buffer = (unsigned char)(m_global_sti>>(8*j));
		setvalue(buffer, 8, m_buffer, byte_pos, bit_pos);
	}
	
	//frame len 4 bits
	buffer = log(m_framelength)/log(2);
	setvalue(buffer, BIT_LENGTH_FRAMELEN, m_buffer, byte_pos, bit_pos);
	
	for(int i=0; i< m_framelength; i++){
		buffer = fi_local[i].busy;
		setvalue(buffer, BIT_LENGTH_BUSY, m_buffer, byte_pos, bit_pos);
		//sti
		field_length = BIT_LENGTH_STI/8 ;
		if ( BIT_LENGTH_STI%8 != 0 ){
			buffer= (unsigned char)(fi_local[i].sti>>( 8* field_length ));
			setvalue(buffer, BIT_LENGTH_STI%8, m_buffer, byte_pos, bit_pos);
		}
		for(int j = field_length-1 ; j >= 0 ; j-- ){
			buffer =(unsigned char)(fi_local[i].sti>>(8*j));
			setvalue(buffer, 8, m_buffer, byte_pos, bit_pos);
		}
		//count
		unsigned char tmpbitmask = 0xff;
		tmpbitmask = ~((tmpbitmask >> BIT_LENGTH_COUNT)<<BIT_LENGTH_COUNT);
		if (fi_local[i].count_2hop > tmpbitmask)
			buffer = tmpbitmask;
		else
			buffer = (unsigned char)fi_local[i].count_2hop;
		setvalue(buffer, BIT_LENGTH_COUNT, m_buffer, byte_pos, bit_pos);
	
		//PSF
		buffer = fi_local[i].psf;
		if (BIT_LENGTH_PSF > 0)
			setvalue(buffer, BIT_LENGTH_PSF, m_buffer, byte_pos, bit_pos);
	
		//clear Count_2hop/3hop
		if (fi_local[i].sti == m_global_sti) {
			fi_local[i].count_2hop = 1;
			fi_local[i].count_3hop = 1;
		} else {
			fi_local[i].c3hop_flag = 0;
			fi_local[i].count_2hop = 0;
			fi_local[i].count_3hop = 0;
		}
	}

}

TypeId
FiHeader::GetTypeId ()
{
  static TypeId tid = TypeId ("ns3::satmac::FiHeader")
    .SetParent<Header> ()
    .AddConstructor<FiHeader> ()
  ;
  return tid;
}

TypeId
FiHeader::GetInstanceTypeId () const
{
  return GetTypeId ();
}

uint32_t
FiHeader::GetSerializedSize () const
{
  return m_fi_size;
}

uint8_t * FiHeader::GetBuffer() const {
  return m_buffer;
};

void FiHeader::setvalue(unsigned char value,
		int bit_len, unsigned char* buffer, int &byte_pos, int &bit_pos){

	int shift=0,field_length=0,mode=0,i=0,bit_remain;
	int index;

	index = byte_pos;
	field_length = bit_len;
	bit_remain = bit_pos+1;

	NS_ASSERT(bit_pos >= 0);
	NS_ASSERT(bit_len >= 1);

	while(true){

		mode = 0;

		if(bit_remain==0){
			bit_remain=8;
			index++;
		}

		if(field_length<=0)	break;

		if (bit_remain >= field_length){
			shift = bit_remain-field_length;
			for(i=0; i<field_length; i++){
				mode += pow(2,i);
			}
			bit_remain = shift;
			field_length=0;
		}
		else{
			shift = 0;
			for(i=0; i<bit_remain; i++){
				mode += pow(2,i);
			}
			field_length -= bit_remain;
			bit_remain = 0;
		}
		buffer[index] |= (( value >> field_length ) & mode ) << shift;
	}

	byte_pos=index;
	bit_pos = bit_remain-1;
}

unsigned long FiHeader::decode_value(unsigned int &byte_pos,unsigned int &bit_pos, unsigned int length){
	unsigned long mode = 0;
	unsigned long value=0;
	unsigned int i=0,j=0,field_length;
	unsigned int bit_remain,index,shift;

	if (length == 0) return 0;

	index = byte_pos;
	bit_remain = bit_pos+1;
	//field_length = length;

	field_length = length % 8;
	if(field_length !=0){//  should first read the remaining field_length bits
		while(field_length>0){
			if (bit_remain >= field_length){
				mode = 0;
				shift = bit_remain-field_length;
				for(j=0; j< field_length ; j++){
					mode += pow(2,j);
				}
				value =  value | ((m_buffer[index] >> shift ) & mode);
				bit_remain -= field_length;
				if(bit_remain == 0){
					bit_remain =8;
					index++;
				}
				field_length = 0;
			}
			else{
				mode=0;
				shift = 0;
				for(j=0; j< bit_remain ; j++){
					mode += pow(2,j);
				}
				value = value | (( m_buffer[index] >> shift ) & mode ) << (8-bit_remain);
				field_length = field_length-bit_remain;
				bit_remain=8;
				index++;
			}
		}
	}
	for(i=0 ; i< length/8 ; i++){
		field_length=8;
		value = value << 8;
		while(field_length>0){
			if (bit_remain >= field_length){
				mode = 0;
				shift = bit_remain-field_length;
				for(j=0; j< field_length ; j++){
					mode += pow(2,j);
				}
				value = value | ((m_buffer[index] >> shift ) & mode);
				bit_remain -= field_length;
				if(bit_remain == 0){
					bit_remain =8;
					index++;
				}
				field_length = 0;
			}
			else{
				mode=0;
				shift = 0;
				for(j=0; j< bit_remain ; j++){
					mode += pow(2,j);
				}
				value = value | (( m_buffer[index] >> shift ) & mode ) << (8-bit_remain);
				field_length = field_length-bit_remain;
				bit_remain=8;
				index++;
			}
		}
	}

	byte_pos = index;
	bit_pos = bit_remain-1;

	return value;
}

void FiHeader::decode_slot_tag(unsigned int &byte_pos,unsigned int &bit_pos, int slot_pos, Frame_info *fi){
	unsigned long value=0;

	slot_tag* fi_local=fi->slot_describe;
	NS_ASSERT(bit_pos >= 0);
	//busy
	value=this->decode_value(byte_pos,bit_pos,BIT_LENGTH_BUSY);
	fi_local[slot_pos].busy = (unsigned char)value;

	//sti
	value=this->decode_value(byte_pos,bit_pos,BIT_LENGTH_STI);
	fi_local[slot_pos].sti = (unsigned int)value;

	//count
	value=this->decode_value(byte_pos,bit_pos,BIT_LENGTH_COUNT);
	fi_local[slot_pos].count_2hop = (unsigned int)value;

	//psf
	value=this->decode_value(byte_pos,bit_pos,BIT_LENGTH_PSF);
	fi_local[slot_pos].psf = (unsigned int)value;

	return;
}


void
FiHeader::Serialize (Buffer::Iterator i) const
{
  i.Write(m_buffer, m_fi_size);
}

uint32_t
FiHeader::Deserialize (Buffer::Iterator start)
{
  Buffer::Iterator i = start;
  int buf_size = i.GetSize();
  m_buffer = new unsigned char [buf_size];
  i.Read(m_buffer, buf_size);
  
  uint32_t dist = i.GetDistanceFrom (start);
  return dist;
}

void
FiHeader::Print (std::ostream &os) const
{

}

std::ostream &
operator<< (std::ostream & os, FiHeader const & h)
{
  h.Print (os);
  return os;
}



bool
FiHeader::operator== (FiHeader const & o) const
{
  return 0;
}


}
}




