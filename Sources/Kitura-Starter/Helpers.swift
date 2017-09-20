//
//  Helpers.swift
//  project1
//
//  Created by Brad G. on 1/2/17.
//
//

import Foundation
import SwiftyJSON
import MySQL
import LoggerAPI


var networkJSON: JSON?
{
    guard let data = try? Data(contentsOf: Constants.NetworkURL) else { return nil }
    let networkData = JSON(data: data)
    return networkData
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
    guard let data = try? Data(contentsOf: URL(string: "\(Constants.BaseURL)\(href)")!) else { return nil }
    return JSON(data: data)
}

func feeds(gbfsHref: URL?) -> [GBFSFeed]?
{
    guard let gbfsHref = gbfsHref else { return nil }
    let feedsJSON = get(gbfsHref.absoluteString)
    guard let jsonArray = feedsJSON?["data"]["en"]["feeds"].arrayObject as? [JSONDictionary] else { return nil }
    return jsonArray.flatMap(GBFSFeed.init)
}

func stationInfo(feeds: [GBFSFeed]) -> [GBFSStationInformation]?
{
    let stationFeed = feeds.first { $0.type == .stationInformation }
    guard let stationInfoFeed = stationFeed else { return nil }
    let stationInfoJSON = get(stationInfoFeed.url.absoluteString)
    guard let jsonArray = stationInfoJSON?["data"]["stations"].arrayObject as? [JSONDictionary] else { return nil }
    return jsonArray.flatMap(GBFSStationInformation.init)
}

func stationStatus(with feeds: [GBFSFeed], stationsDict: [String: GBFSStationInformation], stations: [BikeStation]) -> [BikeStation]?
{
    var stationsDict = stationsDict
    let stationFeed = feeds.first { $0.type == .stationStatus }
    guard let stationStatusFeed = stationFeed else { return nil }
    let stationStatusJSON = get(stationStatusFeed.url.absoluteString)
    guard let jsonArray = stationStatusJSON?["data"]["stations"].arrayObject as? [JSONDictionary] else { return nil }
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
    let systemInformation = feeds.first { $0.type == .systemInformation }
    guard let systemInformationFeed = systemInformation else { return nil }
    let systemInfoJSON = get(systemInformationFeed.url.absoluteString)
    guard let json = systemInfoJSON?["data"].dictionaryObject else { return nil }
    return GBFSSystemInformation(json: json)
}

func systemPricingPlan(feeds: [GBFSFeed]) -> [GBFSSystemPricingPlan]?
{
    let systemPricingPlan = feeds.first { $0.type == .systemPricingPlans }
    guard let systemPricingPlanFeed = systemPricingPlan else { return nil }
    let systemPricingPlanJSON = get(systemPricingPlanFeed.url.absoluteString)
    guard let plansJSON = systemPricingPlanJSON?["data"]["plans"].arrayObject as? [JSONDictionary]
    else { return nil }
    return plansJSON.flatMap(GBFSSystemPricingPlan.init)
}

