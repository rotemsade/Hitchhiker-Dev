//
//  ViewController.swift
//  Hitchhiker Dev
//
//  Created by rotem.sade on 28/09/2018.
//  Copyright © 2018 rotem.sade. All rights reserved.
//

import UIKit
import MapKit

class ViewController: UIViewController, MKMapViewDelegate {
    @IBOutlet weak var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        // Do any additional setup after loading the view, typically from a nib.
    }


}

