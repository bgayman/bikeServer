import Kitura
import LoggerAPI
import HeliumLogger
import Foundation
import SwiftyJSON
import KituraStencil

HeliumLogger.use(.info)
let router = Router()

router.setDefault(templateEngine: StencilTemplateEngine())

router.get("/")
{ request, response, next in
    defer{ next() }
    try response.render("home", context: [:])
}

router.get("/networks")
{ request, response, next in
    defer{ next() }
    let json = networkJSON?.rawValue as? [String: Any]
    try response.render("networks", context: json ?? [:])
}

router.get("/networks/json")
{ request, response, next in
    defer{ next() }
    response.send(json: networkJSON ?? JSON([]))
}

router.get("stations/:id")
{ request, response, next in
    defer{ next() }
    guard let href = request.parameters["id"] else { return }
    guard let stationJSON = stationJSON(href: href) else { return }
    response.send(json: stationJSON)
}

router.get("json/lat/:lat/long/:long")
{ request, response, next in
    defer{ next() }
    guard let lat = Double(request.parameters["lat"] ?? "a") else { return }
    guard let long = Double(request.parameters["long"] ?? "a") else { return }
    let coordinates = Coordinates(latitude: lat, longitude: long)
    let (closeStations, network) = closebyStations(coordinates: coordinates)
    guard case (.some, .some) = (closeStations, network) else { return }
    var jsonDict: JSONDictionary = ["network": network!.jsonDict]
    let closeDict: [JSONDictionary] = closeStations!.map{ $0.jsonDict }
    jsonDict["stations"] = closeDict
    let json = JSON(jsonDict)
    response.send(json: json)
}

router.all("/static", middleware: StaticFileServer())

router.get("/lat/:lat/long/:long")
{ request, response, next in
    defer{ next() }
    guard let lat = Double(request.parameters["lat"] ?? "a") else { return }
    guard let long = Double(request.parameters["long"] ?? "a") else { return }
    let coordinates = Coordinates(latitude: lat, longitude: long)
    let json = closebyStationsJSON(coordinates: coordinates)
    let context = json.rawValue as? [String: Any]
    try response.render("stations", context: context ?? [:])
}

Kitura.addHTTPServer(onPort: 8090, with: router)
Kitura.run()
