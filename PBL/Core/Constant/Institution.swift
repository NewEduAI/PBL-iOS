//
//  Institution.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/1/21.
//

import Foundation

struct Institution {
    let name: String
    let baseUrl: String
    let emailDomains: [String]
}

let tsinghuaInstitution = Institution(
    name: "清华大学",
    baseUrl: "https://assignment.maic.chat/api",
//    baseUrl: "http://8.130.106.106:8101/api",
    emailDomains: [
        "mails.tsinghua.edu.cn",
        "tsinghua.edu.cn"
    ]
)

struct InstitutionList {
    static let institutions: [Institution] = [
        tsinghuaInstitution
    ]
    
    static let defaultInstitution = tsinghuaInstitution


    static func fromEmailDomain(_ emailDomain: String) -> Institution? {
        for institution in institutions {
            if institution.emailDomains.contains(emailDomain) {
                return institution
            }
        }
        return nil
    }

    static func baseURL(for emailDomain: String) -> String {
        return fromEmailDomain(emailDomain)?.baseUrl ?? defaultInstitution.baseUrl
    }
}
