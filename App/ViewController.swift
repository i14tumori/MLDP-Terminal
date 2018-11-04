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
    // text : 分解する文字列
    //  返り値 : 分解された文字列
    func partition(_ text: String) -> [String] {
        print("--- partition ---")
        let count = text.count
        var origin = text
        var splitText = [String]()
        for _ in 0..<count {
            splitText.append(String(origin.prefix(1)))
            origin = String(origin.suffix(origin.count - 1))
        }
        print("partition : \(splitText)")
        return splitText
    }
    // 文が空白文字または空文字のみの判定をする関数
    // text : 判定する文字列
    // 返り値 : 判定結果
    func isNone(_ text: String) -> Bool {
        print("--- isNone ---")
        var str = text
        // 空文字のときfor文に入らずreturn
        for _ in 0..<text.count {
            // 空白以外があるときreturn
            if str.suffix(1) != " " {
                return false
            }
            // 一字減らす
            str = String(str.prefix(str.count - 1))
        }
        return true
    }
    // 文末の空白群を削除する関数
    // text : 文末の空白群を削除する文字列 (参照渡し)
    // 返り値 : 削除した空白数
    func delEndSpace(text: inout String) -> Int {
        print("--- delEndSpace ---")
        var count = 0
        while text.suffix(1) == " " {
            text = String(text.prefix(text.count - 1))
            count += 1
        }
        return count
    }
    // 英数字の判定をする関数(ASCIIコードならtrue)
    // text : 判定する文字列
    //  返り値 : 判定結果
    func isAlphanumeric(_ text: String) -> Bool {
        print("--- isAlphanumeric ---")
        return text >= "\u{00}" && text <= "\u{7f}"
    }
    // 数字の判定をする関数
    // text : 判定する文字列
    //  返り値 : 判定結果
    func isNumeric(_ text: String) -> Bool {
        print("--- isNumeric ---")
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
    
    var timer: Timer?
    
    // エスケープシーケンス判断用フラグ
    var escSeq = 0
    // エスケープシーケンス変位記憶変数
    var escDisplace = [0, 0]
    
    // カーソル位置記憶変数
    var cursor = [1, 1]
    
    // テキスト記憶変数
    var allText = [[String]]()
    // テキストカラー記憶変数
    var allTextColor = [[UIColor]]()
    
    // 色の一時記憶変数
    var currColor: UIColor = UIColor.black
    
    @IBOutlet weak var textview: UITextView!
    
    // AppDelegate内の変数呼び出し用
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // textviewに枠線をつける
        textview.layer.borderColor = UIColor.gray.cgColor
        textview.layer.borderWidth = 0.5
        
        // textviewのフォントサイズを設定する
        textview.font = UIFont.systemFont(ofSize: 12.00)
 
        // textviewのデリゲートをセット
        textview.delegate = self
        
        // textviewの初期化
        clearButtonTapped(UIButton())
        
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
        print("--- touches began ---")
        // キーボードを閉じる
        self.view.endEditing(true)
    }
    
    // textViewの入力値を取得し、カーソル位置に追記
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        print("--- textView Edit ---")
        
        // ペリフェラルと接続されていないとき
        if appDelegate.outputCharacteristic == nil {
            print("\(appDelegate.peripheralDeviceName) is not ready")
            showToast(message: "デバイス未接続")
            return false
        }
        
        print("cursor : [ \(cursor[0]) , \(cursor[1]) ]")
        print("allText : \(allText)")
        
        var input = text
        // iPnoneのdelキーのとき
        if input == "" {
            // BS(後退)に変換する
            input = "\u{08}"
            // カーソル位置をずらす
            cursor[1] = cursor[1] - 1
        }
        // ASCIIコード外のとき
        if !input.isAlphanumeric(input) {
            return false
        }
        
        // ペリフェラルにデータを書き込む
        writePeripheral(input)
        // textviewにデータを書き込む
        writeTextView(input)
        
        // 画面をスクロールする
        scrollToButtom()
        
        // カーソルをずらす
        if input == "\n" {
            cursor[0] = cursor[0] + 1
            cursor[1] = 1
        }
        else {
            cursor[1] = cursor[1] + 1
        }
        
        // カーソルを表示する
        viewCursor()
        
        // デフォルトカーソル(青縦棒)位置への追記はしない
        return false
    }
    
    // clearButtonが押されたとき
    // textViewをクリアする
    @IBAction func clearButtonTapped(_ sender: UIButton) {
        print("--- clear button tapped ---")
        // 色を初期化する
        currColor = UIColor.black
        // テキストの記憶を初期化する
        allText = [[]]
        allText[0].append("_")
        allTextColor = [[]]
        allTextColor[0].append(currColor)
        
        print("allText : \(allText)")
        print("allTextColor : \(allTextColor)")
        
        // カーソル位置を初期化する
        cursor = [1, 1]
        // カーソル表示
        viewCursor()
    }
    
    // scanButtonが押されたとき
    // ペリフェラルスキャンを開始する
    @IBAction func scanButtonTapped(_ sender: UIButton) {
        print("--- scan button tapped ---")
    }
    
    // disconButtonが押されたとき
    @IBAction func disconButtonTapped(_ sender: UIButton) {
        print("--- disconnect button tapped ---")
        // ペリフェラルと接続されていないとき
        if appDelegate.outputCharacteristic == nil {
            print("\(appDelegate.peripheralDeviceName) is not ready")
            showToast(message: "デバイス未接続")
            return
        }
        
        // 通知を切る
        appDelegate.peripheral.setNotifyValue(false, for: appDelegate.outputCharacteristic)
        // 通信を切断する
        appDelegate.centralManager.cancelPeripheralConnection(appDelegate.peripheral)
    }
    
    // deleteButtonが押されたとき
    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        print("--- deviceDelete button tapped ---")
        // 記憶デバイスを消去する
        UserDefaults.standard.removeObject(forKey: "DeviceName")
    }
    
    // トースト出力関数
    // message : トーストする文字列
    func showToast(message: String) {
        let toastLabel = UILabel(frame: CGRect(x: self.view.frame.size.width/2 - 150, y: self.view.frame.size.height/4, width: 300, height: 35))
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
        // ペリフェラルにエスケープを書き込む
        writePeripheral("\u{1b}")
    }
    
    // 追加ボタンCtrlが押されたとき
    @objc func ctrlTapped() {
        print("--- ctrl ---")
    }
    
    // 追加ボタン↑が押されたとき
    @objc func upTapped() {
        print("--- up ---")
        // ペリフェラルとつながっていないときは何もしない
        if appDelegate.outputCharacteristic == nil {
            return
        }
        // ペリフェラルにエスケープシーケンスを書き込む
        writePeripheral("\u{1b}[1A")
    }
    
    // 追加ボタン↓が押されたとき
    @objc func downTapped() {
        print("--- down ---")
        // ペリフェラルとつながっていないときは何もしない
        if appDelegate.outputCharacteristic == nil {
            return
        }
        // ペリフェラルにエスケープシーケンスを書き込む
        writePeripheral("\u{1b}[1B")
    }
    
    // 追加ボタン←が押されたとき
    @objc func leftTapped() {
        print("--- left ---")
        // ペリフェラルとつながっていないときは何もしない
        if appDelegate.outputCharacteristic == nil {
            return
        }
        // ペリフェラルにエスケープシーケンスを書き込む
        writePeripheral("\u{1b}[1D")
    }
    
    // 追加ボタン→が押されたとき
    @objc func rightTapped() {
        print("--- right ---")
        // ペリフェラルとつながっていないときは何もしない
        if appDelegate.outputCharacteristic == nil {
            return
        }
        // ペリフェラルにエスケープシーケンスを書き込む
        writePeripheral("\u{1b}[1C")
    }
    
    /* エスケープシーケンスメソッド */
    
    // 上にn移動する関数
    func escUp(n: Int) {
        print("--- escUp ---")
        print("n : \(n)")
        let column = cursor[1] - 1
        escUpTop(n: n)
        escRight(n: column)
    }
    
    // 下にn移動する関数
    func escDown(n: Int) {
        print("--- escDown ---")
        print("n : \(n)")
        let column = cursor[1] - 1
        escDownTop(n: n)
        escRight(n: column)
    }
    
    // 右にn移動する関数
    func escRight(n: Int) {
        print("--- escRight ---")
        print("n : \(n)")
        print("cursor : [ \(cursor[0]), \(cursor[1]) ]")
        // カーソルの示す行を取得する
        var text = getText()
        var curText = text[cursor[0] - 1]
        // テキストカラーを取得する
        var color = getTextColor()
        print("text : \(text)")
        // 何もないときはカーソル文字を追加
        if getCurrChar() == "" {
            // 文字を追加
            text[cursor[0] - 1] = "_"
            curText = text[cursor[0] - 1]
            // テキストカラーを追加
            color[cursor[0] - 1] = [UIColor.black]
        }
        // カーソル文字を削除する
        if getCurrChar() == "_" && curIsSentenceEnd() {
            curText = String(curText.prefix(curText.count - 1))
            text[cursor[0] - 1] = curText
            color[cursor[0] - 1].removeLast()
        }
        // カーソルをずらす
        cursor[1] = cursor[1] + n
        // 桁数が足りないとき
        if cursor[1] > curText.count {
            // 足りない分の空白を挿入する
            var space = ""
            var addColor = [UIColor]()
            for _ in 0..<cursor[1] - curText.count - 1 {
                space.append(" ")
                addColor.append(UIColor.white)
            }
            print("space count : \(space.count)")
            // カーソル文字を追加する
            text[cursor[0] - 1] = curText + space + "_"
            addColor.append(UIColor.white)
            // 文を結合する
            setText(text)
            // テキストカラーを反映する
            color[cursor[0] - 1] = color[cursor[0] - 1] + addColor
            setTextColor(color)
        }
        // カーソルを表示する
        viewCursor()
    }
    
    // 左にn移動する関数
    func escLeft(n: Int) {
        print("--- escLeft ---")
        print("n : \(n)")
        // カーソルの示す行を取得する
        var text = getText()
        var curText = text[cursor[0] - 1]
        // テキストカラーを取得する
        var color = getTextColor()
        // カーソル文字を削除する
        if getCurrChar() == "_" && curIsSentenceEnd() {
            curText = String(curText.prefix(curText.count - 1))
            text[cursor[0] - 1] = curText
            color[cursor[0] - 1].removeLast()
        }
        print("curText : \(curText)")
        var move = n
        // 桁数が足りないとき
        if cursor[1] <= move {
            move = cursor[1] - 1
        }
        // カーソルをずらす
        cursor[1] = cursor[1] - move
        // 空白か空文字ならカーソル文字にする
        if getCurrChar() == " " {
            // カーソル前の文字列
            let preStr = String(curText.prefix(cursor[1] - 1))
            // カーソル前のテキストカラー
            let preColor = color[cursor[0] - 1].prefix(cursor[1] - 1)
            // 結合する
            curText = preStr + "_"
            // 文字を追加
            text[cursor[0] - 1] = curText
            // テキストカラーを追加
            color[cursor[0] - 1] = preColor
        }
        else if getCurrChar() == "" {
            curText = "_"
        }
        // 文末の空白を削除する
        let delCount = curText.delEndSpace(text: &curText)
        print("curText : \(curText)")
        // 削除した空白のテキストカラーを削除する
        let tempColor = allTextColor[cursor[0] - 1]
        allTextColor[cursor[0] - 1] = []
        for i in 0..<delCount {
            allTextColor[cursor[0] - 1].append(tempColor[i])
        }
        // 文を結合する
        setText(text)
        
        // カーソルを表示する
        viewCursor()
    }
    
    // n行下の先頭に移動する関数
    func escDownTop(n: Int) {
        print("--- escDownTop ---")
        print("n : \(n)")
        var text = getText()
        var curText = text[cursor[0] - 1]
        // カーソル文字を削除する
        if getCurrChar() == "_" && curIsSentenceEnd() {
            curText = String(curText.prefix(curText.count - 1))
        }
        let count = getTextCount()
        print("count.count : \(count.count)\ncursor[0] : \(cursor[0])")
        print("count.count - cursor[0] : \(count.count - cursor[0])")
        // 行数が足りないとき
        if count.count - cursor[0] < n {
            // 改行を付け加える
            for _ in 0..<n - (count.count - cursor[0]) {
                allText.insert([""], at: cursor[0])
                allTextColor.insert([currColor], at: cursor[0])
            }
            // 改行とカーソル文字を追加する
            text[text.count - 1] = text[text.count - 1] + "_"
        }
        // 文末の空白を削除する
        let delCount = curText.delEndSpace(text: &curText)
        print("curText : \(curText)")
        // 削除した空白のテキストカラーを削除する
        let tempColor = allTextColor[cursor[0] - 1]
        allTextColor[cursor[0] - 1] = []
        for i in 0..<delCount {
            allTextColor[cursor[0] - 1].append(tempColor[i])
        }
        // 文を結合する
        for i in 0..<text.count {
            allText[i] = text[i].partition(text[i])
        }
        // カーソルをずらす
        cursor[0] = cursor[0] + n
        cursor[1] = 1
        // カーソルを表示する
        viewCursor()
    }
    
    // n行上の先頭に移動する関数
    func escUpTop(n: Int) {
        print("--- escUpTop ---")
        print("n : \(n)")
        var text = getText()
        // カーソル文字を削除する
        if getCurrChar() == "_" && curIsSentenceEnd() {
            let curText = text[cursor[0] - 1]
            text[cursor[0] - 1] = String(curText.prefix(curText.count - 1))
        }
        var move = n
        // 行数が足りないとき
        if cursor[0] <= move {
            // 移動範囲を制限する
            move = cursor[0] - 1
        }
        print("move : \(move)")
        print("cursor : [ \(cursor[0]), \(cursor[1]) ]")
        // カーソルをずらす
        cursor[0] = cursor[0] - move
        cursor[1] = 1
        // カーソル位置に文字がないとき
        if getCurrChar() == "" {
            text[cursor[0] - 1] = "_"
        }
        // 空白行と空行を削除する
        for _ in 0..<text.count {
            // 空白でも空文字でもないとき
            if !text[text.count - 1].isNone(text[text.count - 1]) {
                break
            }
            // 最後の行を削除する
            text.removeLast()
            allTextColor.removeLast()
        }
        // 文を結合する
        for i in 0..<text.count {
            allText[i] = text[i].partition(text[i])
        }
        // カーソルを表示する
        viewCursor()
    }
    
    // 現在位置と関係なく上からn、左からmの場所に移動する関数
    func escRoot(n: Int, m: Int) {
        print("--- escRoot ---")
        print("n : \(n), m : \(m)")
        var text = getText()
        // カーソル文字を削除する
        if getCurrChar() == "_" && curIsSentenceEnd() {
            let curText = text[cursor[0] - 1]
            text[cursor[0] - 1] = String(curText.prefix(curText.count - 1))
        }
        // カーソルを上に移動させるとき
        if cursor[0] >= n {
            // cursor[0] - n上の先頭に移動する
            escUpTop(n: cursor[0] - n)
        }
        // カーソルを下に移動させるとき
        else {
            // n - cursor[0]下の先頭に移動する
            escDownTop(n: n - cursor[0])
        }
        // 左からmの位置に移動する
        escRight(n: m - 1)
    }
    
    /* Central関連メソッド */
    
    // commit用変更コメント (意味なし)
    
    // centralManagerの状態が変化すると呼ばれる
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOff:
            print("Bluetooth電源 : OFF")
            // Indicator表示開始
            BusyIndicator.sharedManager.show(controller: self)
            showToast(message: "Bluetoothの電源がOFF")
        case .poweredOn:
            // Indicator表示終了
            BusyIndicator.sharedManager.dismiss()
            print("Bluetooth電源 : ON")
        case .resetting:
            // Indicator表示開始
            BusyIndicator.sharedManager.show(controller: self)
            print("レスティング状態")
        case .unauthorized:
            // Indicator表示開始
            BusyIndicator.sharedManager.show(controller: self)
            print("非認証状態")
        case .unknown:
            // Indicator表示開始
            BusyIndicator.sharedManager.show(controller: self)
            print("不明")
        case .unsupported:
            // Indicator表示開始
            BusyIndicator.sharedManager.show(controller: self)
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
        // トーストを出力する
        showToast(message: "切断完了")
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
        // エラーのときは原因を出力してreturn
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
        // エラーのときは原因を出力してreturn
        if error != nil {
            print(error.debugDescription)
            return
        }
        
        textview.isScrollEnabled = false
        
        print("--- peripheral Update ---")
        print("cursor : [ \(cursor[0]), \(cursor[1]) ]")
        
        //  読み込みデータの取り出し
        let data = characteristic.value
        let dataString = String(data: data!, encoding: .utf8)
        
        print("dataString:\(String(describing: dataString))")
        
        // \0(nil)のとき
        if dataString! == "\0" {
            return
        }
        // エスケープシーケンス のとき
        else if escSeq > 0 {
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
        // エスケープのとき
        else if dataString! == "\u{1b}" {
            escSeq = 1
        }
            
        // BS(後退)のとき
        else if dataString! == "\u{08}" {
            // カーソル前の文字を削除する
            deleteTextView()
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
        
        print("--- writeTextView ---")
        print("string : \(string)")
        print("cursor : [ \(cursor[0]), \(cursor[1]) ]")
        
        // 改行なら次の行を準備して返る
        if string == "\n" || string == "\r"{
            // 次のテキスト記憶を準備
            allText.insert(["_"], at: cursor[0])
            // 次のテキストカラー記憶を準備
            allTextColor.insert([currColor], at: cursor[0])
            return
        }
        // BS(後退)ならそのまま返る
        if string == "\u{08}" {
            return
        }
        
        // カーソルの位置に文字と背景色を書き込む
        allText[cursor[0] - 1].insert(string, at: cursor[1] - 1)
        allTextColor[cursor[0] - 1].insert(currColor, at: cursor[1] - 1)
        
        print("allText : \(allText)")
        print("allTextColor : \(allTextColor)")
        
        // textviewに設定する
        var text = ""
        for i in 0..<allText.count {
            text += allText[i].joined()
        }
        textview.text = text
        
        // フォントを再設定する
        textview.font = UIFont(name: "CourierNewPSMT", size: textview.font!.pointSize)
        
        // 画面をスクロールする
        scrollToButtom()
    }
        
    // ペリフェラルに文字を書き込む関数
    // txStr : 書き込む文字
    func writePeripheral(_ txStr: String) {
        print("--- writePeripheral ---")
        if let txData = txStr.data(using: .utf8) {
            appDelegate.peripheral.writeValue(txData, for: appDelegate.outputCharacteristic, type: CBCharacteristicWriteType.withResponse)
        }
        else {
            print("txStr is nil")
        }
    }
    
    // カーソル位置の一つ前の文字を削除する関数
    func deleteTextView() {
        textview.isScrollEnabled = false
        
        print("--- deleteTextView ---")
        print("get index : \(cursor[0] - 1)")
        
        // カーソル前の位置にある文字と背景色を削除する
        allText[cursor[0] - 1].remove(at: (cursor[1] - 1) - 1)
        allTextColor[cursor[0] - 1].remove(at: (cursor[1] - 1) - 1)
        
        // フォントを再設定する
        textview.font = UIFont(name: "CourierNewPSMT", size: textview.font!.pointSize)
        
        // 画面をスクロールする
        scrollToButtom()
    }
    
    // カーソルを表示する関数
    func viewCursor() {
        print("--- viewCursor ---")
        let text = NSMutableAttributedString()
        
        var attributes: [NSAttributedStringKey : Any]
        var char: NSMutableAttributedString
        
        // textviewの行数だけ繰り返す
        for row in 0..<allText.count {
            // 各行の文字数だけ繰り返す
            for column in 0..<allText[row].count {
                // 背景色を設定する
                var backColor = UIColor.white
                // カーソル文字のとき
                if cursor == [row + 1, column + 1] {
                    // 背景をグレーにする
                    backColor = UIColor.gray
                }
                // 文字の色を設定する
                attributes = [.backgroundColor : backColor, .foregroundColor : currColor]
                // 文字に色を登録する
                char = NSMutableAttributedString(string: allText[row][column], attributes: attributes)
                // 文字を追加する
                text.append(char)
            }
            // 改行を追加する
            attributes = [.backgroundColor : UIColor.white, .foregroundColor : UIColor.white]
            char = NSMutableAttributedString(string: "\n", attributes: attributes)
            text.append(char)
        }
        
        // 色付きのテキストを設定する
        textview.attributedText = text
        // フォントを再設定する
        textview.font = UIFont(name: "CourierNewPSMT", size: textview.font!.pointSize)
    }
    
    // カーソルの最後尾判断をする関数
    func curIsEnd() -> Bool {
        print("--- curIsEnd ---")
        print("cursor : [ \(cursor[0]) , \(cursor[1]) ]")
        print("allText : \(allText)")
        
        // カーソルが最後尾を示しているとき
        if curIsSentenceEnd() && cursor[0] == allText.count {
            return true
        }
        return false
    }
    
    // カーソルの文末判断をする関数
    func curIsSentenceEnd() -> Bool {
        print("--- curIsSentenceEnd ---")
        print("cursor : [ \(cursor[0]) , \(cursor[1]) ]")
        print("allText : \(allText)")
        
        // カーソルが文末を示しているとき
        if cursor[1] == allText[cursor[0] - 1].count && allText[cursor[0] - 1][cursor[1] - 1] == "_" {
            return true
        }
        return false
    }
    
    // カーソルの示す文字を取得する関数
    func getCurrChar() -> String {
        print("--- getCurrChar ---")
        print("cursor : [ \(cursor[0]), \(cursor[1]) ]")
        // カーソルの示す位置の文字を返す
        return allText[cursor[0] - 1][cursor[1] - 1]
    }
    
    // allTextの文字列を改行区切りの配列で返す関数
    func getText() -> [String] {
        var splitArray = [String]()
        // テキストの行数だけ繰り返す
        for i in 0..<allText.count {
            // 各行を文字列に結合して追加する
            splitArray.append(allText[i].joined())
        }
        return splitArray
    }
    
    // allTextColorを返す関数
    func getTextColor() -> [[UIColor]] {
        return allTextColor
    }
    
    // allTextに文字列を設定する関数
    // text : 設定文字列
    func setText(_ text: [String]) {
        // 文字列を分解する
        var splitText = [[String]]()
        for row in 0..<text.count {
            let partText = text[row].partition(text[row])
            for column in 0..<partText.count {
                splitText[row].append(partText[column])
            }
            splitText.append([])
        }
        // allTextの初期化
        allText = []
        // 設定文字列の行数だけ繰り返す
        for row in 0..<text.count {
            // 各行の列数だけ繰り返す
            for column in 0..<text[row].count {
                allText[row].append(splitText[row][column])
            }
            // 次の行の準備
            allText.append([])
        }
    }
    
    // allTextColorに色を設定する関数
    // color : 設定色
    func setTextColor(_ color: [[UIColor]]) {
        // allTextColorの初期化
        allTextColor = []
        // 設定色の行数だけ繰り返す
        for row in 0..<color.count {
            // 各行の列数だけ繰り返す
            for column in 0..<color[row].count {
                    allTextColor[row].append(color[row][column])
            }
            // 次の行の準備
            allTextColor.append([])
        }
    }
    
    // textviewの行数と各行の文字数を返す関数
    func getTextCount() -> [Int] {
        // 文字数カウント変数
        var count = [Int]()
        
        // 各行の文字数を格納する
        for i in 0..<allText.count {
            count.append(allText[i].count)
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

