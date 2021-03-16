package platform;

import windows "core:sys/windows"
import window32 "core:sys/win32"

import intrin "core:intrinsics"

TicketMutex :: struct
{
    ticket : i64,
    serving : i64,
}

atomic_add64 :: proc(value : ^i64/*volatile*/,amount : i64)-> i64
{
//    dest := value;
    
//#if IOS || OSX
//    result = __sync_fetch_and_add((s64* volatile)value,(s64)amount);
    //#elif WINDOWS

    result := intrin.atomic_add(value,amount);    
//     result := window32.interlocked_exchange_add64;
//    result := InterlockedExchangeAdd64(value,amount);    
//#endif
    return result;
}

ticket_mutex_begin :: proc(mutex : ^TicketMutex)
{
    ticket : i64 = atomic_add64(&mutex.ticket,1);
//#if IOS
//    while(ticket != mutex.serving){__asm__ __volatile__("yield");};
//#else
    for ;;
    {
	//	if ticket != mutex.serving {window32.mm_pause();}
	if ticket != mutex.serving {intrin.cpu_relax();}	
	else {break};	
    }
    
//#endif    
}

ticket_mutex_end :: proc(mutex : ^TicketMutex)
{
    atomic_add64(&mutex.serving,1);    
}
