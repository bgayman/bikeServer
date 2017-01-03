//
//  BikeNetworkLocation.swift
//  project1
//
//  Created by Brad G. on 1/2/17.
//
//

import Foundation

struct BikeNetworkLocation
{
    let city: String
    let country: String
    let coordinates: Coordinates
}

extension BikeNetworkLocation
{
    init?(json: JSONDictionary)
    {
        guard let city = json["city"] as? String,
            let country = json["country"] as? String,
            let latitude = json["latitude"] as? Double,
            let longitude = json["longitude"] as? Double
            else
        {
            return nil
        }
        self.city = city
        self.country = country
        self.coordinates = Coordinates(latitude: latitude, longitude: longitude)
    }
    
    var jsonDict: JSONDictionary
    {
        return ["city": self.city,
                "country": self.country,
                "latitude": self.coordinates.latitude,
                "longitude": self.coordinates.longitude]
    }
}
