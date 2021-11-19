package server
import enet "vendor:enet"
import fmt "core:fmt"
import con "../../engine/containers"
import msgpack "../../engine/external/msgpack"
import network "../../engine/network"

import mem "core:mem"

Spin :: struct{
	user_id : u64,
	game_id : u64,
	bet_amount : i32,
	
}

SpinResult :: struct{
	user_id : u64,
	game_id : u64,
	cash_amount : i32,
	
}

Client :: struct{

}

ClientConnection :: struct{

}

Server :: struct{
	host : ^enet.Host,
	address : enet.Address, 
	is_running : bool,
}	

clients : con.Buffer(Client)

server : Server

buffer : [1024]byte

main :: proc(){
	using fmt
	using enet
	using msgpack
	if initialize() != 0{
		fmt.println("Failed exiting")
		return 
	}

	//buffer := [1024]byte{}

	address_set_host(&server.address, "localhost");

	//server.address.host = HOST_ANY
	server.address.port = 3000
	server.host  = host_create (&server.address /* the address to bind the server host to */, 
                             32      /* allow up to 32 clients and/or outgoing connections */,
                              2      /* allow up to 2 channels to be used, 0 and 1 */,
                              0      /* assume any amount of incoming bandwidth */,
                              0      /* assume any amount of outgoing bandwidth */);
	if (server.host == nil)
	{
	    println("An error occurred while trying to create an ENet server host.\n");
	    return
	}

	//fmt.println("Server started ",server)
	
	fmt.println("Server Starting")
	
	event : Event
	server.is_running = true

	socket,err := network.create_connection()

	//poll
	for server.is_running{
		/* Wait up to 1000 milliseconds for an event. */
		for host_service (server.host, & event, 1000) > 0{
			#partial switch event.type{
				case .CONNECT:{
					println("A new client connected from %x:%u.\n", 
		            event.peer.address.host,
		            event.peer.address.port);
		    		/* Store any relevant client information here. */
		    		data_string : cstring = "Client information"
		    		event.peer.data = rawptr(data_string)
		    		break;
				}
				case .RECEIVE:{
		    		println("A packet of length %u containing %s was received from %s on channel %u.\n",
		            event.packet.dataLength,
		            event.packet.data,
		            event.peer.data,
		            event.channelID);
					
					fmt.println("peer data : ",cstring(event.peer.data))
					//ctx = msgpack.read_context_init(event.packet.data[:event.packet.dataLength])
					read_spin : Spin
    				err := unmarshal(read_spin,event.packet.data[:event.packet.dataLength])
					

					fmt.println(read_spin)
					network.send_message(socket,read_spin,size_of(Spin) + 1024)
    				
    				
    				//logger.print_log("TEST READ STRING ",read_string_m)
					//read_string,err := msgpack.read_string(&ctx)
					if err == .None{
						fmt.println("Read string from network ",read_spin)

					}else{
						check_error(err)
						fmt.println("Read error!")
					}
					
		    	
		    	/* Clean up the packet now that we're done using it. */
		    		packet_destroy (event.packet);
			        break;
		   		}
				case .DISCONNECT:{
		    		printf ("%s disconnected.\n", event.peer.data);
		    		/* Reset the peer's client information. */
		    		event.peer.data = nil;
				}
			}
		}
	}

	fmt.println("Server Shutting down")
}

check_error :: proc(err : msgpack.Read_Error){
	using fmt
	using msgpack

	// errors that can appear while reading
	print (err)
	#partial switch err{
		case .None : {
		}
		case .Bounds_Buffer_Byte :{

		} 
		case .Bounds_Buffer_Byte_Ptr:{

		}
		case .Bounds_Buffer_Advance :{

		} 
		case .Bounds_Buffer_Slice :{

		} 
		case .Wrong_Array_Format :{

		}
		case .Wrong_Map_Format :{

		}
		case .Type_Id_Not_Supported:{

		}
		case .Wrong_Current_Format:{

		}
		case .Unmarshall_Pointer :{

		}
	}
}
