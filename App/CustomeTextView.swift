//
//  CustomeTextView.swift
//  App
//
//  Created by 津森智己 on 2018/08/26.
//  Copyright © 2018年 津森智己. All rights reserved.
//

import UIKit

class CustomeTextView: UITextView {
    
    // 入力カーソル非表示
    override func caretRect(for position: UITextPosition) -> CGRect {
        return CGRect.zero
    }

}
