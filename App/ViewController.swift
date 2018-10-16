//
//  ViewController.swift
//  App
//
//  Created by 津森智己 on 2018/08/08.
//  Copyright © 2018年 津森智己. All rights reserved.
//

import UIKit
import CoreBluetooth

// String型の拡張メソッド
extension String {
    // 英数字の判定
    func isAlphanumeric(_ text: String) -> Bool {
        return text >= "\0" && text <= "~"
    }
}

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, UITextViewDelegate {
       
    var response = ""
    let maxLength = 18
    
    // テキスト入力可能判断用フラグ
    var viewEditFlag = 0
    
    // カーソル位置記憶変数
    var cursor = [0, 0]
    
    @IBOutlet weak var textview: UITextView!
    
    // AppDelegate内の変数呼び出し用
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // TextViewに枠線をつける
        textview.layer.borderColor = UIColor.gray.cgColor
        textview.layer.borderWidth = 0.5
        textview.layer.cornerRadius = 5
 
        textview.delegate = self
        
        // プロンプト,カーソル表示
       writePrompt("")
        
        // カーソルの位置を初期化する
        cursor[0] = 1
        
        // テキストのフォント設定
        textview.font = UIFont(name: "CourierNewPSMT", size: textview.font!.pointSize)
        
        // インスタンスの生成および初期化
        appDelegate.centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        print("centralManagerDelegate set")
        appDelegate.centralManager.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /* Bluetooth以外関連メソッド */
    
    // タッチ開始時のタッチイベント
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("touches began")
        // キーボードを閉じる
        self.view.endEditing(true)
    }
    
    // textViewの入力値を取得し、最後尾に追記
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // 編集不可判断,入力文字制限
        if (viewEditFlag == 1 || !text.isAlphanumeric(text)) {
            // 追記せずに戻る
            return false
        }
        // 改行(コマンド送信)のとき
        if text == "\n" {
            if appDelegate.outputCharacteristic == nil {
                print("\(appDelegate.peripheralDeviceName) is not ready")
                showToast(message: "デバイス未接続")
            }
            else {
                // レスポンスがあるまで編集不可にする
                viewEditFlag = 1
                
                // 一行分の文字列を取得する
                let splitArray = textview.text!.components(separatedBy: CharacterSet.newlines)
                var txText = splitArray[splitArray.count - 1]
                
                // カーソル用空白文字,プロンプトを取り除く
                if txText.count > 1 {
                    // カーソル用空白文字の除去
                    txText = String(txText.prefix(txText.count-1))
                    // プロンプトの除去
                    txText = String(txText.suffix(txText.count-1))
                }
                
                /* 商　quotient   余り　remainder */
                let remainder = txText.count % maxLength
                
                // 文字列を分割しながら送信する
                for i in stride(from: 0, to: txText.count - remainder, by: maxLength) {
                    let splitText = txText[txText.index(txText.startIndex, offsetBy: i)..<txText.index(txText.startIndex, offsetBy: i + maxLength)]
                    let data = splitText.data(using: String.Encoding.utf8)
                    // ペリフェラルにデータを書き込む
                    appDelegate.peripheral.writeValue(data!, for: appDelegate.outputCharacteristic, type: CBCharacteristicWriteType.withResponse)
                }
                
                let splitText = String(txText.suffix(remainder)) + "\r\n"
                let data = splitText.data(using: String.Encoding.utf8)
                
                // ペリフェラルにデータを書き込む
                appDelegate.peripheral.writeValue(data!, for: appDelegate.outputCharacteristic, type: CBCharacteristicWriteType.withResponse)
                
                // カーソル位置に追記
                writeTextView(text)
                
                // カーソルをずらす
                cursor[0] = cursor[0] + 1
                cursor[1] = 1
                
                // カーソルを表示する
                viewCursor()
            }
        }
        else {
            // カーソル位置に追記
            writeTextView(text)
            
            // カーソルをずらす
            cursor[1] = cursor[1] + 1
            
            // カーソルを表示する
            viewCursor()
        }
        // デフォルトカーソル(青縦棒)位置への追記はしない
        return false
    }
    
    // clearButtonが押されたとき
    @IBAction func clearButtonTapped(_ sender: UIButton) {
        print("clear button tapped")
        // カーソル表示
        writePrompt("")
        
        // カーソルの位置を初期化する
        cursor[0] = 1
        
        // フォントを再設定する
        textview.font = UIFont(name: "CourierNewPSMT", size: textview.font!.pointSize)
    }
    
    // scanButtonが押されたとき
    @IBAction func scanButtonTapped(_ sender: UIButton) {
        print("scan button tapped")
        appDelegate.centralManager.scanForPeripherals(withServices: [appDelegate.mldpService_UUID], options: nil)
    }
    
    // disconButtonが押されたとき
    @IBAction func disconButtonTapped(_ sender: UIButton) {
        print("disconnect button tapped")
        
        if appDelegate.outputCharacteristic == nil {
            print("\(appDelegate.peripheralDeviceName) is not ready")
            showToast(message: "デバイス未接続")
            return
        }
        
        appDelegate.peripheral.setNotifyValue(false, for: appDelegate.outputCharacteristic)
        appDelegate.centralManager.cancelPeripheralConnection(appDelegate.peripheral)
    }
    
    // トースト出力関数
    func showToast(message : String) {
        let toastLabel = UILabel(frame: CGRect(x: self.view.frame.size.width/2 - 150, y: self.view.frame.size.height/2, width: 300, height: 35))
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center;
        toastLabel.font = UIFont(name: "Montserrat-Light", size: 12.0)
        toastLabel.text = message
        toastLabel.alpha = 1.0
        toastLabel.layer.cornerRadius = 10;
        toastLabel.clipsToBounds  =  true
        self.view.addSubview(toastLabel)
        UIView.animate(withDuration: 4.0, delay: 0.1, options: .curveEaseOut, animations: {
            toastLabel.alpha = 0.0
        }, completion: {(isCompleted) in
            toastLabel.removeFromSuperview()
        })
    }
    
    /* キーボード追加ボタンイベント */
    
    @objc func escTapped() {
        print("esc")
    }
    
    @objc func upTapped() {
        print("up")
        if cursor[0] > 1 {
            cursor[0] = cursor[0] - 1
            viewCursor()
        }
    }
    
    @objc func downTapped() {
        print("down")
        if cursor[0] < getTextCount().count {
            cursor[0] = cursor[0] + 1
            viewCursor()
        }
    }
    
    @objc func leftTapped() {
        print("left")
        if cursor[1] > 1 {
            cursor[1] = cursor[1] - 1
            viewCursor()
        }
    }
    
    @objc func rightTapped() {
        print("right")
        if cursor[1] < getTextCount()[cursor[0] - 1] {
            cursor[1] = cursor[1] + 1
            viewCursor()
        }
    }
    
    /* Central関連メソッド */
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("CentralManagerState: \(central.state)")
        switch central.state {
        case .poweredOff:
            print("Bluetooth電源 : OFF")
            showToast(message: "Bluetoothの電源がOFF")
        case .poweredOn:
            print("Bluetooth電源 : ON")
        case .resetting:
            print("レスティング状態")
        case .unauthorized:
            print("非認証状態")
        case .unknown:
            print("不明")
        case .unsupported:
            print("非対応")
        }
    }
    
    // ペリフェラルへの接続が成功すると呼ばれる
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("接続成功")
        print("接続デバイス:\(appDelegate.peripheral.name!)")
        appDelegate.centralManager.stopScan()
        print("探索終了")
        
        // サービス探索結果を受け取るためにデリゲートをセット
        appDelegate.peripheral.delegate = self
        
        // サービス探索開始
        appDelegate.peripheral.discoverServices([appDelegate.mldpService_UUID])
    }
    
    /* Peripheral関連メソッド */
    
    // サービスを発見すると呼ばれる
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // エラーのときは原因を出力してreturn
        if error != nil {
            print(error.debugDescription)
            return
        }
        
        // 代入されたservicesがnilまたはカウントが0のときにguard文内へ進む
        guard let services = peripheral.services, services.count > 0 else {
            print("no services")
            return
        }
        
        print("\(services.count)個のサービスを検出 \(services)")
        // サービスの数だけキャラクタリスティック探索
        for service in services {
            // キャラクタリスティック探索開始
            appDelegate.peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    // キャラクタリスティックを発見すると呼ばれる
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            print(error.debugDescription)
            return
        }
        
        // 代入されたcharacteristicsがnilまたはカウントが0の時にguard文内へ進む
        guard let characteristics = service.characteristics, characteristics.count > 0 else {
            print("no characteristics")
            return
        }
        
        print("\(characteristics.count)個のキャラクタリスティックを検出 \(characteristics)")
        
        // whereを満たす間characteristicsからcharacteristicへ一つずつ取り出す
        // 複数個あってもMLDPのキャラクタリスティックにのみ反応するようにしている
        for characteristic in characteristics where characteristic.uuid.isEqual(appDelegate.mldpCharacteristic_UUID1) {
            appDelegate.outputCharacteristic = characteristic
            print("Write Indicate UUID を発見")
            // characteristicの値を読み取る
            peripheral.readValue(for: characteristic)
            
            // 更新通知受け取りを開始する
            peripheral.setNotifyValue(true, for: characteristic)
            
            // 書き込みデータの準備(文字を文字コードに変換?)
            let str = "App:on\r\n"
            let data = str.data(using: String.Encoding.utf8)
            
            // ペリフェラルにデータを書き込む
            peripheral.writeValue(data!, for: appDelegate.outputCharacteristic, type: CBCharacteristicWriteType.withResponse)
            
            showToast(message: "デバイス接続")
        }
    }
    
    // Notify開始/停止時に呼ばれる
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print(error.debugDescription)
        } else {
            print("Notify状態更新 characteristic UUID : \(characteristic.uuid), isNotifying : \(characteristic.isNotifying)")
        }
    }
    
    // データ更新時に呼ばれる
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print(error.debugDescription)
            return
        }
        
        textview.isScrollEnabled = false
        
        //  読み込みデータの取り出し(文字コードを文字に変換?)
        let data = characteristic.value
        let dataString = String(data: data!, encoding: String.Encoding.utf8)
        
        print("dataString:\(String(describing: dataString))")
        
        // 改行コードのとき
        if (dataString! == "\r") {
            writePrompt(textview.text)
            // カーソルを表示する
            viewCursor()
            
            viewEditFlag = 0
        }
        // それ以外のとき
        else {
            // textViewに読み込みデータを書き込む
            writeTextView(dataString!)
            
            // カーソルをずらす
            cursor[1] = cursor[1] + 1
            
            // カーソルを表示する
            viewCursor()
        }
    }
    
    // textview内のカーソル位置に文字を書き込む関数
    func writeTextView(_ string: String) {
        // textview内の文字列を改行で分割する
        let splitArray = textview.text!.components(separatedBy: CharacterSet.newlines)
        
        // カーソルの指す行を取得する
        let crText = splitArray[cursor[0] - 1]
        
        print("--- writeTextView ---")
        print("splitArray.count : \(splitArray.count)")
        print("get index : \(cursor[0] - 1)")
        print("crText : \(crText)\ncount : \(crText.count)")
        
        // カーソル前の文字列
        let preStr = String(crText.prefix(cursor[1] - 1))
        // カーソル後の文字列
        let aftStr = String(crText.suffix((crText.count - cursor[1]) + 1))
        
        // カーソル行の完成
        let curText = preStr + string + aftStr
        
        print("preString : \(preStr) , aftString : \(aftStr) , cursorString : \(curText)")
        
        // カーソル以外の行と結合
        var allText = ""
        for i in 0..<splitArray.count {
            if i == cursor[0] - 1 {
                allText.append(curText)
            }
            else {
                allText.append(splitArray[i] + "\n")
            }
        }
        
        print("allText : \(allText)")
        
        // textviewに設定する
        textview.text = allText
        
        // フォントを再設定する
        textview.font = UIFont(name: "CourierNewPSMT", size: textview.font!.pointSize)
    }
    
    // カーソルを表示する関数
    func viewCursor() {
        let stringAttributes: [NSAttributedStringKey : Any] = [.backgroundColor : UIColor.white, .foregroundColor : UIColor.black]
        let cursorAttributes: [NSAttributedStringKey : Any] = [.backgroundColor : UIColor.gray, .foregroundColor : UIColor.white]
        
        // textview内の文字列を改行で分割する
        let splitArray = textview.text!.components(separatedBy: CharacterSet.newlines)
        
        // カーソルの指す行を取得する
        let crText = splitArray[cursor[0] - 1]
        
        print("--- viewCursor ---")
        print("cursor : [ \(cursor[0]) , \(cursor[1]) ]")
        print("splitArray.count : \(splitArray.count)")
        print("get index : \(cursor[0] - 1)")
        print("crText : \(crText)\ncount : \(crText.count)")
        
        // カーソル前の文字列
        let preChar = String(crText.prefix(cursor[1] - 1))
        // カーソル文字
        let curChar = String(crText.prefix(cursor[1]).suffix(1))
        // カーソル後の文字列
        let aftChar = String(crText.suffix(crText.count - cursor[1]))
        
        let preString = NSMutableAttributedString(string: preChar, attributes: stringAttributes)
        let cursorString = NSMutableAttributedString(string: curChar, attributes: cursorAttributes)
        let aftString = NSMutableAttributedString(string: aftChar, attributes: stringAttributes)
        
        print("preString : \(preChar) , cursorString : \(curChar) , aftString : \(aftChar)")
        
        // カーソル行の完成
        let curText = NSMutableAttributedString()
        curText.append(preString)
        curText.append(cursorString)
        curText.append(aftString)
        
        // カーソル以外の行と結合
        let allText = NSMutableAttributedString()
        print("splitArray.count : \(splitArray.count)")
        for i in 0..<splitArray.count {
            if i == cursor[0] - 1 {
                allText.append(curText)
                print("curText appended")
            }
            else {
                let text = NSMutableAttributedString(string: splitArray[i] + "\n", attributes: stringAttributes)
                allText.append(text)
                print("plainText appended")
            }
        }
        
        // textviewに設定する
        textview.attributedText = allText
        // フォントを再設定する
        textview.font = UIFont(name: "CourierNewPSMT", size: textview.font!.pointSize)
    }
    
    // プロンプトを書き込む関数(カーソルはプロンプトの次に移動させる)
    func writePrompt(_ string: String) {
        var getText = string
        
        // カーソルが最後尾にある場合
        if curIsEnd() && getText.count != 0 {
            // カーソル用文字を取り除く
            getText = String(getText.prefix(getText.count - 1))
        }
        
        // 文字列が既にあるなら改行する
        if getText != "" {
            getText = getText + "\n"
        }
        
        print("--- writePrompt ---")
        print("getText : \(getText)")
        
        let cursorAttributes: [NSAttributedStringKey : Any] = [.backgroundColor : UIColor.gray, .foregroundColor : UIColor.white]
        let attrText = NSMutableAttributedString(string: "_", attributes: cursorAttributes)
        let plainText = NSMutableAttributedString(string: getText)
        let prompt = NSMutableAttributedString(string: ">")
        
        let text = NSMutableAttributedString()
        text.append(plainText)
        text.append(prompt)
        text.append(attrText)
        
        // textviewに設定する
        textview.attributedText = text
        // フォントを再設定する
        textview.font = UIFont(name: "CourierNewPSMT", size: textview.font!.pointSize)
        
        // textview内の文字列を改行で分割する
        let splitArray = textview.text!.components(separatedBy: CharacterSet.newlines)
        // カーソル位置をずらす
        cursor[0] = splitArray.count
        cursor[1] = 2
    }
    
    // カーソルの文末判断をする関数
    func curIsEnd() -> Bool {
        // textview内の文字列を改行で分割する
        let splitArray = textview.text!.components(separatedBy: CharacterSet.newlines)
        
        print("--- curIsEnd ---")
        print("cursor : [ \(cursor[0]) , \(cursor[1]) ]")
        print("splitArray.count : \(splitArray.count)")
        
        // カーソルが最後の行にある場合
        if cursor[0] == splitArray.count {
            print("splitArray[cursor[0] - 1].count : \(splitArray[cursor[0] - 1].count)")
            // カーソルが文末にある場合
            if cursor[1] == splitArray[cursor[0] - 1].count {
                return true
            }
        }
        return false
    }
    
    // textviewの行数と各行の文字数を返す関数
    func getTextCount() -> [Int] {
        // 文字数カウント変数
        var count = [Int]()
        
        // textview内の文字列を改行で分割する
        let splitArray = textview.text!.components(separatedBy: CharacterSet.newlines)
        
        // 各行の文字数を格納する
        for i in 0..<splitArray.count {
            count.append(splitArray[i].count)
        }
        
        print("--- getTextCount ---")
        for i in 0..<count.count {
            print("row : \(i + 1) , column : \(count[i])")
        }
        
        return count
    }
    
    // textviewを最下までスクロールする関数
    func scrollToButtom() {
        textview.selectedRange = NSRange(location: textview.text.count, length: 0)
        textview.isScrollEnabled = true
        
        let scrollY = textview.contentSize.height - textview.bounds.height
        let scrollPoint = CGPoint(x: 0, y: scrollY > 0 ? scrollY : 0)
        textview.setContentOffset(scrollPoint, animated: false)
    }
    
}

