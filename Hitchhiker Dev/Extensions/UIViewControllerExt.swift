//
//  UIViewControllerExt.swift
//  Hitchhiker Dev
//
//  Created by rotem.sade on 04/10/2018.
//  Copyright © 2018 rotem.sade. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {
    func shouldPresentLoadingView(_ status: Bool) {
        var fadeView: UIView?
        
        if status {
            fadeView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height))
            fadeView?.backgroundColor = UIColor.black
            fadeView?.alpha = 0.0
            fadeView?.tag = 99
            
            let spinner = UIActivityIndicatorView()
            spinner.color = UIColor.white
            spinner.style = .whiteLarge
            spinner.center = view.center
            
            fadeView?.addSubview(spinner)
            view.addSubview(fadeView!)
            
            spinner.startAnimating()
            
            fadeView?.fadeTo(alphaValue: 0.7, withDuration: 0.2)
        } else {
            for subView in view.subviews {
                if subView.tag == 99 {
                    UIView.animate(withDuration: 0.2, animations: {
                        subView.alpha = 0.0
                    }) { (finished) in
                        subView.removeFromSuperview()
                    }
                }
            }
        }
    }
}
