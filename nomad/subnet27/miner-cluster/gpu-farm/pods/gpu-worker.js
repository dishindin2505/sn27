importScripts('path/to/gpu.js');
socket.on('message', function(msg) {
  if (isValidMessage(msg)) {
      sockets.forEach(s => {
          if (s !== socket && s.readyState === WebSocket.OPEN) {
              onmessage = function() {
                // define gpu instance
                const gpu = new GPU();
              
                // input values
                const a = [1,2,3];
                const b = [3,2,1];
              
                // setup kernel
                const kernel = gpu.createKernel(function(a, b) {
                  return a[this.thread.x] - b[this.thread.x];
                })
                  .setOutput([3]);
              
                // output some Nuemric result + stream real time abck to client!
                s.send(kernel(a, b));
              };
          }
      });
  } else {
      console.error('Invalid message received:', msg);
  }
});