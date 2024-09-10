//
//  FireXPCService.swift
//  FireXPCService
//
//  Created by 杨永榜 on 2024/9/10.
//

import Foundation

/// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
public class FireXPCService: NSObject, FireXPCServiceProtocol {
    public func getMainAppEndpoint(with reply: @escaping (NSXPCListenerEndpoint) -> Void) {
        reply(self.mainAppEndpoint!)
    }
    
    var mainAppEndpoint: NSXPCListenerEndpoint?
    public func setMainAppEndpoint(endpoint: NSXPCListenerEndpoint, with reply: @escaping (Int) -> Void) {
        self.mainAppEndpoint = endpoint
        reply(0)
    }
}
