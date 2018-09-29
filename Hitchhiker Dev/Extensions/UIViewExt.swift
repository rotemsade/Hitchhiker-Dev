//
//  UIViewExt.swift
//  Hitchhiker Dev
//
//  Created by rotem.sade on 29/09/2018.
//  Copyright © 2018 rotem.sade. All rights reserved.
//

import UIKit

extension UIView {
    func fadeTo(alphaValue: CGFloat, withDuration duration: TimeInterval) {
        UIView.animate(withDuration: duration) {
            self.alpha = alphaValue
        }
    }
}
