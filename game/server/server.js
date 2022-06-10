const http = require('http');
const msgpack = require('msgpackr');
const net = require('net');
var Packr = msgpack.Packr
//const enetjs = require("enet-js");

const { MongoClient } = require('mongodb');
// or as an es module:
// import { MongoClient } from 'mongodb'

// Connection URL
const url = 'mongodb://localhost:27017';


//const enet = require("enet");
const hostname = '127.0.0.1';
const tcpport = 7071;

function start_tcp_server(){

}
let sockets = [];
const tcpserver = net.createServer();
tcpserver.listen(tcpport, hostname, () => {
    console.log('TCP Server is running on port ' + tcpport +'.');
});

tcpserver.on('connection', function(sock) {
    console.log('CONNECTED: ' + sock.remoteAddress + ':' + sock.remotePort);
    sockets.push(sock);

    sock.on('data', function(data) {
        console.log('DATA ' + sock.remoteAddress + ': ' + data);
        let structures = []
        let packr = new Packr({ structures,largeBigIntToFloat : true,int64AsNumber : true })
        //var serialized = packr.pack(data)
        var deserialized = packr.unpack(data)
        console.log(deserialized)
/*
        insert(deserialized)
          .then(console.log)
          .catch(console.error)
          .finally(() => client.close());
        // Write the data back to all the connected, the client will receive it as data from the server
        sockets.forEach(function(sock, index, array) {
            sock.write(sock.remoteAddress + ':' + sock.remotePort + " said " + data + '\n');
        });
*/
    });

      // When the client requests to end the TCP connection with the server, the server
    // ends the connection.
    sock.on('end', function() {
        console.log('Closing connection with the client');
    });

    // Don't forget to catch error, for your own sake.
    sock.on('error', function(err) {
        console.log(`Error: ${err}`);
    });
});

const client = new MongoClient(url);
const dbName = 'gargame';

async function insert(){
  await client.connect();
  console.log('Connected successfully to server');
  const db = client.db(dbName);
  const collection = db.collection('slots');
const insertResult = await collection.insertMany([{ a: 1 }, { a: 2 }, { a: 3 }]);
console.log('Inserted documents =>', insertResult);
    // the following code examples can be pasted here...
    return 'done.';
}


        insert()
          .then(console.log)
          .catch(console.error)
          .finally(() => client.close());

