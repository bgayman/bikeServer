//
//  GBFSFeed.swift
//  BikeShare
//
//  Created by Brad G. on 2/9/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import Foundation

enum GBFSFeedType: String
{
    case systemInformation = "system_information"
    case stationInformation = "station_information"
    case stationStatus = "station_status"
    case freeBikeStatus = "free_bike_status"
    case systemHours = "system_hours"
    case systemCalendar = "system_calendar"
    case systemRegions = "system_regions"
    case systemPricingPlans = "system_pricing_plans"
    case systemAlerts = "system_alerts"
}


struct GBFSFeed
{
    let name: String
    let url: URL
    let type: GBFSFeedType
}

extension GBFSFeed
{
    init?(json: JSONDictionary)
    {
        guard let name = json["name"] as? String,
              let urlString = json["url"] as? String,
              let url = URL(string: urlString.replacingOccurrences(of: "http:", with: "https:")),
              let type = GBFSFeedType(rawValue: name)
        else { return nil }
        self.type = type
        self.name = name
        self.url = url
    }
}
