//
//  Alertable.swift
//  Hitchhiker Dev
//
//  Created by rotem.sade on 04/10/2018.
//  Copyright © 2018 rotem.sade. All rights reserved.
//

import UIKit

protocol Alertable {}

extension Alertable where Self: UIViewController {
    func showAlert(_ msg: String) {
        let alertController = UIAlertController(title: ALERT_MSG_PREFIX, message: msg, preferredStyle: .alert)
        let action = UIAlertAction(title: ALERT_BUTTON_FACE, style: .default, handler: nil)
        
        alertController.addAction(action)
        present(alertController, animated: true, completion: nil)
    }
}
