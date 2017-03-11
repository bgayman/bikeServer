//
//  Helpers.swift
//  project1
//
//  Created by Brad G. on 1/2/17.
//
//

import Foundation
import SwiftyJSON

var networkData: Data?

var networkJSON: JSON?
{
    if let networkData = networkData
    {
        return JSON(data: networkData)
    }
    guard let data = try? Data(contentsOf: Constants.NetworkURL) else { return nil }
    networkData = data
    return JSON(data: data)
}

var networks: [BikeNetwork]?
{
    guard let json = networkJSON else { return nil }
    guard let networksJSON = json["networks"].rawValue as? [JSONDictionary] else { return nil }
    return networksJSON.flatMap(BikeNetwork.init)
}

func network(for id: String) -> BikeNetwork?
{
    guard let networks = networks else { return nil }
    return networks.filter { $0.id == id }.first
}

func stationJSON(href: String) -> JSON?
{
    guard let url = URL(string: "\(Constants.BaseURL)\(href)") else { return nil }
    guard let data = try? Data(contentsOf: url) else { return nil }
    return JSON(data: data)
}

func feeds(gbfsHref: URL?) -> [GBFSFeed]?
{
    guard let gbfsHref = gbfsHref,
          let data = try? Data(contentsOf: gbfsHref) else { return nil }
    let feedsJSON = JSON(data: data)
    guard let jsonArray = feedsJSON["data"]["en"]["feeds"].arrayObject as? [JSONDictionary] else { return nil }
    return jsonArray.flatMap(GBFSFeed.init)
}

func stationInfo(feeds: [GBFSFeed]) -> [GBFSStationInformation]?
{
    let stationFeed = feeds.filter { $0.type == .stationInformation }
    guard let stationInfoFeed = stationFeed.first,
          let data = try? Data(contentsOf: stationInfoFeed.url)
    else { return nil }
    let stationInfoJSON = JSON(data: data)
    guard let jsonArray = stationInfoJSON["data"]["stations"].arrayObject as? [JSONDictionary] else { return nil }
    return jsonArray.flatMap(GBFSStationInformation.init)
}

func stationStatus(with feeds: [GBFSFeed], stationsDict: [String: GBFSStationInformation], stations: [BikeStation]) -> [BikeStation]?
{
    var stationsDict = stationsDict
    let stationFeed = feeds.filter { $0.type == .stationStatus }
    guard let stationStatusFeed = stationFeed.first,
          let data = try? Data(contentsOf: stationStatusFeed.url)
    else { return nil }
    let stationStatusJSON = JSON(data: data)
    guard let jsonArray = stationStatusJSON["data"]["stations"].arrayObject as? [JSONDictionary] else { return nil }
    let stationStatuses = jsonArray.flatMap(GBFSStationStatus.init)
    for stationStatus in stationStatuses
    {
        stationsDict[stationStatus.stationID]?.stationStatus = stationStatus
    }
    var newStationsDict = [String: GBFSStationInformation]()
    for (_, value) in stationsDict
    {
        newStationsDict[value.name] = value
    }
    let newStations: [BikeStation] = stations.map
    {
        var station = $0
        station.gbfsStationInformation = newStationsDict[station.name]
        return station
    }
    return newStations
}

func systemInformation(feeds: [GBFSFeed]) -> GBFSSystemInformation?
{
    let systemInformation = feeds.filter { $0.type == .systemInformation }
    guard let systemInformationFeed = systemInformation.first,
        let data = try? Data(contentsOf: systemInformationFeed.url)
    else { return nil }
    let systemInfoJSON = JSON(data: data)
    guard let json = systemInfoJSON["data"].dictionaryObject else { return nil }
    return GBFSSystemInformation(json: json)
}

func systemPricingPlan(feeds: [GBFSFeed]) -> [GBFSSystemPricingPlan]?
{
    let systemPricingPlan = feeds.filter { $0.type == .systemPricingPlans }
    guard let systemPricingPlanFeed = systemPricingPlan.first,
          let data = try? Data(contentsOf: systemPricingPlanFeed.url)
    else { return nil }
    let systemPricingPlanJSON = JSON(data: data)
    guard let plansJSON = systemPricingPlanJSON["data"]["plans"].arrayObject as? [JSONDictionary]
    else { return nil }
    return plansJSON.flatMap(GBFSSystemPricingPlan.init)
}

func systemAlert(feeds: [GBFSFeed]) -> [GBFSSystemAlert]?
{
    let systemAlert = feeds.filter { $0.type == .systemAlerts }
    guard let systemAlertFeed = systemAlert.first,
          let data = try? Data(contentsOf: systemAlertFeed.url)
    else { return nil }
    let systemAlertJSON = JSON(data: data)
    guard let alertsJSON = systemAlertJSON["data"]["alerts"].arrayObject as? [JSONDictionary] else { return nil }
    var alerts = alertsJSON.flatMap(GBFSSystemAlert.init)
    if let stationsInfo = stationInfo(feeds: feeds)
    {
        for (index, alert) in alerts.enumerated()
        {
            var alert = alert
            guard let stationsIDs = alert.stationIDs else { continue }
            alert.stations = stationsInfo.filter { stationsIDs.contains($0.stationID) }
            alerts[index] = alert
        }
    }
    return alerts
}

func sortedStations(coordinates: Coordinates, stations: [BikeStation]) -> [BikeStation]
{
    let sortedStations = stations.sorted
    {
        $0.0.coordinates.distance(to: coordinates) < $0.1.coordinates.distance(to: coordinates)
    }
    return sortedStations
}

func sortedNetworks(coordinates: Coordinates, networks: [BikeNetwork]) -> [BikeNetwork]
{
    let sortedNetworks = networks.sorted
    {
        $0.0.location.coordinates.distance(to: coordinates) < $0.1.location.coordinates.distance(to: coordinates)
    }
    return sortedNetworks
}

func stations(href: String) -> [BikeStation]?
{
    guard let json = stationJSON(href: href) else { return nil }
    guard let stationsJSON = json["network"]["stations"].rawValue as? [JSONDictionary] else { return nil }
    let stations = stationsJSON.flatMap(BikeStation.init)
    guard let network = network(for: href),
          let gbfsHref = network.gbfsHref
    else { return stations}
    
    guard let gbfsFeeds = feeds(gbfsHref: gbfsHref),
          let stationInformation = stationInfo(feeds: gbfsFeeds)
    else { return stations }
    
    let stationsDict: [String: GBFSStationInformation] = stationInformation.reduce([String: GBFSStationInformation]())
    { (result, stationInformation) in
        var result = result
        result[stationInformation.stationID] = stationInformation
        return result
    }
    guard let newStations = stationStatus(with: gbfsFeeds, stationsDict: stationsDict, stations: stations) else { return stations }
    return newStations
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

func closebyStations(coordinates: Coordinates, network: BikeNetwork) -> [BikeStation]?
{
    guard let stations = stations(href: network.id) else { return nil }
    let sortedStations = stations.sorted{ $0.coordinates.distance(to: coordinates) < $1.coordinates.distance(to: coordinates) }
    guard sortedStations.first != nil else { return [] }
    var closeStations = Array(sortedStations.prefix(5))
    closeStations = closeStations.map
    {
        var station = $0
        station.distance = station.coordinates.distance(to: coordinates)
        return station
    }
    return closeStations
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
