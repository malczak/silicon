# silicon

Simple dependency injection / service locator for Swift applications

Great if you're tired of over-used singleton pattern.

Silicon advantages
* all application services / models / what-ever-app-needs are defined in a service locator
* all services are lazy initializated when requested and retained
* access any service by name
* use build-in dependency injection to inject services 

## simple usage example

Define service called _apiService_

```swift

// each call to 'get("myService")' will create a new instance of 'MyServiceImpl' class

Silicon.set("myService", shared:false) { (si) in
    let o = MySerivceImpl()
    o.setupInstance()
    return o
};

// this instance will be shared but only twice

Silicon.set("mySharedService", shared:true, count: 2) { (si) in
    let o = MySerivceImpl()
    o.setupInstance()
    return o
};


```

Session object will be created when requested for the first time. After creating service instance Silicon uses it in any subsequent requests.

Using defined service

```objc

// get two different instances of 'myService'

let instance1 = Silicon.get('myService')
let instance2 = Silicon.get('myService')

// in example below both 'shared1' and 'shared2' are pointing to the same instance

let shared1 = Silicon.get('mySharedService')
let shared2 = Silicon.get('mySharedService')

// any following calls for 'mySharedService' will result in nill - service availability was set only to 2

let shared3 = Silicon.get('mySharedService')

```