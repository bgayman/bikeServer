//
//  GBFSSystemPricingPlan.swift
//  BikeShare
//
//  Created by Brad G. on 2/12/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import Foundation

struct GBFSSystemPricingPlan
{
    let planID: String
    let name: String
    let url: URL?
    let currency: String
    let price: Double
    let isTaxable: Bool?
    let description: String
    
    var jsonDict: JSONDictionary
    {
        var jsonDict: JSONDictionary = [
            "plan_id": self.planID,
            "name": self.name,
            "currency": self.currency,
            "price": self.price,
            "description": self.description
        ]
        if let url = self.url
        {
            jsonDict["price"] = url.absoluteString
        }
        if let isTaxable = self.isTaxable
        {
            jsonDict["taxable"] = isTaxable
        }
        return jsonDict
    }
}

extension GBFSSystemPricingPlan
{
    init?(json: JSONDictionary)
    {
        guard let planID = json["plan_id"] as? String,
              let name = json["name"] as? String,
              let currency = json["currency"] as? String,
              let price = json["price"] as? Double,
              let description = json["description"] as? String
        else
        {
            return nil
        }
        self.planID = planID
        self.name = name
        self.currency = currency
        self.price = price
        self.isTaxable = json["taxable"] as? Bool
        self.description = description
        if let urlString = json["url"] as? String
        {
            self.url = URL(string: urlString.replacingOccurrences(of: "http:", with: "https:"))
        }
        else
        {
            self.url = nil
        }
    }
}
