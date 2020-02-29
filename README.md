# WebServer
A webserver I built to learn Objective-C, implemented using BSD's POSIX socket APIs and utilizing Grand Central
Dispatch for multithreading.

The routing API is heavily inspired by [Express.js](https://expressjs.com/) (my actual preference for building web applications)
and the repository also includes a very basic simple ncurses-based CLI.

<img width="682" alt="image" src="https://user-images.githubusercontent.com/37072691/75615567-2596e480-5b3d-11ea-8395-0859489698cc.png">

```objc
[server on:GET path:@"/" execute:^(Request* request, Response* response){
    [response append:@"<p>hi</p>"];
}];
```
