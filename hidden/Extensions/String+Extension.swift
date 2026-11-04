//
//  String+Extension.swift
//  Hidden Bar
//
//  Created by Licardo on 2020/3/9.
//  Copyright © 2020 Dwarves Foundation. All rights reserved.
//

import Foundation

extension String {
    
    // localize
    var localized: String {
        if let language = UserDefaults.standard.string(forKey: "foldbarLanguage"),
           ["en", "zh-Hans"].contains(language),
           let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: self, value: self, table: nil)
        }
        return Bundle.main.localizedString(forKey: self, value: self, table: nil)
    }
}
