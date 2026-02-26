//
//  Main.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/1/21.
//

class API {
    let user: UserAPI
    
    init(baseUrl: String){
        self.user = UserAPI(baseURL: baseUrl)
    }
}
