//
//  RoundMapView.swift
//  Hitchhiker Dev
//
//  Created by rotem.sade on 04/10/2018.
//  Copyright © 2018 rotem.sade. All rights reserved.
//

import UIKit
import MapKit

class RoundMapView: MKMapView {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupView()
    }
    
    func setupView() {
        self.layer.cornerRadius = self.frame.width / 2
        self.layer.borderColor = UIColor.white.cgColor
        self.layer.borderWidth = 10.0
    }

}
