//
//  CircleView.swift
//  Hitchhiker Dev
//
//  Created by rotem.sade on 29/09/2018.
//  Copyright © 2018 rotem.sade. All rights reserved.
//

import UIKit

class CircleView: UIView {
    
    @IBInspectable var borderColor: UIColor? {
        didSet {
            setupView()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupView()
    }

    func setupView() {
        self.layer.cornerRadius = self.frame.size.width / 2
        self.layer.borderWidth = 1.2
        self.layer.borderColor = borderColor?.cgColor
    }
}
