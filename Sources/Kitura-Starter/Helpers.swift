//
//  Helpers.swift
//  project1
//
//  Created by Brad G. on 1/2/17.
//
//

import Foundation
import SwiftyJSON

var networkJSON: JSON?
{
    guard let data = try? Data(contentsOf: Constants.NetworkURL) else { return nil }
    return JSON(data: data)
}

var networks: [BikeNetwork]?
{
    guard let json = networkJSON else { return nil }
    guard let networksJSON = json["networks"].rawValue as? [JSONDictionary] else { return nil }
    return networksJSON.flatMap(BikeNetwork.init)
}

func stationJSON(href: String) -> JSON?
{
    guard let url = URL(string: "\(Constants.BaseURL)\(href)") else { return nil }
    guard let data = try? Data(contentsOf: url) else { return nil }
    return JSON(data: data)
}

func stations(href: String) -> [BikeStation]?
{
    guard let json = stationJSON(href: href) else { return nil }
    guard let stationsJSON = json["network"]["stations"].rawValue as? [JSONDictionary] else { return nil }
    return stationsJSON.flatMap(BikeStation.init)
}

func closebyStations(coordinates: Coordinates) -> ([BikeStation]?, BikeNetwork?)
{
    guard let netW = networks else { return (nil, nil) }
    let sortedNetworks = netW.sorted{ $0.location.coordinates.distance(to: coordinates) < $1.location.coordinates.distance(to: coordinates) }
    guard let closestNetwork = sortedNetworks.first else { return (nil, nil) }
    guard let stations = stations(href: closestNetwork.id) else { return (nil, closestNetwork) }
    let sortedStations = stations.sorted{ $0.coordinates.distance(to: coordinates) < $1.coordinates.distance(to: coordinates) }
    guard let closestStation = sortedStations.first else { return ([], closestNetwork) }
    guard closestStation.coordinates.distance(to: coordinates) <= 10.0 else { return ([], closestNetwork) }
    var closeStations = Array(sortedStations.prefix(5))
    closeStations = closeStations.map
    {
        var station = $0
        station.distance = station.coordinates.distance(to: coordinates)
        return station
    }
    return (closeStations, closestNetwork)
}

func closebyStationsJSON(coordinates: Coordinates) -> JSON
{
    let (closeStations, network) = closebyStations(coordinates: coordinates)
    guard case (.some, .some) = (closeStations, network) else { return JSON([:]) }
    var jsonDict = JSONDictionary()
    if !(closeStations?.isEmpty ?? false)
    {
        jsonDict = ["network": network!.jsonDict]
    }
    let closeDict: [JSONDictionary]
    if let data = try? Data(contentsOf: timeZoneURL(lat: coordinates.latitude, long: coordinates.longitude))
    {
        let timeZoneJSON = JSON(data: data)
        closeDict = closeStations!.map{ $0.jsonDict(timeZoneID: timeZoneJSON["timeZoneId"].stringValue) }
    }
    else
    {
        closeDict = closeStations!.map{ $0.jsonDict }
    }
    jsonDict["stations"] = closeDict
    jsonDict["currentLocation"] = ["latitude": coordinates.latitude, "longitude": coordinates.longitude]
    let json = JSON(jsonDict)
    return json
}

func timeZoneURL(lat: Double, long: Double) -> URL
{
    return URL(string: "https://maps.googleapis.com/maps/api/timezone/json?location=\(lat),\(long)&timestamp=0&key=AIzaSyC7QULaKAQL2T8wEwGweWIrYpA8IthppiE")!
}
