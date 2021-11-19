package server
import fmt "core:fmt"
import enet "vendor:enet"
import strings "core:strings"
import msgpack "../../engine/external/msgpack"
import logger "../../engine/logger"

NUM_CHANNELS : uint= 5//?

host_ : ^enet.Host

network_init :: proc(){
    using enet 
    using fmt

    // initialize enet
    // TODO: prevent this from being called multiple times
    if initialize() != 0{
        println("An error occurred while initializing ENet");
        return
    }
    
    // create a host
    host_ = host_create(
        nil, // create a client host
        1, // only allow 1 outgoing connection
        NUM_CHANNELS, // allow up to N channels to be used
        0, // assume any amount of incoming bandwidth
        0); // assume any amount of outgoing bandwidth
    // check if creation was successful
    // NOTE: this only fails if malloc fails inside `enet_host_create`
    if host_ == nil {
        println("An error occurred while trying to create an ENet client host");
    }
}

server_ : ^enet.Peer
TIMEOUT_MS : u32 = 1000

connect :: proc(host : cstring , port : u16) -> bool{
using fmt
using enet
    if is_connected(){
        println("ENetClient is already connected to a server");
        return false
    }
    // set address to connect to
    address : Address 
    address_set_host(&address, host)
    address.port = port
    // initiate the connection, allocating the two channels 0 and 1.
    server_ = host_connect(host_, &address, NUM_CHANNELS, 0)
    if server_ == nil {
        println("No available peers for initiating an ENet connection");
        return true
    }
    // attempt to connect to the peer (server)
    event : Event
    // wait N for connection to succeed
    // NOTE: we don't need to check / destroy packets because the server will be
    // unable to send the packets without first establishing a connection
    if host_service(host_, &event, TIMEOUT_MS) > 0 && event.type == .CONNECT {
        // connection successful
        println("Connection to ", host ,":" ,port ,"succeeded")
        return false
    }
    // failure to connect
    println("Connection to " , host , ":" , port , " failed")
    peer_reset(server_)
    server_ = nil
    return true
}

is_connected :: proc() -> bool{
    return host_.connectedPeers > 0;
}

send_message :: proc(type : enet.PacketFlag, message : any,size : int){
    using enet
    using msgpack

     channel : u32= 0
     flags : u32 = 0
    if type == .RELIABLE {
        channel = 0//RELIABLE_CHANNEL;
        flags = u32(PacketFlag.RELIABLE)
    } else {
        channel = 0//UNRELIABLE_CHANNEL;
        flags = u32(PacketFlag.UNSEQUENCED)
    }
    m_bytes,m_err := msgpack.marshal(message, size + 1024)
    logger.print_log("writer errror : ",m_err)
    
    // create the packet
    p := packet_create(
            &m_bytes[0],
            len(m_bytes),
            flags);

    // send the packet to the peer
    peer_send(server_, u8(channel), p);
    // flush / send the packet queue
    host_flush(host_);
}