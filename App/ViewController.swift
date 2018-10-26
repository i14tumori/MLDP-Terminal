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
    var timer: Timer?
    
    // テキスト入力可能判断用フラグ(0: iPhone 入力可 , 1: iPhone 入力不可)
    var viewEditFlag = 0
    
    // カーソル位置記憶変数
    var cursor = [0, 0]
    
    // コマンド記憶変数
    var commandList = [String]()
    // コマンド一時記憶変数
    var tempCommand = ""
    // commandListの添字変数
    var commandIndex = 0
    
    @IBOutlet weak var textview: UITextView!
    
    // AppDelegate内の変数呼び出し用
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // TextViewに枠線をつける
        textview.layer.borderColor = UIColor.gray.cgColor
        textview.layer.borderWidth = 0.5
 
        // TextViewのデリゲートをセット
        textview.delegate = self
        
        // コマンド記憶の準備
        commandList.append("")
        
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
        // 編集不可判断,入力文字制限(DELは空文字になるため制限する)
        if (viewEditFlag == 1 || (!text.isAlphanumeric(text) && text != "")) {
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
                // レスポンスがあるまで書き込み不可にする
                viewEditFlag = 1
                
                textview.isScrollEnabled = false
                
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
                
                // コマンドが入力されていなければプロンプトを表示する
                if txText == "" {
                    // プロンプトを追記
                    writePrompt(textview.text)
                    // カーソルを表示する
                    viewCursor()
                    // 書き込みを許可する
                    viewEditFlag = 0
                    // 画面をスクロールする
                    scrollToButtom()
                }
                else {
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
                    
                    // 改行を追記する
                    if curIsEnd() {
                        textview.text = textview.text.prefix(textview.text.count - 1) + "\n" + textview.text.suffix(1)
                    }
                    else {
                        textview.text = textview.text + "\n_"
                    }
                    
                    // コマンド記憶サイズを超えている場合は古い方から削除する
                    if commandList.count >= maxLength {
                        commandList.removeFirst()
                    }
                    // 次のコマンドを記憶する準備
                    commandList.append("")
                    
                    // commandListの添字を初期化する
                    commandIndex = 0
                    
                    // カーソルをずらす
                    cursor[0] = cursor[0] + 1
                    cursor[1] = 1
                    
                    // カーソルを表示する
                    viewCursor()
                }
            }
        }
        // 空文字(DELキー)のとき
        else if text == "" {
            if cursor[1] > 2 {
                // カーソル位置の文字を削除する
                deleteTextView()
                
                // 現在のコマンドを示す添字
                let index = commandList.count - 1
                // コマンド
                let command = commandList[index]
                // コマンドがあるなら一文字削除する
                if command.count > 0 {
                    // コマンドから一文字削除する
                    commandList[index] = String(commandList[index].prefix(command.count - 1))
                }
                
                // カーソルをずらす
                cursor[1] = cursor[1] - 1
                
                // カーソルを表示する
                viewCursor()
            }
        }
        else {
            // カーソル位置に追記する
            writeTextView(text)
            
            // コマンドとして追記する
            commandList[commandList.count - 1].append(text)
            
            // カーソルをずらす
            cursor[1] = cursor[1] + 1
            
            // カーソルを表示する
            viewCursor()
        }
        
        // 画面をスクロールする
        scrollToButtom()
        
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
        
        // コマンド記憶の初期化
        commandList.removeAll()
        commandList.append("")
        // コマンド添字初期化
        commandIndex = 0
        
        // iPhoneの入力を許可
        viewEditFlag = 0
    }
    
    // scanButtonが押されたとき
    @IBAction func scanButtonTapped(_ sender: UIButton) {
        print("scan button tapped")
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
    
    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        print("deviceDelete button tapped")
        UserDefaults.standard.removeObject(forKey: "DeviceName")
    }
    
    // トースト出力関数
    // message : トーストする文字列
    func showToast(message: String) {
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
    
    // 追加ボタンESCが押されたとき
    @objc func escTapped() {
        print("--- esc ---")
        // ペリフェラルとつながっていないときは何もしない
        if appDelegate.outputCharacteristic == nil {
            return
        }
        let data = "\u{1b}".data(using: .utf8)
        // ペリフェラルにエスケープを書き込む
        appDelegate.peripheral.writeValue(data!, for: appDelegate.outputCharacteristic, type: CBCharacteristicWriteType.withResponse)
    }
    
    // 追加ボタンCtrlが押されたとき
    @objc func ctrlTapped() {
        print("--- ctrl ---")
    }
    
    // 追加ボタン↑が押されたとき
    @objc func upTapped() {
        print("--- up ---")
        // 入力不可のときは何もしない
        if viewEditFlag == 1 {
            return
        }
        // 記憶したコマンドがあるとき
        if commandList.count - 2 >= commandIndex {
            // 元のコマンドを記憶する
            if commandIndex == 0 {
                tempCommand = commandList[commandList.count - 1]
            }
            // 表示するコマンドを変化させる
            commandIndex = commandIndex + 1
            // textview内の文字列を改行で分割する
            let splitArray = textview.text!.components(separatedBy: CharacterSet.newlines)
            
            // 最後の2行以外を改行ありで結合する
            var allText = ""
            for i in 0..<splitArray.count - 2 {
                allText.append(splitArray[i] + "\n")
            }
            // 最後から2番目の行を改行なしで結合する
            allText.append(splitArray[splitArray.count - 2])
            
            // コマンドを書き換える
            writePrompt(allText)
            writeTextView(commandList[(commandList.count - 1) - commandIndex])
            // コマンド記憶も書き換える
            commandList[commandList.count - 1] = commandList[(commandList.count - 1) - commandIndex]
            
            // カーソルをずらす
            cursor[1] = cursor[1] + commandList[commandList.count - 1].count
            // カーソルを表示する
            viewCursor()
        }
    }
    
    // 追加ボタン↓が押されたとき
    @objc func downTapped() {
        print("--- down ---")
        // 入力不可のときは何もしない
        if viewEditFlag == 1 {
            return
        }
        print("commandList.count - 1 : \(commandList.count - 1)\ncommandIndex : \(commandIndex)")
        // 記憶したコマンドがあるとき
        if commandIndex > 0 {
            // 表示するコマンドを変化させる
            commandIndex = commandIndex - 1
            // 元に戻ってきたら記憶した元コマンドを復旧する
            if commandIndex == 0 {
                commandList[commandList.count - 1] = tempCommand
            }
            // textview内の文字列を改行で分割する
            let splitArray = textview.text!.components(separatedBy: CharacterSet.newlines)
            
            // 最後の2行以外を改行ありで結合する
            var allText = ""
            for i in 0..<splitArray.count - 2 {
                allText.append(splitArray[i] + "\n")
            }
            // 最後から2番目の行を改行なしで結合する
            allText.append(splitArray[splitArray.count - 2])
            
            // コマンドを書き換える
            writePrompt(allText)
            writeTextView(commandList[(commandList.count - 1) - commandIndex])
            // コマンド記憶も書き換える
            commandList[commandList.count - 1] = commandList[(commandList.count - 1) - commandIndex]
            
            // カーソルをずらす
            cursor[1] = cursor[1] + commandList[commandList.count - 1].count
            // カーソルを表示する
            viewCursor()
        }
    }
    
    // 追加ボタン←が押されたとき
    @objc func leftTapped() {
        print("--- left ---")
        // 入力不可のときは何もしない
        if viewEditFlag == 1 {
            return
        }
        // カーソルを一つ左にずらす
        moveLeft()
    }
    
    // カーソルを左にずらす関数(カーソル表示含む)
    // attr : ずらす量を調整する引数 (top : 行先頭にずらす)
    // parent : 呼び出し元の関数名
    func moveLeft(attr: String = "", parent: String = #function) {
        print("--- moveLeft ---")
        // カーソル移動を制限するための変数
        var limit = 1
        // 呼び出し元がleftTapped()の場合プロンプトの分だけ移動を制限する
        if parent == "leftTapped()" {
            limit = 2
        }
        // カーソルを移動させられるとき
        if cursor[1] > limit {
            // textview内の文字列を改行で分割する
            var splitArray = textview.text!.components(separatedBy: CharacterSet.newlines)
            // カーソルの指す行を取得する
            let crText = splitArray[cursor[0] - 1]
            // カーソル文字を削除する
            if cursor[1] == crText.count && crText.suffix(1) == "_"{
                splitArray[cursor[0] - 1] = String(crText.prefix(crText.count - 1))
                // 結合した文字列をtextviewに設定する
                textview.text = splitArray.joined(separator: "\n")
            }
            // カーソルをずらす
            if attr == "top" {
                cursor[1] = 1
            }
            else if attr == "" {
                cursor[1] = cursor[1] - 1
            }
            viewCursor()
        }
    }
    
    // ??? 呼ばれない
    @objc func leftPress(gesture: UILongPressGestureRecognizer) {
        print("--- leftPress ---")
        if gesture.state == .began {
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { (_) in
                guard let _ = self.timer else {
                    return
                }
                // 呼び出し
            }
        }
        if gesture.state == .ended {
            timer?.invalidate()
        }
    }
    
    // 追加ボタン→が押されたとき
    @objc func rightTapped() {
        print("--- right ---")
        // 入力不可のときは何もしない
        if viewEditFlag == 1 {
            return
        }
        // カーソルを一つ右にずらす
        moveRight()
    }
    
    // カーソルを右にずらす関数(カーソル表示含む)
    // attr : ずらす量を調整する引数 (end : 行末尾にずらす)
    func moveRight(attr: String = "") {
        // textview内の文字列を改行で分割する
        var splitArray = textview.text!.components(separatedBy: CharacterSet.newlines)
        // カーソルの指す行を取得する
        let crText = splitArray[cursor[0] - 1]
        // カーソルを移動させられるとき
        if cursor[1] < getTextCount()[cursor[0] - 1] || crText.suffix(1) != "_" {
            // カーソル文字を追加する
            if (cursor[1] == crText.count && crText.suffix(1) != "_") || attr == "end" {
                splitArray[cursor[0] - 1] = crText + "_"
                // 結合した文字列をtextviewに設定する
                textview.text = splitArray.joined(separator: "\n")
            }
            // カーソルをずらす
            if attr == "end" {
                cursor[1] = splitArray[cursor[0] - 1].count
            }
            else if attr == "" {
                cursor[1] = cursor[1] + 1
            }
            viewCursor()
        }
    }
    
    /* Central関連メソッド */
    
    // centralManagerの状態が変化すると呼ばれる
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
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
    
    // ペリフェラルとの切断が完了すると呼ばれる
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("disconnectperiferal complete")
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
        
        // 書き込み不可なら何もしない
        if viewEditFlag == 0 {
            return
        }
        
        textview.isScrollEnabled = false
        
        //  読み込みデータの取り出し
        let data = characteristic.value
        let dataString = String(data: data!, encoding: String.Encoding.utf8)
        
        print("dataString:\(String(describing: dataString))")
        
        // Ctrl+d(EOT : 転送終了)のとき
        if dataString! == "\u{04}" {
            print("End of Transmission")
            // プロンプトを書き込む
            writePrompt(textview.text)
            // カーソルを表示する
            viewCursor()
            
            // iPhoneからの書き込みを許可する
            viewEditFlag = 0
        }
        // Ctrl+a(カーソルを行先頭に移動)のとき
        else if dataString! == "\u{01}" {
            print("move to Top")
            moveLeft(attr: "top")
        }
        // Ctrl+b(カーソルを一文字左に移動)のとき
        else if dataString! == "\u{02}" {
            moveLeft()
        }
        // Ctrl+e(カーソルを行末尾に移動)のとき
        else if dataString! == "\u{05}" {
            print("move to End")
            moveRight(attr: "end")
        }
        // Ctrl+f(カーソルを一文字右に移動)のとき
        else if dataString! == "\u{06}" {
            moveRight()
        }
        // エスケープのとき
        else if dataString! == "\u{1b}" {
            
        }
        // それ以外のとき
        else {
            // textViewに読み込みデータを書き込む
            writeTextView(dataString!)
            
            // カーソルをずらす
            if dataString! == "\r" {
                cursor[0] = cursor[0] + 1
                cursor[1] = 1
            }
            else {
                cursor[1] = cursor[1] + 1
            }
            
            // カーソルを表示する
            viewCursor()
        }
        // 画面をスクロールする
        scrollToButtom()
    }
    
    // textview内のカーソル位置に文字を書き込む関数
    // string : 書き込む文字
    func writeTextView(_ string: String) {
        textview.isScrollEnabled = false
        // textview内の文字列を改行で分割する
        var splitArray = textview.text!.components(separatedBy: CharacterSet.newlines)
        
        // カーソルの指す行を取得する
        var crText = splitArray[cursor[0] - 1]
        
        print("--- writeTextView ---")
        print("splitArray.count : \(splitArray.count)")
        print("get index : \(cursor[0] - 1)")
        print("crText : \(crText)\ncount : \(crText.count)")
        
        // カーソル前の文字列
        let preStr = String(crText.prefix(cursor[1] - 1))
        // カーソル後の文字列
        let aftStr = String(crText.suffix((crText.count - cursor[1]) + 1))
        
        // カーソル行の完成
        crText = preStr + string + aftStr
        
        print("preString : \(preStr) , aftString : \(aftStr) , cursorString : \(crText)")
        
        // カーソル以外の行と結合
        splitArray[cursor[0] - 1] = crText
        let allText = splitArray.joined(separator: "\n")
        
        print("allText : \(allText)")
        
        // textviewに設定する
        textview.text = allText
        
        // フォントを再設定する
        textview.font = UIFont(name: "CourierNewPSMT", size: textview.font!.pointSize)
        
        // 画面をスクロールする
        scrollToButtom()
    }
    
    // カーソル位置の一つ前の文字を削除する関数
    func deleteTextView() {
        // textview内の文字列を改行で分割する
        var splitArray = textview.text!.components(separatedBy: CharacterSet.newlines)
        
        // カーソルの指す行を取得する
        var crText = splitArray[cursor[0] - 1]
        
        print("--- deleteTextView ---")
        print("splitArray.count : \(splitArray.count)")
        print("get index : \(cursor[0] - 1)")
        print("crText : \(crText)\ncount : \(crText.count)")
        
        // カーソル前の文字列 - カーソル文字
        let preStr = String(crText.prefix(cursor[1] - 2))
        // カーソル後の文字列
        let aftStr = String(crText.suffix((crText.count - cursor[1]) + 1))
        
        // 削除後の文の完成
        crText = preStr + aftStr
        
        print("preString : \(preStr) , aftString : \(aftStr) , cursorString : \(crText)")
        
        // カーソル以外の行と結合
        splitArray[cursor[0] - 1] = crText
        let allText = splitArray.joined(separator: "\n")
        
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
        
        // textviewの行数を取得する
        let columnCount = getTextCount().count
        
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
        let CRString = NSMutableAttributedString(string: "\n", attributes: stringAttributes)
        
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
                // カーソル行が最後行でないなら改行する
                if cursor[0] != columnCount {
                    curText.append(CRString)
                }
                allText.append(curText)
            }
            else {
                let text = NSMutableAttributedString(string: splitArray[i], attributes: stringAttributes)
                // iの示す行が最後行でないなら改行する
                if i != columnCount - 1 {
                    text.append(CRString)
                }
                allText.append(text)
            }
        }
        
        // textviewに設定する
        textview.attributedText = allText
        // フォントを再設定する
        textview.font = UIFont(name: "CourierNewPSMT", size: textview.font!.pointSize)
    }
    
    // プロンプトを書き込む関数(カーソルはプロンプトの次に移動させ、描画はしない)
    // string : プロンプトを書き込む文字列
    func writePrompt(_ string: String) {
        var getText = string
        
        // カーソルが最後尾にある場合
        if curIsEnd() && getText.suffix(1) == "_" && getText.count != 0 {
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
        print("--- curIsEnd ---")
        print("cursor : [ \(cursor[0]) , \(cursor[1]) ]")
        
        // textviewの行数、各行の文字数を取得する
        let textCount = getTextCount()
        print("textCount : \(textCount)")
        // カーソルが最後尾を示しているならtrueを返す
        if cursor[0] == textCount.count && cursor[1] == textCount[textCount.count - 1] {
            return true
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

