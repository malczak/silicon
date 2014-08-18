# silicon

Simple dependency injection / service locator for Objective-C iOS applications. 

Great if you're tired of over-used singleton pattern.

Silicon advantages
* all application services / models / what-ever-app-needs are defined in a service locator
* all services are lazy initializated when requested and retained
* access any service by name
* use build-in dependency injection to inject services 

## simple usage example

Define service called _apiService_

```objc
Silicon *si = [Silicon si];
[si service:@"apiService" withBlock:^NSObject*(Silicon *si){
 		   NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
           NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
           // custom config
           return session;
        }];
```

Session object will be created when requested for the first time. After creating service instance Silicon uses it in any subsequent requests.

Using defined service

```objc
Silicon *si = [Silicon si];
NSURLSession *api = [si get:@"apiService"]
```