//
//  PassengerAnnotation.swift
//  Hitchhiker Dev
//
//  Created by rotem.sade on 04/10/2018.
//  Copyright © 2018 rotem.sade. All rights reserved.
//

import Foundation
import MapKit

class PassengerAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var key:  String
    
    init(coordinate: CLLocationCoordinate2D, key: String) {
        self.coordinate = coordinate
        self.key = key
        super.init()
    }
}
