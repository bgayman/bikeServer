//
//  GBFSSystemInformation.swift
//  BikeShare
//
//  Created by Brad G. on 2/9/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import Foundation

struct GBFSSystemInformation
{
    static let dateFormatter: DateFormatter =
    {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "y-MM-dd"
        return dateFormatter
    }()
    
    let systemID: String
    let language: String?
    let name: String
    let shortName: String?
    let `operator`: String?
    let url: URL?
    let purchaseURL: URL?
    let startDate: Date?
    let phoneNumber: String?
    let email: String?
    let licenseURL: URL?
    let timeZone: String
    
    var jsonDict: JSONDictionary
    {
        var jsonDict = ["system_id": self.systemID,
                        "name": self.name,
                        "timezone": self.timeZone]
        if let language = self.language
        {
            jsonDict["language"] = language
        }
        if let shortName = self.shortName
        {
            jsonDict["short_name"] = shortName
        }
        if let `operator` = self.operator
        {
            jsonDict["operator"] = `operator`
        }
        if let url = self.url?.absoluteString
        {
            jsonDict["url"] = url
        }
        if let purchaseURL = self.purchaseURL?.absoluteString
        {
            jsonDict["purchase_url"] = purchaseURL
        }
        if let date = self.startDate
        {
            jsonDict["state_date"] = GBFSSystemInformation.dateFormatter.string(from: date)
        }
        if let phoneNumber = self.phoneNumber
        {
            jsonDict["phone_number"] = phoneNumber
        }
        if let email = self.email
        {
            jsonDict["email"] = email
        }
        return jsonDict
    }
}

extension GBFSSystemInformation
{
    init?(json: JSONDictionary)
    {
        guard let systemID = json["system_id"] as? String,
              let name = json["name"] as? String,
              let timeZone = json["timezone"] as? String
        else { return nil }
        self.systemID = systemID
        self.language = json["language"] as? String
        self.name = name
        self.shortName = json["short_name"] as? String
        self.timeZone = timeZone
        self.operator = json["operator"] as? String
        if let urlString = json["url"] as? String
        {
            let secureString = urlString.replacingOccurrences(of: "http:", with: "https:")
            self.url = URL(string: secureString)
        }
        else
        {
            self.url = nil
        }
        if let purchaseURLString = json["purchase_url"] as? String
        {
            let secureString = purchaseURLString.replacingOccurrences(of: "http:", with: "https:")
            self.purchaseURL = URL(string: secureString)
        }
        else
        {
            self.purchaseURL = nil
        }
        if let startDateString = json["start_date"] as? String
        {
            self.startDate = GBFSSystemInformation.dateFormatter.date(from: startDateString)
        }
        else
        {
            self.startDate = nil
        }
        self.phoneNumber = json["phone_number"] as? String
        self.email = json["email"] as? String
        if let licenseURLString = json["license_url"] as? String
        {
            let secureString = licenseURLString.replacingOccurrences(of: "http:", with: "https:")
            self.licenseURL = URL(string: secureString)
        }
        else
        {
            self.licenseURL = nil
        }
    }
}
