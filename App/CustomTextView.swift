//
//  CustomeTextView.swift
//  App
//
//  Created by 津森智己 on 2018/08/26.
//  Copyright © 2018年 津森智己. All rights reserved.
//

import UIKit

class CustomTextView: UITextView {
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        // ボタンを追加するViewを作成、設定
        let keyboard = UIStackView(frame: CGRect(x: 0, y: 0, width: 320, height: 40))
        keyboard.axis = .horizontal
        keyboard.alignment = .center
        keyboard.distribution = .fillEqually
        keyboard.spacing = 3
        keyboard.sizeToFit()
        
        // ボタン追加Viewの背景用View
        let backView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 40))
        backView.backgroundColor = UIColor.gray
        backView.sizeToFit()
        
        // エスケープキーの作成、設定
        let escButton = UIButton(frame: CGRect())
        escButton.backgroundColor = UIColor.lightGray
        escButton.setTitle("ESC", for: UIControlState.normal)
        escButton.addTarget(ViewController(), action: #selector(ViewController.escTapped), for: UIControlEvents.touchUpInside)
        
        // コントロールキーの作成、設定
        let ctrlButton = UIButton(frame: CGRect())
        ctrlButton.backgroundColor = UIColor.lightGray
        ctrlButton.setTitle("Ctrl", for: UIControlState.normal)
        ctrlButton.addTarget(ViewController(), action: #selector(ViewController.ctrlTapped), for: UIControlEvents.touchUpInside)
        
        // 上矢印キーの作成、設定
        let upButton = UIButton(frame: CGRect())
        upButton.backgroundColor = UIColor.lightGray
        upButton.setTitle("↑", for: UIControlState.normal)
        upButton.addTarget(ViewController(), action: #selector(ViewController.upTapped), for: UIControlEvents.touchUpInside)
        
        // 下矢印キーの作成、設定
        let downButton = UIButton(frame: CGRect())
        downButton.backgroundColor = UIColor.lightGray
        downButton.setTitle("↓", for: UIControlState.normal)
        downButton.addTarget(ViewController(), action: #selector(ViewController.downTapped), for: UIControlEvents.touchUpInside)
        
        // 左矢印キーの作成、設定
        let leftButton = UIButton(frame: CGRect())
        leftButton.backgroundColor = UIColor.lightGray
        leftButton.setTitle("←", for: UIControlState.normal)
        leftButton.addTarget(ViewController(), action: #selector(ViewController.leftTapped), for: UIControlEvents.touchUpInside)
        
        // 右矢印キーの作成、設定
        let rightButton = UIButton(frame: CGRect())
        rightButton.backgroundColor = UIColor.lightGray
        rightButton.setTitle("→", for: UIControlState.normal)
        rightButton.addTarget(ViewController(), action: #selector(ViewController.rightTapped), for: UIControlEvents.touchUpInside)
        
        // ボタンをViewに追加する
        keyboard.addArrangedSubview(escButton)
        keyboard.addArrangedSubview(ctrlButton)
        keyboard.addArrangedSubview(upButton)
        keyboard.addArrangedSubview(downButton)
        keyboard.addArrangedSubview(leftButton)
        keyboard.addArrangedSubview(rightButton)
        
        // ボタンViewに背景をつける
        backView.addSubview(keyboard)
        
        // textViewと紐付ける
        self.inputAccessoryView = backView
    }
    
    // 入力カーソル非表示
    override func caretRect(for position: UITextPosition) -> CGRect {
        return CGRect.zero
    }
}
