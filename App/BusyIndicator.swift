//
//  BusyIndicator.swift
//  App
//
//  Created by 津森智己 on 2018/10/25.
//  Copyright © 2018 津森智己. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

// 処理中の画面を表示するためのクラス
class BusyIndicator: UIView {
    // 表示状態を表す変数
    var isShow = false
    
    // 基本的な見た目などの初期化
    private func commonInit() {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: "BusyIndicator", bundle: bundle)
        let view = nib.instantiate(withOwner: self, options: nil).first as! UIView
        view.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
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
    
    // 表示する関数
    func show(controller: UIViewController) {
        // 表示状態にする
        isShow = true
        // 画面全体を覆わせる
        self.frame = UIScreen.main.bounds
        print("rootViewController : \(String(describing: controller))")
        // Viewを追加して表示させる
        let vc = controller
        vc.view.addSubview(self)
    }
    
    // 非表示にする関数
    func dismiss() {
        // 非表示状態にする
        isShow = false
        // Viewを除去して非表示にする
        self.removeFromSuperview()
    }
}
