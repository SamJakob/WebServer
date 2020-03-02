# WebServer

![https://github.com/SamJakob/WebServer/tree/master/LICENSE](https://img.shields.io/github/license/SamJakob/WebServer) ![https://github.com/SamJakob/WebServer/issues](https://img.shields.io/github/issues/SamJakob/WebServer)

An Objective-C WebServer with WebSockets support implemented using BSD's POSIX socket APIs and utilizing Grand Central Dispatch for multithreading.

The routing API is heavily inspired by [Express.js](https://expressjs.com/) (my actual preference for building web applications)
and the repository also includes a very basic simple ncurses-based CLI.

<img width="682" alt="image" src="https://user-images.githubusercontent.com/37072691/75615567-2596e480-5b3d-11ea-8395-0859489698cc.png">

```objc
[server on:GET path:@"/" execute:^(Request* request, Response* response){
    [response append:@"<p>hi</p>"];
}];
```

```objc
[server onWebSocketConnection:@"/echo" execute:^(Request* request, WebSocket* socket){

  [socket onMessage:^(NSString* message){
    // Simply sends the recieved message back to the client.
    [socket sendString:message];
  }];

}];
```



## Features

- Fast and lightweight.
- Fully asynchronous handlers for HTTP requests.
- Supports CRUD methods (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`).
- Express.js-derived API emphasizing readability.
- IPv4 support.
- WebSocket support out of the box.

