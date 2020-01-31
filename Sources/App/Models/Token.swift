//
//  Toke n.swift
//  App
//
//  Created by Ben Schultz on 1/30/20.
//

import Foundation
import FluentMySQL
import Vapor
import JWT

struct Token: JWTPayload {
    var user: UserJWTInfo
    var exp: Date
    var ip: String?
    
    // TODO: implement verify
    func verify(using signer: JWTSigner) throws {
        // nothing to verify yet
    }
}