func systemAlert(feeds: [GBFSFeed]) -> [GBFSSystemAlert]?
{
    let systemAlert = feeds.first { $0.type == .systemAlerts }
    guard let systemAlertFeed = systemAlert else { return nil }
    let systemAlertJSON = get(systemAlertFeed.url.absoluteString)
    guard let alertsJSON = systemAlertJSON?["data"]["alerts"].arrayObject as? [JSONDictionary] else { return nil }
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
    let sortedNetworks = netW.filter{ $0.location.coordinates.distance(to: coordinates) < 50.0 }
    guard !sortedNetworks.isEmpty else { return (nil, nil) }
    let networkStations = sortedNetworks.map { ($0, stations(href: $0.id)) }
    let lotsOfStations = networkStations.flatMap { $0.1 }.flatMap { $0 }
    let sortedStations = lotsOfStations.sorted{ $0.coordinates.distance(to: coordinates) < $1.coordinates.distance(to: coordinates) }
    guard let closestStation = sortedStations.first else { return ([], sortedNetworks.first) }
    var closestNetworkStation: (BikeNetwork, [BikeStation]?)?
    for networkStation in networkStations
    {
        if networkStation.1?.contains(closestStation) == true
        {
            closestNetworkStation = networkStation
            break
        }
    }
    guard closestNetworkStation != nil  else { return  (nil, nil) }
    guard closestStation.coordinates.distance(to: coordinates) <= 10.0 else { return ([], closestNetworkStation!.0) }
    guard let closeStationsAll = closestNetworkStation?.1 else { return ([], closestNetworkStation!.0) }
    let sortedCloseStations = closeStationsAll.sorted { $0.coordinates.distance(to: coordinates) < $1.coordinates.distance(to: coordinates) }
    var closeStations = Array(sortedCloseStations.prefix(5))
    closeStations = closeStations.map
    {
        var station = $0
        station.distance = station.coordinates.distance(to: coordinates)
        return station
    }
    return (closeStations, closestNetworkStation!.0)
}

func stations(with ids: [String], in network: BikeNetwork) -> [BikeStation]?
{
    guard let stations = stations(href: network.id) else { return nil }
    return stations.filter { ids.contains($0.id) }
}

func stationsJSON(with ids: [String], in network: BikeNetwork) -> [JSONDictionary]?
{
    return stations(with: ids, in: network)?.map { $0.jsonDict }
}

func closebyStations(coordinates: Coordinates, network: BikeNetwork) -> [BikeStation]?
{
    guard let stations = stations(href: network.id) else { return nil }
    let sortedStations = stations.sorted{ $0.coordinates.distance(to: coordinates) < $1.coordinates.distance(to: coordinates) }
    guard sortedStations.first != nil else { return [] }
    var closeStations = Array(sortedStations.prefix(8))
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
    if let timeZoneJSON = get(timeZoneURL(lat: coordinates.latitude, long: coordinates.longitude).absoluteString)
    {
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

func addStationStatusesToDatabase(networkID: String)
{
    guard let stations = stations(href: networkID) else { return }
    do
    {
        let (db, connection) = try connectToDatabase()
        
        let deleteQuery = "DELETE FROM `\(networkID)` WHERE `timestamp` < (NOW() - INTERVAL 1 WEEK)"
        try db.execute(deleteQuery)
        try db.execute("SET autocommit=0;", [], connection)
        for station in stations
        {
            try db.execute("INSERT INTO `\(networkID)`" + station.insertQueryString, [networkID], connection)
        }
        try db.execute("COMMIT;", [], connection)
    }
    catch
    {
        Log.warning("Failed to send /statuses for \(networkID): \(error.localizedDescription)")
    }
}

func getStationStatusesFromDatabase(network: BikeNetwork, stationID: String) -> [BikeStationStatus]?
{
    do
    {
        let (db, connection) = try connectToDatabase()
        let queryString = "SELECT * FROM `\(network.id)` WHERE `stationID` = ? ORDER BY `timestamp` DESC LIMIT 168;"
        let statusNodes = try db.execute(queryString, [stationID], connection)
        let statuses = statusNodes.flatMap(BikeStationStatus.init)
        return statuses
        
    }
    catch
    {
        Log.warning("Failed to get /statuses for \(network.id): \(error.localizedDescription)")
        return nil
    }
}

func timeZoneURL(lat: Double, long: Double) -> URL
{
    return URL(string: "https://maps.googleapis.com/maps/api/timezone/json?location=\(lat),\(long)&timestamp=0&key=AIzaSyC7QULaKAQL2T8wEwGweWIrYpA8IthppiE")!
}

func connectToDatabase() throws -> (Database, Connection)
{
    let mysql = try Database(host: "us-cdbr-iron-east-03.cleardb.net", user: "b7d5233d55fa0a", password: "48eb44de", database: "ad_45072b617cc9058")
    let connection = try mysql.makeConnection()
    return (mysql, connection)
}
