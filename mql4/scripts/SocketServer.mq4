/**
 * Socket-Server (by JJC)
 *
 * For a bit of fun... the following script accepts multiple concurrent TCP/IP connections, and writes incoming CR-delimited messages to the Experts log.
 * For example, once the script is running you can connect via Telnet (to port 51234 by default), and each line of text which you type in will be printed.
 *
 * @see https://forum.mql4.com/73886/page2#1041511
 */
#property strict
#property show_inputs

// ---------------------------------------------------------------------
// User-configurable parameters
// ---------------------------------------------------------------------

input int PortNumber = 51234; // TCP/IP port number

// ---------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------

// Size of temporary buffer used to read from client sockets
#define SOCKET_READ_BUFFER_SIZE 10000

// ---------------------------------------------------------------------
// Forward definitions of classes
// ---------------------------------------------------------------------

// Wrapper around a connected client socket
class Connection;

// ---------------------------------------------------------------------
// Winsock structure definitions and DLL imports
// ---------------------------------------------------------------------

struct sockaddr_in {
   short af_family;
   short port;
   int addr;
   int dummy1;
   int dummy2;
};

struct timeval {
   int secs;
   int usecs;
};

struct fd_set {
   int count;
   int single_socket;
   int dummy[63];
};

#import "Ws2_32.dll"
   int socket(int, int, int);
   int bind(int, sockaddr_in&, int);
   int htons(int);
   int listen(int, int);
   int accept(int, int, int);
   int closesocket(int);
   int select(int, fd_set&, int, int, timeval&);
   int recv(int, uchar&[], int, int);
   int WSAGetLastError();
#import


// ---------------------------------------------------------------------
// Global variables
// ---------------------------------------------------------------------

// Handle of main listening server socket
int ServerSocket;

// List of currently connected clients
Connection * Clients[];



// ---------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------

void OnStart()
{
   if (!TerminalInfoInteger(TERMINAL_DLLS_ALLOWED)) {Print("Requires \'Allow DLL imports\'");return;}

   // (Don't need to call WSAStartup because MT4 must have done this)

   // Create the main server socket
   ServerSocket = socket(2 /* AF_INET */, 1 /* SOCK_STREAM */, 6 /* IPPROTO_TCP */);
   if (ServerSocket == -1) {Print("ERROR " , WSAGetLastError() , " in socket creation");return;}

   // Bind the socket to the specified port number. In this example,
   // we only accept connections from localhost
   sockaddr_in service;
   service.af_family = 2 /* AF_INET */;
   service.addr = 0x100007F; // equivalent to inet_addr("127.0.0.1")
   service.port = (short)htons(PortNumber);
   if (bind(ServerSocket, service, 16 /* sizeof(service) */) == -1) {Print("ERROR " , WSAGetLastError() , " in socket bind");return;}

   // Put the socket into listening mode
   if (listen(ServerSocket, 0) == -1) {Print("ERROR " , WSAGetLastError() , " in socket listen");return;}


   // Listening loop, which continues until Remove Script is used
   timeval waitfor;
   waitfor.secs = 0;
   waitfor.usecs = 0;

   while (!IsStopped()) {
      // .........................................................
      // Do we have a new pending connection on the server socket?
      fd_set PollServerSocket;
      PollServerSocket.count = 1;
      PollServerSocket.single_socket = ServerSocket;

      int selres = select(0, PollServerSocket, 0, 0, waitfor);
      if (selres > 0) {

         Print("New incoming connection...");
         int NewClientSocket = accept(ServerSocket, 0, 0);
         if (NewClientSocket == -1) {
            Print("ERROR " , WSAGetLastError() , " in socket accept");

         } else {
            Print("...accepted");

            int ctarr = ArraySize(Clients);
            ArrayResize(Clients, ctarr + 1);
            Clients[ctarr] = new Connection(NewClientSocket);
            Print("Got connection to client ", Clients[ctarr].GetID());
         }
      }

      // .........................................................
      // Process any incoming data from client connections
      // (including any which have just been accepted, above)
      int ctarr = ArraySize(Clients);
      for (int i = ctarr - 1; i >= 0; i--) {
         // Return value from ReadAnyPendingData() is true
         // if the socket still seems to be alive; false if
         // the connection seems to have been closed, and should be discarded
         if (Clients[i].ReadAnyPendingData()) {
            // Socket still seems to be alive

         } else {
            // Socket appears to be dead. Delete, and remove from list
            Print("Lost connection to client ", Clients[i].GetID());

            delete Clients[i];
            for (int j = i + 1; j < ctarr; j++) {
               Clients[j - 1] = Clients[j];
            }
            ctarr--;
            ArrayResize(Clients, ctarr);
         }
      }

      Sleep(10); // Sleep(1) appears to be a little too aggressive in this context
   }
}

// ---------------------------------------------------------------------
// Termination (could do this at the end of OnStart() instead.
// It's just a little clearer to do it here
// ---------------------------------------------------------------------

void OnDeinit(const int reason)
{
   closesocket(ServerSocket);

   for (int i = 0; i < ArraySize(Clients); i++) {
      delete Clients[i];
   }
}


// ---------------------------------------------------------------------
// Simple wrapper around each connected client socket
// ---------------------------------------------------------------------

class Connection {
private:
   // Client socket handle
   int mSocket;

   // Temporary buffer used to handle incoming data
   uchar mTempBuffer[SOCKET_READ_BUFFER_SIZE];

   // Stored-up data, waiting for a \r character
   string mPendingData;

public:
   Connection(int ClientSocket) {mSocket = ClientSocket; mPendingData = "";}
   ~Connection() {closesocket(mSocket);}
   string GetID() {return IntegerToString(mSocket);}

   bool ReadAnyPendingData();
};

// Called repeatedly on a timer from OnStart(), to check whether any
// data is available on this client connection. Returns true if the
// client still seems to be connected (*not* if there's new data);
// returns false if the connection seems to be dead.
bool Connection::ReadAnyPendingData()
{
   // Check the client socket for data-readability
   timeval waitfor;
   waitfor.secs = 0;
   waitfor.usecs = 0;

   fd_set PollClientSocket;
   PollClientSocket.count = 1;
   PollClientSocket.single_socket = mSocket;

   int selres = select(0, PollClientSocket, 0, 0, waitfor);
   if (selres > 0) {

      // Winsock says that there is data waiting to be read on this socket
      int res = recv(mSocket, mTempBuffer, SOCKET_READ_BUFFER_SIZE, 0);
      if (res > 0) {
         // Convert the buffer to a string, and add it to any pending
         // data which we already have on this connection
         string strIncoming = CharArrayToString(mTempBuffer, 0, res);
         mPendingData += strIncoming;

         // Do we have a complete message (or more than one) ending in \r?
         int idxTerm = StringFind(mPendingData, "\r");
         while (idxTerm >= 0) {
            if (idxTerm > 0) {
               string strMsg = StringSubstr(mPendingData, 0, idxTerm);

               // Print the \r-terminated message in the log
               Print("#" , GetID() , ": " , strMsg);
            }

            // Keep looping until we have extracted all the \r delimited
            // messages, and leave any residue in the pending data
            mPendingData = StringSubstr(mPendingData, idxTerm + 1);
            idxTerm = StringFind(mPendingData, "\r");
         }

         return true;

      } else {
         // recv() failed. Assume socket is dead
         return false;
      }

   } else if (selres == -1) {
      // Assume socket is dead
      return false;

   } else {
      // No pending data
      return true;
   }
}
