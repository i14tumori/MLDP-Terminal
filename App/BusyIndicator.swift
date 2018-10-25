//
//  BusyIndicator.swift
//  App
//
//  Created by 津森智己 on 2018/10/25.
//  Copyright © 2018 津森智己. All rights reserved.
//

import Foundation
import UIKit

class BusyIndicator: UIView {
    // 基本的な見た目などの初期化
    private func commonInit() {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: "BusyIndicator", bundle: bundle)
        let view = nib.instantiate(withOwner: self, options: nil).first as! UIView
        self.addSubview(view)
        
        view.translatesAutoresizingMaskIntoConstraints = false
        let bindings = ["view": view]
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[view]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: bindings))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[view]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: bindings))
    }
    
    // シングルトンで生成する
    static let sharedManager: BusyIndicator = {
        let instance = BusyIndicator()
        instance.commonInit()
        return instance
    }()
    
    // 表示する
    func show() {
        // 画面全体を覆わせる
        self.frame = UIScreen.main.bounds
        // Viewを追加して表示させる
        let vc = UIApplication.shared.keyWindow?.rootViewController
        vc?.view.addSubview(self)
    }
    
    // 非表示にする
    func dismiss() {
        // Viewを除去して非表示にする
        self.removeFromSuperview()
    }
}
