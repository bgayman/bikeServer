//
//  Networking.swift
//  Kitura-Starter
//
//  Created by B Gay on 5/20/17.
//
//

import Foundation
import KituraNet
import SwiftyJSON

func get(_ url: String) -> JSON?
{
    guard let newURL = URL(string: url),
          let data = try? Data(contentsOf: newURL) else { return nil }
    return JSON(data: data)
}
