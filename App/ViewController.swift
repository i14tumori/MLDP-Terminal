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
    // String型を一文字ずつの配列に分解する関数
    func partition(_ text: String) -> [String] {
        let count = text.count
        var origin = text
        var splitText = [String]()
        for _ in 0..<count {
            splitText.append(String(origin.prefix(1)))
            origin = String(origin.suffix(origin.count - 1))
        }
        print("--- partition ---")
        print("partition : \(splitText)")
        return splitText
    }
    // 英数字の判定をする関数
    func isAlphanumeric(_ text: String) -> Bool {
        return text >= "\0" && text <= "~"
    }
    // 数字の判定をする関数
    func isNumeric(_ text: String) -> Bool {
        let partText = text.partition(text)
        for i in 0..<text.count {
            if partText[i] < "0" || partText[i] > "9" {
                return false
            }
        }
        return true
    }
}

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, UITextViewDelegate {
       
    var response = ""
    let maxLength = 18
    var timer: Timer?
    
    // プロンプト
    var promptStr = ">"
    // プロンプトの長さ
    var promptLength = 0
    
    // テキスト入力判断用フラグ(0: iPhoneから入力 , 1: BLEから入力)
    var viewEditFlag = 0
    // 上書き判断用フラグ
    var overWrite = false
    
    // エスケープシーケンス判断用フラグ
    var escSeq = 0
    // エスケープシーケンス変位記憶変数
    var escDisplace = [0, 0]
    
    // カーソル位置記憶変数
    var cursor = [1, 1]
    // コマンド長記憶変数
    var commandLength = 0
    
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
        
        // TextViewのフォントサイズを設定する
        textview.font = UIFont.systemFont(ofSize: 12.00)
 
        // TextViewのデリゲートをセット
        textview.delegate = self
        
        // コマンド記憶の準備
        commandList.append("")
        
        // プロンプト,カーソル表示
        clearButtonTapped(UIButton())
        
        // テキストのフォント設定
        textview.font = UIFont(name: "CourierNewPSMT", size: textview.font!.pointSize)
        print("--- viewDidLoad ---\nfont : \(String(describing: textview.font))")
        print("pointSize : \(textview.font!.pointSize)")
        
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
        print("--- textView Edit ---")
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
                let splitArray = getText()
                var txText = splitArray[splitArray.count - 1]
                
                // カーソル用空白文字,プロンプトを取り除く
                if txText.count > 1 {
                    print("curIsSentenceEnd : \(curIsSentenceEnd)")
                    // カーソルが文末にあるとき
                    if curIsSentenceEnd() {
                        print("txText : \(txText)\ntxText.prefix(txText.count - 1) : \(txText.prefix(txText.count - 1))")
                        // カーソル用空白文字の除去
                        txText = String(txText.prefix(txText.count - 1))
                    }
                    // プロンプトの除去
                    txText = String(txText.suffix(txText.count - promptLength))
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
                
                // プロンプトの長さを初期化
                promptLength = 0
                    
                // カーソルを表示する
                viewCursor()
            }
        }
        // 空文字(DELキー)のとき
        else if text == "" {
            if cursor[1] > 1 {
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
            cursor[1] = cursor[1] + text.count
            
            // カーソルを表示する
            viewCursor()
        }
        
        // 画面をスクロールする
        scrollToButtom()
        
        // デフォルトカーソル(青縦棒)位置への追記はしない
        return false
    }
    
    // clearButtonが押されたとき
    // textViewをクリアする
    @IBAction func clearButtonTapped(_ sender: UIButton) {
        print("clear button tapped")
        
        // フォントを再設定する
        textview.font = UIFont(name: "CourierNewPSMT", size: textview.font!.pointSize)
        print("--- clearButtonTapped ---\nfont : \(String(describing: textview.font))")
        print("pointSize : \(textview.font!.pointSize)")
        
        // textviewをクリアする
        textview.text = "_"
        
        // カーソル位置を初期化する
        cursor[0] = 1
        cursor[1] = 1
        // プロンプトの長さを初期化
        promptLength = 0
        // カーソル表示
        writePrompt()
        
        // コマンド記憶の初期化
        commandList.removeAll()
        commandList.append("")
        // コマンド添字初期化
        commandIndex = 0
        
        // iPhoneの入力を許可
        viewEditFlag = 0
    }
    
    // scanButtonが押されたとき
    // ペリフェラルスキャンを開始する
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
    
    // deleteButtonが押されたとき
    // 記憶デバイスを消去する
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
            
            // 最後の行以外を改行ありで結合する
            var allText = ""
            for i in 0..<splitArray.count - 1 {
                allText.append(splitArray[i] + "\n")
            }
            
            // プロンプトとカーソル文字を付け足し，textViewに設定する
            allText.append(splitArray[splitArray.count - 1].prefix(promptLength) + "_")
            textview.text = allText
            
            // textviewの文字数を取得する
            let count = getTextCount()
            
            // カーソル位置をずらす
            cursor[0] = count.count
            cursor[1] = count[cursor[0] - 1] - promptLength
            
            // コマンドを書き換える
            writeTextView(commandList[(commandList.count - 1) - commandIndex])
            // コマンド記憶も書き換える
            commandList[commandList.count - 1] = commandList[(commandList.count - 1) - commandIndex]
            
            // コマンド文字数カーソルをずらす
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
            
            // 最後の行以外を改行ありで結合する
            var allText = ""
            for i in 0..<splitArray.count - 1 {
                allText.append(splitArray[i] + "\n")
            }
            
            // プロンプトとカーソル文字を付け足し，textViewに設定する
            allText.append(splitArray[splitArray.count - 1].prefix(promptLength) + "_")
            textview.text = allText
            
            // textviewの文字数を取得する
            let count = getTextCount()
            
            // カーソル位置をずらす
            cursor[0] = count.count
            cursor[1] = count[cursor[0] - 1] - promptLength
            
            // コマンドを書き換える
            writeTextView(commandList[(commandList.count - 1) - commandIndex])
            // コマンド記憶も書き換える
            commandList[commandList.count - 1] = commandList[(commandList.count - 1) - commandIndex]
            
            // コマンド文字数カーソルをずらす
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
    func moveLeft(attr: String = "") {
        print("--- moveLeft ---")
        // カーソル移動を制限するための変数
        let limit = 1
        // カーソルを移動させられるとき
        if cursor[1] > limit {
            // textview内の文字列を改行で分割する
            var splitArray = textview.text!.components(separatedBy: CharacterSet.newlines)
            // カーソルの指す行を取得する
            let crText = splitArray[cursor[0] - 1]
            // カーソル文字を削除する
            if cursor[1] == crText.count - promptLength && crText.suffix(1) == "_"{
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
        if cursor[1] < getTextCount()[cursor[0] - 1] - promptLength || crText.suffix(1) != "_" {
            // カーソル文字を追加する
            if (cursor[1] == crText.count - promptLength && crText.suffix(1) != "_") || attr == "end" {
                splitArray[cursor[0] - 1] = crText + "_"
                // 結合した文字列をtextviewに設定する
                textview.text = splitArray.joined(separator: "\n")
            }
            // カーソルをずらす
            if attr == "end" {
                cursor[1] = splitArray[cursor[0] - 1].count - promptLength
            }
            else if attr == "" {
                cursor[1] = cursor[1] + 1
            }
            viewCursor()
        }
    }
    
    /* エスケープシーケンスメソッド */
    
    // 上にn移動する関数
    func escUp(n: Int) {
        print("--- escUp ---")
        print("n : \(n)")
    }
    
    // 下にn移動する関数
    func escDown(n: Int) {
        print("--- escDown ---")
        print("n : \(n)")
    }
    
    // 右にn移動する関数
    func escRight(n: Int) {
        print("--- escRight ---")
        print("n : \(n)")
    }
    
    // 左にn移動する関数
    func escLeft(n: Int) {
        print("--- escLeft ---")
        print("n : \(n)")
    }
    
    // n行下の先頭に移動する関数
    func escDownTop(n: Int) {
        print("--- escDownTop ---")
        print("n : \(n)")
    }
    
    // n行上の先頭に移動する関数
    func escUpTop(n: Int) {
        print("--- escUpTop ---")
        print("n : \(n)")
    }
    
    // 現在位置と関係なく上からn、左からmの場所に移動する関数
    func escRoot(n: Int, m: Int) {
        print("--- escRoot ---")
        print("n : \(n), m : \(m)")
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
        print("disconnect complete")
        // データを初期化する
        appDelegate.isScanning = false
        appDelegate.centralManager = CBCentralManager()
        appDelegate.settingCharacteristic = nil
        appDelegate.outputCharacteristic = nil
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
        
        print("--- peripheral Update ---")
        print("cursor : [ \(cursor[0]), \(cursor[1]) ]")
        
        //  読み込みデータの取り出し
        let data = characteristic.value
        let dataString = String(data: data!, encoding: String.Encoding.utf8)
        
        print("dataString:\(String(describing: dataString))")
        
        // Ctrl+d(EOT : 転送終了)のとき
        if dataString! == "\u{04}" {
            print("End of Transmission")
            
            // プロンプトの長さを更新
            promptLength = cursor[1] - 1
            // カーソル位置を初期化
            cursor[1] = 1
            // プロンプトを書き込む
            writePrompt()
            // カーソルを表示する
            viewCursor()
            
            // iPhoneからの書き込みを許可する
            viewEditFlag = 0
            // エスケープシーケンス判定を初期化
            escSeq = 0
        }
        // エスケープシーケンスのとき
        else if escSeq > 0{
            switch escSeq {
            // シーケンス一文字目
            case 1:
                // 正しいシーケンスのとき
                if dataString! == "[" {
                    escSeq = 2
                }
                // シーケンスではなかったとき
                else {
                    print("NO ESC_SEQ")
                    escSeq = 0
                }
            // シーケンス二文字目
            case 2:
                // 正しいシーケンスのとき
                if dataString!.isNumeric(dataString!) {
                    // 変位を記憶する
                    escDisplace[0] = Int(dataString!)!
                    escSeq = 3
                }
                // シーケンスではなかったとき
                else {
                    print("NO ESC_SEQ")
                    escSeq = 0
                }
            // シーケンス三文字目
            case 3:
                switch dataString! {
                // 正しいシーケンスのとき
                case "A":
                    escUp(n: escDisplace[0])
                    escSeq = 0
                case "B":
                    escDown(n: escDisplace[0])
                    escSeq = 0
                case "C":
                    escRight(n: escDisplace[0])
                    escSeq = 0
                case "D":
                    escLeft(n: escDisplace[0])
                    escSeq = 0
                case "E":
                    escDownTop(n: escDisplace[0])
                    escSeq = 0
                case "F":
                    escUpTop(n: escDisplace[0])
                    escSeq = 0
                case "G":
                    escRoot(n: cursor[0], m: escDisplace[0])
                    escSeq = 0
                case ";":
                    escSeq = 4
                // シーケンスではなかったとき
                default:
                    print("NO ESC_SEQ")
                    escSeq = 0
                }
            // シーケンス四文字目
            case 4:
                // 正しいシーケンスのとき
                if dataString!.isNumeric(dataString!) {
                    // 変位を記憶する
                    escDisplace[1] = Int(dataString!)!
                    escSeq = 5
                }
                // シーケンスではなかったとき
                else {
                    print("NO ESC_SEQ")
                    escSeq = 0
                }
            // シーケンス五文字目
            case 5:
                // 正しいシーケンスのとき
                if dataString! == "H" || dataString! == "f" {
                    escRoot(n: escDisplace[0], m: escDisplace[1])
                    escSeq = 0
                }
                // シーケンスではなかったとき
                else {
                    print("NO ESC_SEQ")
                    escSeq = 0
                }
            default: break
            }
        }
        // エスケープのとき　(テスト用に # で動作する)
        else if dataString! == "\u{1b}" || dataString! == "#" {
            escSeq = 1
        }
            
        /* デバッグ用のカーソル移動 */
            
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
            
        /* デバッグ用のカーソル移動 ここまで */
            
        // それ以外のとき
        else {
            // textViewに読み込みデータを書き込む
            writeTextView(dataString!)
            
            // カーソルをずらす
            if dataString! == "\r" {
                cursor[0] = cursor[0] + 1
                cursor[1] = 1
                // プロンプトの長さを初期化する
                promptLength = 0
            }
            else {
                cursor[1] = cursor[1] + dataString!.count
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
        print("string : \(string)")
        print("cursor : [ \(cursor[0]), \(cursor[1]) ]")
        print("splitArray.count : \(splitArray.count)")
        print("get index : \(cursor[0] - 1)")
        print("crText : \(crText)\ncount : \(crText.count)")
        print("promptLength : \(promptLength)")
        /*
        // カーソル前の文字列
        let preStr = String(crText.prefix((cursor[1] + promptLength) - 1))
        print("preStr : \(preStr)")
        // カーソル後の文字列
        let aftStr = String(crText.suffix((crText.count - (cursor[1] + promptLength)) + 1))
        print("aftStr : \(aftStr)")
        */
        // カーソル前の文字列
        let preStr = String(crText.prefix((cursor[1] + promptLength) - 1))
        print("preStr : \(preStr)")
        // カーソル後の文字列
        var aftStr: String
        // 上書きのとき(カーソルが示す文字を含まない)
        if overWrite {
            aftStr = String(crText.suffix(crText.count - (cursor[1] + promptLength)))
            // 最後まで上書きされた場合
            if aftStr == "" {
                // カーソルを追加
                aftStr = "_"
                // 追記に変更する
                overWrite = false
            }
        }
        // 追記のとき(カーソルが示す文字を含む)
        else {
            aftStr = String(crText.suffix((crText.count - (cursor[1] + promptLength)) + 1))
        }
        print("aftStr : \(aftStr)")
        
        // カーソル行の完成
        crText = preStr + string + aftStr
        
        print("cursorString : \(crText)")
        
        // カーソル以外の行と結合
        splitArray[cursor[0] - 1] = crText
        let allText = splitArray.joined(separator: "\n")
        
        print("allText : \(allText)")
        
        // textviewに設定する
        textview.text = allText
        
        // フォントを再設定する
        textview.font = UIFont(name: "CourierNewPSMT", size: textview.font!.pointSize)
        print("--- writeTextView ---\nfont : \(String(describing: textview.font))")
        print("pointSize : \(textview.font!.pointSize)")
        
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
        let preStr = String(crText.prefix((cursor[1] + promptLength) - 2))
        // カーソル後の文字列
        let aftStr = String(crText.suffix((crText.count - (cursor[1] + promptLength)) + 1))
        
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
        print("--- deleteTextView ---\nfont : \(String(describing: textview.font))")
        print("pointSize : \(textview.font!.pointSize)")
    }
    
    // カーソルを表示する関数
    func viewCursor() {
        let stringAttributes: [NSAttributedStringKey : Any] = [.backgroundColor : UIColor.white, .foregroundColor : UIColor.black]
        let cursorAttributes: [NSAttributedStringKey : Any] = [.backgroundColor : UIColor.gray, .foregroundColor : UIColor.white]
        
        // textview内の文字列を改行で分割する
        let splitArray = textview.text!.components(separatedBy: CharacterSet.newlines)
        
        print("--- viewCursor ---")
        print("cursor : [ \(cursor[0]) , \(cursor[1]) ]")
        print("real cursorPlace : [ \(cursor[0]) , \(cursor[1] + promptLength) ]")
        print("splitArray.count : \(splitArray.count)")
        print("get index : \(cursor[0] - 1)")
        
        // カーソルの指す行を取得する
        let crText = splitArray[cursor[0] - 1]
        
        // textviewの行数を取得する
        let columnCount = getTextCount().count
    
        print("crText : \(crText)\ncount : \(crText.count)")
        print("promptLength : \(promptLength)")
        
        // カーソル前の文字列
        let preChar = String(crText.prefix((cursor[1] + promptLength) - 1))
        // カーソル文字
        let curChar = String(crText.prefix(cursor[1] + promptLength).suffix(1))
        // カーソル後の文字列
        let aftChar = String(crText.suffix(crText.count - (cursor[1] + promptLength)))
        
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
        print("--- viewCursor ---\nfont : \(String(describing: textview.font))")
        print("pointSize : \(textview.font!.pointSize)")
    }
    
    // プロンプトを書き込む関数(現在のカーソル位置に書き込み，プロンプトの長さを更新する)
    func writePrompt() {
        print("--- writePrompt ---")
        
        // カーソルが文末を示しているとき
        if curIsSentenceEnd() {
            overWrite = false
        }
        // カーソルが文途中を示しているとき
        else {
            overWrite = true
        }
        
        // プロンプト文字を書き込む
        writeTextView(promptStr)
        promptLength = promptLength + promptStr.count
        
        // カーソルを表示する
        viewCursor()
    }
    
    // カーソルの最後尾判断をする関数
    func curIsEnd() -> Bool {
        print("--- curIsEnd ---")
        print("cursor : [ \(cursor[0]) , \(cursor[1]) ]")
        print("real cursorPlace : [ \(cursor[0]) , \(cursor[1] + promptLength) ]")
        
        // textviewの文字列を取得する
        let text = getText()
        // textviewの行数、各行の文字数を取得する
        let textCount = getTextCount()
        print("text : \(text)")
        print("textCount : \(textCount)")
        // カーソルが最後尾を示しているとき
        if cursor[0] == textCount.count && cursor[1] + promptLength == textCount[textCount.count - 1] && text[cursor[0] - 1].suffix(1) == "_" {
            return true
        }
        return false
    }
    
    // カーソルの文末判断をする関数
    func curIsSentenceEnd() -> Bool {
        print("curIsSentenceEnd ---")
        print("cursor : [ \(cursor[0]) , \(cursor[1]) ]")
        print("real cursorPlace : [ \(cursor[0]) , \(cursor[1] + promptLength) ]")
        
        // textviewの文字列を取得する
        let text = getText()
        // textviewの行数、各行の文字数を取得する
        let textCount = getTextCount()
        print("text : \(text)")
        print("textCount : \(textCount)")
        // カーソルが文末を示しているとき
        if cursor[1] + promptLength == textCount[cursor[0] - 1] && text[cursor[0] - 1].suffix(1) == "_" {
            return true
        }
        return false
    }
    
    // textviewの文字列を改行区切りの配列で返す関数
    func getText() -> [String] {
        // textview内の文字列を改行で分割する
        let splitArray = textview.text!.components(separatedBy: CharacterSet.newlines)
        return splitArray
    }
    
    // textviewの行数と各行の文字数を返す関数
    func getTextCount() -> [Int] {
        // 文字数カウント変数
        var count = [Int]()
        
        // textview内の文字列を改行で分割する
        let splitArray = getText()
        
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

