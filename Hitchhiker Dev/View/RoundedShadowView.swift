//
//  RoundedShadowView.swift
//  Hitchhiker Dev
//
//  Created by rotem.sade on 28/09/2018.
//  Copyright © 2018 rotem.sade. All rights reserved.
//

import UIKit

class RoundedShadowView: UIView {
    override func awakeFromNib() {
        super.awakeFromNib()
        setupView()
    }

    func setupView(){
        self.layer.shadowOpacity = 0.3
        self.layer.shadowColor = UIColor.darkGray.cgColor
        self.layer.shadowRadius = 5
        self.layer.shadowOffset = CGSize(width: 0, height: 5)
        
        self.layer.cornerRadius = 5
    }

}
