//
//  FireXPCServiceProtocol.swift
//  FireXPCService
//
//  Created by 杨永榜 on 2024/9/10.
//

import Foundation

/// The protocol that this service will vend as its API. This protocol will also need to be visible to the process hosting the service.
@objc public protocol FireXPCServiceProtocol {
    func setMainAppEndpoint(endpoint: NSXPCListenerEndpoint, with reply: @escaping (Int) -> Void)
    
    func getMainAppEndpoint(with reply: @escaping (NSXPCListenerEndpoint) -> Void)
}

/*
 To use the service from an application or other process, use NSXPCConnection to establish a connection to the service by doing something like this:

     connectionToService = NSXPCConnection(serviceName: "com.qwertyyb.inputmethod.Fire.FireXPCService")
     connectionToService.remoteObjectInterface = NSXPCInterface(with: FireXPCServiceProtocol.self)
     connectionToService.resume()

 Once you have a connection to the service, you can use it like this:

     if let proxy = connectionToService.remoteObjectProxy as? FireXPCServiceProtocol {
         proxy.performCalculation(firstNumber: 23, secondNumber: 19) { result in
             NSLog("Result of calculation is: \(result)")
         }
     }

 And, when you are finished with the service, clean up the connection like this:

     connectionToService.invalidate()
*/
