package network

import sdl_net "vendor:sdl2/net"
import logger "../../engine/logger"
import fmt "core:fmt"
import msgpack "../external/msgpack"

is_running : bool = true

Socket :: struct{
	socket : sdl_net.TCPsocket,
}

create_connection :: proc() -> (socket : Socket,err : int) {
	using sdl_net
	using fmt
	address : sdl_net.IPaddress
	if Init() == -1{
		println("Could not Init SDL NET.\n")
	}
	
	if ResolveHost(&address, "127.0.0.1", 7071) == -1{
		logger.print_log("Could not resolve host.\n")	
	}

	result : Socket
	result.socket = TCP_Open(&address)

	if result.socket ==  nil{
		println("Could not open socket.\n")	
		return result,-1
	}
	return result,0
}

TestSubStruct :: struct{
	a : i32,
	name : string,
}

TestStruct :: struct{
	name : string,
	amount : i32,
	test : TestSubStruct,
}

send_message :: proc(socket : Socket,data : any,size : int){
    using msgpack
    using sdl_net
    
    //test_struct := TestStruct{"abc",i32(123),TestSubStruct{i32(1234),"DEF"}}
    //write_err := msgpack.write_string(&ctx, "test")
    bytes,err := msgpack.marshal(data, size)
    fmt.println("writer errror : ",err)

	result := TCP_Send(socket.socket, rawptr(&bytes[0]), i32(len(bytes)))
	if int(result) < len(bytes){
		fmt.println("ERROR SENDING MESSAGE")
	}
}

/*
	//for is_running{
	message : cstring = "test"
	result := TCP_Send(socket, rawptr(message), i32(len(message)))
	if int(result) < len(message){
		println("ERROR SENDING MESSAGE")
	}
	//}
*/

