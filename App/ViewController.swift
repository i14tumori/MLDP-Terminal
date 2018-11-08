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
    // text : 対象文字列
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
    // 英数字の判定をする関数(ASCIIコードならtrueを返す)
    // text : 対象文字
    func isAlphanumeric(_ text: String) -> Bool {
        print("--- isAlphanumeric ---")
        return text >= "\u{00}" && text <= "\u{7f}"
    }
    // 数字の判定をする関数
    // 対象文字
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

// 文字と色を保存をする構造体
struct textAttr {
    // 文字を保存する変数
    var char: String
    // 色を保存する変数
    var color: UIColor
    
    // 初期化関数
    init(char: String, color: UIColor) {
        self.char = char
        self.color = color
    }
}

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, UITextViewDelegate {
    
    var timer: Timer?
    
    // 通知変数
    let notification = NotificationCenter.default
    
    // エスケープシーケンス判断用フラグ
    var escSeq = 0
    // エスケープシーケンス変位記憶変数
    var escDisplace = [0, 0]
    
    // カーソル位置記憶変数
    var cursor = [1, 1]
    
    // テキスト保存変数
    var allTextAttr = [[textAttr]]()
    
    // 色の一時記憶変数
    var currColor: UIColor = UIColor.black
    
    // メニュー表示を制御する変数
    var tapCount = 0
    
    @IBOutlet weak var textview: UITextView!
    @IBOutlet weak var menu: UIButton!
    @IBOutlet weak var backView: UIView!
    
    // AppDelegate内の変数呼び出し用
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    // viewが読み込まれたときのイベント
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // メニューを隠す
        hideMenu(duration: 0.0)
        
        // textviewに枠線をつける
        textview.layer.borderColor = UIColor.lightGray.cgColor
        textview.layer.borderWidth = 1
        
        // textviewのフォントサイズを設定する
        textview.font = UIFont.systemFont(ofSize: 12.00)
        
        // textviewのデリゲートをセット
        textview.delegate = self
        
        // textviewの初期化
        clear()
        
        // インスタンスの生成および初期化
        appDelegate.centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
    }
    
    // viewを表示する前のイベント
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        // centralManagerのデリゲートをセットする
        print("centralManagerDelegate set")
        appDelegate.centralManager.delegate = self
        
        // Notificationを設定する
        configureObserver()
    }
    
    // viewが消える前のイベント
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        
        // Notificationを削除する
        removeObserver()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /* Bluetooth以外関連メソッド */
    
    // タッチ開始時のイベント
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("--- touches began ---")
        // キーボードを閉じる
        keyboardDown()
    }
    
    // キーボードを閉じる関数
    @objc func keyboardDown() {
        print("--- keyboardDown ---")
        self.view.endEditing(true)
    }
    
    // textViewの入力値を取得し、カーソル位置に追記する関数
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        print("--- textView Edit ---")
        
        // ペリフェラルと接続されていないとき
        if appDelegate.outputCharacteristic == nil {
            print("\(appDelegate.peripheralDeviceName) is not ready")
            showToast(message: "デバイス未接続")
            return false
        }
        
        var input = text
        // iPnoneのdelキーのとき
        if input == "" {
            // BS(後退)に変換する
            input = "\u{08}"
        }
        // ASCIIコード外のとき
        if !input.isAlphanumeric(input) {
            return false
        }
        
        // ペリフェラルにデータを書き込む
        writePeripheral(input)
        
        // 画面をスクロールする
        scrollToButtom()
        
        // カーソルを表示する
        viewCursor()
        
        // デフォルトカーソル(青縦棒)位置への追記はしない
        return false
    }
    
    // textview移動のNotificationを設定する関数
    func configureObserver() {
        print("--- configureObserver ---")
        // キーボード出現の検知
        notification.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        // キーボード終了の検知
        notification.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        // 画面回転の検知
        notification.addObserver(self, selector: #selector(onOrientationChange(notification:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    }
    
    // textview移動のNotificationを削除する関数
    func removeObserver() {
        print("--- removeObserver ---")
        notification.removeObserver(self)
    }
    
    // キーボードが現れるときに画面をずらす関数
    @objc func keyboardWillShow(notification: Notification?) {
        print("--- keyboardWillShow ---")
        // キーボードの高さを取得する
        let keyboardHeight = (notification?.userInfo![UIKeyboardFrameEndUserInfoKey] as AnyObject).cgRectValue.height
        print("keyboardHeight : \(keyboardHeight)")
        // textviewの高さを変更する
         textview.frame = CGRect(origin: textview.frame.origin, size: CGSize(width: self.view.frame.width, height: self.view.frame.height - keyboardHeight - textview.frame.origin.y))
        // スクロールする
        scrollToButtom()
    }
    
    // キーボードが消えるときに画面を戻す関数
    @objc func keyboardWillHide(notification: Notification?) {
        print("--- keyboardWillHide ---")
        // 初期の位置に戻す
        textview.frame = CGRect(origin: textview.frame.origin, size: CGSize(width: self.view.frame.width, height: self.view.frame.height - textview.frame.origin.y))
        // スクロールする
        scrollToButtom()
    }
    
    // 画面が回転したときに呼ばれる関数
    @objc func onOrientationChange(notification: Notification?) {
        print("--- onOrientationChange ---")
        // indicatorを表示しているとき
        if appDelegate.indicator.isShow {
            // 再表示
            appDelegate.indicator.show(controller: self)
        }
    }
    
    // メニューが押されたとき
    // sender : 押下ボタン
    @IBAction func menuTap(_ sender: UIButton) {
        print("--- menu button tapped ---")
        // 表示非表示を切り替える
        tapCount = (tapCount + 1) % 2
        print("tapCount : \(tapCount)")
        switch tapCount {
        case 0:
            // メニューを非表示状態にする
            hideMenu(duration: 0.7)
        case 1:
            // メニューを表示状態にする
            showMenu(duration: 0.7)
        default: break
        }
    }
    
    // メニューを隠す関数
    // second : 表示アニメーションの秒数
    func hideMenu(duration second: Float) {
        print("--- hideMenu ---")
        // メニューを移動させる
        UIView.animate(withDuration: TimeInterval(second)) {
            self.backView.center.x = 0
        }
        // メニューを隠す
        UIView.animate(withDuration: TimeInterval(second)) {
            self.backView.alpha = 0.0
        }
    }
    
    // メニューを表示する関数
    // second : 表示アニメーションの秒数
    func showMenu(duration second: Float) {
        print("--- showMenu ---")
        // メニューを移動させる
        UIView.animate(withDuration: TimeInterval(second)) {
            self.backView.center.x = self.view.center.x - self.menu.bounds.width
        }
        // メニューを表示する
        UIView.animate(withDuration: TimeInterval(second)) {
            self.backView.alpha = 1.0
        }
    }
    
    // scanButtonが押されたとき
    // sender : 押下ボタン
    @IBAction func scanTap(_ sender: UIButton) {
        print("--- scan button tapped ---")
    }
    
    // disconButtonが押されたとき
    // sender : 押下ボタン
    @IBAction func disconTap(_ sender: UIButton) {
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
    // sender : 押下ボタン
    @IBAction func delTap(_ sender: UIButton) {
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
    // n : 変位
    func escUp(n: Int) {
        print("--- escUp ---")
        print("n : \(n)")
        let column = cursor[1] - 1
        escUpTop(n: n)
        escRight(n: column)
    }
    
    // 下にn移動する関数
    // n : 変位
    func escDown(n: Int) {
        print("--- escDown ---")
        print("n : \(n)")
        let column = cursor[1] - 1
        escDownTop(n: n)
        escRight(n: column)
    }
    
    // 右にn移動する関数
    // n : 変位
    func escRight(n: Int) {
        print("--- escRight ---")
        print("n : \(n)")
        print("cursor : [ \(cursor[0]), \(cursor[1]) ]")
        // 移動がないとき(n = 0)
        if n == 0 {
            return
        }
        // 何もないときはカーソル文字を追加
        if getCurrChar() == "" {
            allTextAttr[cursor[0] - 1].append(textAttr(char: "_", color: currColor))
        }
        // カーソル文字を削除する
        if curIsSentenceEnd() {
            print("remove last")
            allTextAttr[cursor[0] - 1] = Array(allTextAttr[cursor[0] - 1][0..<allTextAttr[cursor[0] - 1].count - 1])
            if allTextAttr[cursor[0] - 1].count == 0 {
                allTextAttr[cursor[0] - 1] = [textAttr(char: " ", color: currColor)]
            }
            viewChar(allTextAttr)
        }
        // カーソルをずらす
        cursor[1] = cursor[1] + n
        // 桁数が足りないとき
        if cursor[1] > allTextAttr[cursor[0] - 1].count {
            print("column isn't enough")
            print("add spaceCount : \(cursor[1] - allTextAttr[cursor[0] - 1].count - 1)")
            // 足りない空白を追加する
            for _ in 0..<cursor[1] - allTextAttr[cursor[0] - 1].count - 1 {
                allTextAttr[cursor[0] - 1].append(textAttr(char: " ", color: currColor))
            }
            // カーソル文字を追加する
            allTextAttr[cursor[0] - 1].append(textAttr(char: "_", color: currColor))
            print("curText : \(allTextAttr[cursor[0] - 1])")
        }
        refresh()
        // カーソルを表示する
        viewCursor()
    }
    
    // 左にn移動する関数
    // n : 変位
    func escLeft(n: Int) {
        print("--- escLeft ---")
        print("n : \(n)")
        // 移動がないとき(n = 0)
        if n == 0 {
            return
        }
        // カーソル文字を削除する
        if curIsSentenceEnd() {
            print("remove last")
            allTextAttr[cursor[0] - 1] = Array(allTextAttr[cursor[0] - 1][0..<allTextAttr[cursor[0] - 1].count - 1])
            if allTextAttr[cursor[0] - 1].count == 0 {
                allTextAttr[cursor[0] - 1] = [textAttr(char: "_", color: currColor)]
            }
            viewChar(allTextAttr)
        }
        var move = n
        // 桁数が足りないとき
        if cursor[1] <= move {
            move = cursor[1] - 1
        }
        // カーソルをずらす
        cursor[1] = cursor[1] - move
        refresh()
        // カーソルを表示する
        viewCursor()
    }
    
    // n行下の先頭に移動する関数
    // n : 変位
    func escDownTop(n: Int) {
        print("--- escDownTop ---")
        print("n : \(n)")
        viewChar(allTextAttr)
        // カーソル文字を削除する
        if curIsSentenceEnd() {
            print("remove last")
            allTextAttr[cursor[0] - 1] = Array(allTextAttr[cursor[0] - 1][0..<allTextAttr[cursor[0] - 1].count - 1])
            if allTextAttr[cursor[0] - 1].count == 0 {
                allTextAttr[cursor[0] - 1] = [textAttr(char: "", color: currColor)]
            }
            viewChar(allTextAttr)
        }
        // 行数が足りないとき
        if allTextAttr.count - cursor[0] < n {
            print("row isn't enough : \(n - (allTextAttr.count - cursor[0]))")
            // 改行を付け加える
            for _ in 0..<(n - (allTextAttr.count - cursor[0]) - 1) {
                allTextAttr.append([textAttr(char: "", color: currColor)])
            }
            // 改行とカーソル文字を追加する
            allTextAttr.append([textAttr(char: "_", color: currColor)])
            viewChar(allTextAttr)
        }
        // カーソルをずらす
        cursor[0] = cursor[0] + n
        cursor[1] = 1
        refresh()
        // カーソルを表示する
        viewCursor()
    }
    
    // n行上の先頭に移動する関数
    // n : 変位
    func escUpTop(n: Int) {
        print("--- escUpTop ---")
        print("n : \(n)")
        // カーソル文字を削除する
        if curIsSentenceEnd() {
            print("remove last")
            allTextAttr[cursor[0] - 1] = Array(allTextAttr[cursor[0] - 1][0..<allTextAttr[cursor[0] - 1].count - 1])
            if allTextAttr[cursor[0] - 1].count == 0 {
                allTextAttr[cursor[0] - 1] = [textAttr(char: "", color: currColor)]
            }
            viewChar(allTextAttr)
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
        print("after cursor : [ \(cursor[0]), \(cursor[1]) ]")
        print("allText char")
        for row in 0..<allTextAttr.count {
            for column in 0..<allTextAttr[row].count {
                print("char : \(allTextAttr[row][column].char)")
            }
        }
        print("allText count")
        for row in 0..<allTextAttr.count {
            print("row : \(row), column : \(allTextAttr[row].count)")
        }
        // 空文字ならカーソル文字にする
        if getCurrChar() == "" {
            allTextAttr[cursor[0] - 1][cursor[1] - 1] = textAttr(char: "_", color: currColor)
        }
        viewChar(allTextAttr)
        // 空白行と空行を削除する
        for _ in 0..<allTextAttr.count {
            // 最後の行が空白でも空文字でもないとき
            if !isNone(allTextAttr[allTextAttr.count - 1]) {
                break
            }
            // 最後の行を削除する
            allTextAttr.removeLast()
        }
        viewChar(allTextAttr)
        refresh()
        // カーソルを表示する
        viewCursor()
    }
    
    // 現在位置と関係なく上からn、左からmの場所に移動する関数
    // n : 変位
    // m : 変位
    func escRoot(n: Int, m: Int) {
        print("--- escRoot ---")
        print("n : \(n), m : \(m)")
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
    
    // centralManagerの状態が変化すると呼ばれるイベント
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOff:
            print("Bluetooth電源 : OFF")
            // Indicator表示開始
            appDelegate.indicator.show(controller: self)
            showToast(message: "Bluetoothの電源がOFF")
        case .poweredOn:
            // Indicator表示終了
            appDelegate.indicator.dismiss()
            print("Bluetooth電源 : ON")
        case .resetting:
            // Indicator表示開始
            appDelegate.indicator.show(controller: self)
            print("レスティング状態")
        case .unauthorized:
            // Indicator表示開始
            appDelegate.indicator.show(controller: self)
            print("非認証状態")
        case .unknown:
            // Indicator表示開始
            appDelegate.indicator.show(controller: self)
            print("不明")
        case .unsupported:
            // Indicator表示開始
            appDelegate.indicator.show(controller: self)
            print("非対応")
        }
    }
    
    // ペリフェラルへの接続が成功すると呼ばれるイベント
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
    
    // ペリフェラルとの切断が完了すると呼ばれるイベント
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
    
    // サービスを発見すると呼ばれるイベント
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
    
    // キャラクタリスティックを発見すると呼ばれるイベント
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
    
    // Notify開始/停止時に呼ばれるイベント
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print(error.debugDescription)
        } else {
            print("Notify状態更新 characteristic UUID : \(characteristic.uuid), isNotifying : \(characteristic.isNotifying)")
        }
    }
    
    // peripheralからデータが届いたときのイベント
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
        
        // 複数文字届いたとき
        if dataString!.count > 1 {
            return
        }
       
        // \0(nil)のとき
        if dataString == nil {
            return
        }
        // ASCIIコード外のとき
        else if !dataString!.isAlphanumeric(dataString!) {
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
                // 複数桁の数値のとき
                if dataString!.isNumeric(dataString!) {
                    // 変位に追加する
                    escDisplace[0] = escDisplace[0] * 10 + Int(dataString!)!
                    break
                }
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
                case "m":
                    if escDisplace[0] >= 30 && escDisplace [0] <= 37 {
                        changeColor(color: escDisplace[0])
                    }
                    else {
                        print("NO ESC_SEQ")
                    }
                    escSeq = 0
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
                // 複数桁の数値のとき
                if dataString!.isNumeric(dataString!) {
                    // 変位に追加する
                    escDisplace[1] = escDisplace[1] * 10 + Int(dataString!)!
                    break
                }
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
        // それ以外のとき
        else {
            // textViewに読み込みデータを書き込む
            writeTextView(dataString!)
            
            // カーソルをずらす
            // 改行のとき
            if dataString! == "\n" || dataString! == "\r" {
                cursor[0] = cursor[0] + 1
                cursor[1] = 1
            }
            // BS(削除)のとき
            else if dataString! == "\u{08}" {
                if cursor[1] > 1 {
                    cursor[1] = cursor[1] - 1
                }
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
        
        print("--- writeTextView ---")
        print("string : \(string)")
        print("cursor : [ \(cursor[0]), \(cursor[1]) ]")
        viewChar(allTextAttr)
        
        // 改行なら次の行を準備とカーソル文字を削除して返る
        if string == "\r" || string == "\n" {
            print("before row : \(allTextAttr[cursor[0] - 1])")
            // 次のテキスト記憶を準備
            allTextAttr.insert([textAttr(char: "_", color: currColor)], at: cursor[0])
            print("prepare")
            viewChar(allTextAttr)
            // 次の行にカーソル以降の要素を登録する
            allTextAttr[cursor[0]] = Array(allTextAttr[cursor[0] - 1][cursor[1] - 1..<allTextAttr[cursor[0] - 1].count])
            print("register")
            viewChar(allTextAttr)
            print("next row : \(allTextAttr[cursor[0]])")
            // カーソル行をカーソル前の文字列だけにする
            // カーソル前に文字列がない(カーソルが一列目を指している)とき
            if cursor[1] == 1 {
                allTextAttr[cursor[0] - 1] = [textAttr(char: "", color: currColor)]
            }
            // カーソル前に文字列があるとき
            else {
                allTextAttr[cursor[0] - 1] = Array(allTextAttr[cursor[0] - 1][0..<cursor[1] - 1])
            }
            print("change")
            viewChar(allTextAttr)
            print("cursor row : \(allTextAttr[cursor[0] - 1])")
            viewChar(allTextAttr)
            // カーソルが文末のとき
            if curIsSentenceEnd() {
                // カーソル文字を削除する
                allTextAttr[cursor[0] - 1].removeLast()
            }
            return
        }
        // BS(後退)ならテキストを削除する
        if string == "\u{08}" {
            deleteTextView()
            return
        }
        
        // カーソルの位置に文字と背景色を書き込む
        allTextAttr[cursor[0] - 1].insert(textAttr(char: string, color: currColor), at: cursor[1] - 1)
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
        print("--- deleteTextView ---")
        print("get index : \(cursor[0] - 1)")
        
        // 削除できないとき
        if cursor[1] == 1 {
            return
        }
        
        // カーソル前の位置にある文字と背景色を削除する
        allTextAttr[cursor[0] - 1].remove(at: (cursor[1] - 1) - 1)
        // フォントを再設定する
        textview.font = UIFont(name: "CourierNewPSMT", size: textview.font!.pointSize)
    }
    
    // 文字色を変更する関数
    // color : 変更する色
    func changeColor(color: Int) {
        switch color {
        case 30:
            currColor = UIColor.black
        case 31:
            currColor = UIColor.red
        case 32:
            currColor = UIColor.green
        case 33:
            currColor = UIColor.yellow
        case 34:
            currColor = UIColor.blue
        case 35:
            currColor = UIColor.magenta
        case 36:
            currColor = UIColor.cyan
        case 37:
            currColor = UIColor.white
        default: break
        }
    }
    
    // カーソルを表示する関数
    func viewCursor() {
        print("--- viewCursor ---")
        print("cursor : [ \(cursor[0]) , \(cursor[1]) ]")
        viewChar(allTextAttr)
        textview.isScrollEnabled = false
        
        let text = NSMutableAttributedString()
        var attributes: [NSAttributedStringKey : Any]
        var char: NSMutableAttributedString
        
        // textviewの行数だけ繰り返す
        for row in 0..<allTextAttr.count {
            // 各行の文字数だけ繰り返す
            for column in 0..<allTextAttr[row].count {
                // 背景色を設定する
                var backColor = UIColor.white
                // 前景色を設定する
                var foreColor = allTextAttr[row][column].color
                // カーソル文字のとき
                if cursor == [row + 1, column + 1] {
                    // 背景をグレーにする
                    backColor = UIColor.gray
                    // 前景を白にする
                    foreColor = UIColor.white
                }
                // 文字の色を設定する
                attributes = [.backgroundColor : backColor, .foregroundColor : foreColor]
                // 文字に色を登録する
                char = NSMutableAttributedString(string: allTextAttr[row][column].char, attributes: attributes)
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
        
        // 画面をスクロールする
        scrollToButtom()
    }
    
    // カーソルの最後尾判断をする関数
    // 返り値 : 最後尾->true, それ以外->false
    func curIsEnd() -> Bool {
        print("--- curIsEnd ---")
        print("cursor : [ \(cursor[0]) , \(cursor[1]) ]")
        
        // カーソルが最後尾を示しているとき
        if curIsSentenceEnd() && cursor[0] == allTextAttr.count {
            return true
        }
        return false
    }
    
    // カーソルの文末判断をする関数
    // 返り値 : 文末->true, それ以外->false
    func curIsSentenceEnd() -> Bool {
        print("--- curIsSentenceEnd ---")
        print("cursor : [ \(cursor[0]) , \(cursor[1]) ]")
        viewChar(allTextAttr)
        
        // カーソルが文末を示しているとき
        if cursor[1] == allTextAttr[cursor[0] - 1].count && allTextAttr[cursor[0] - 1][cursor[1] - 1].char == "_" {
            return true
        }
        return false
    }
    
    // カーソルの示す文字を取得する関数
    // 返り値 : カーソルの示す文字
    func getCurrChar() -> String {
        print("--- getCurrChar ---")
        print("cursor : [ \(cursor[0]), \(cursor[1]) ]")
        viewChar(allTextAttr)
        print("return : \(allTextAttr[cursor[0] - 1][cursor[1] - 1].char)")
        // カーソルの示す位置の文字を返す
        return allTextAttr[cursor[0] - 1][cursor[1] - 1].char
    }
    
    // textAttr配列の空白文字を削除する関数
    // text : 対象配列
    // limit : 削除制限数
    // 返り値 : 空白が削除されたtextAttr配列
    func delSpace(_ text: [textAttr], _ limit: Int) -> [textAttr] {
        print("--- delSpace ---")
        var delText = text
        var count = text.count
        print("delText : \(delText)")
        print("count : \(count)")
        // 最後の文字が空白かつ制限内のとき
        while delText[delText.count - 1].char == " " && count > limit {
            // 最後の文字を消す
            delText.removeLast()
            print("delText : \(delText)")
            count -= 1
            print("count minus : \(count)")
        }
        if delText.count == 0 {
            delText = [textAttr(char: "", color: currColor)]
        }
        print("return delText : \(delText)")
        return delText
    }
    
    // textAttr配列の文字列が空白のみかを判定する関数(空文字はfalse)
    // text : 対象配列
    // 返り値 : 空白のみ->true, それ以外->false
    func isNone(_ text: [textAttr]) -> Bool {
        var checkText = text
        print("--- isNone ---")
        // 列数だけ繰り返す
        for _ in 0..<checkText.count {
            // 最後の文字が空白でないとき
            if checkText[checkText.count - 1].char != " " {
                return false
            }
            // 最後の要素を削除する
            checkText.removeLast()
        }
        return true
    }
    
    // allTextAttr内を整える関数
    func refresh() {
        print("--- refresh ---")
        var refreshText = [[textAttr]]()
        // 空白文字列の削除
        for row in 0..<allTextAttr.count {
            // 空白だけかつカーソル行ではないとき
            if isNone(allTextAttr[row]) && row != cursor[0] - 1 {
                print("isNone")
                // 空文字に変換
                refreshText.append([textAttr(char: "", color: currColor)])
            }
            // 文字がある(空文字を含む)またはカーソル行のとき
            else {
                print("isNotNone")
                refreshText.append(allTextAttr[row])
            }
        }
        viewChar(refreshText)
        
        // カーソルより後ろの空文字列の削除
        print("cursor : [ \(cursor[0]), \(cursor[1]) ]")
        var row = refreshText.count - 1
        var count = 0
        print("row : \(row)")
        while row > cursor[0] - 1 {
            if refreshText[row][0].char != "" {
                print("break")
                break
            }
            row -= 1
            count += 1
        }
        print("after count : \(count)")
        refreshText = Array(refreshText[0..<refreshText.count - count])
        viewChar(refreshText)
        
        // 各行末尾の空白文字列の削除
        for row in 0..<refreshText.count {
            // 削除制限数
            var limit = 0
            if row == cursor[0] - 1 {
                limit = cursor[1]
            }
            refreshText[row] = delSpace(refreshText[row], limit)
        }
        viewChar(refreshText)
        
        // 変換後の配列にする
        allTextAttr = refreshText
    }
   
    // textviewをクリアする関数
    func clear() {
        print("--- clear ---")
        // 色を初期化する
        currColor = UIColor.black
        // テキストの記憶を初期化する
        allTextAttr = [[textAttr(char: "_", color: currColor)]]
        viewChar(allTextAttr)
        
        // カーソル位置を初期化する
        cursor = [1, 1]
        // カーソル表示
        viewCursor()
    }
    
    // textviewを最下までスクロールする関数
    func scrollToButtom() {
        textview.selectedRange = NSRange(location: textview.text.count, length: 0)
        textview.isScrollEnabled = true
        
        let scrollY = textview.contentSize.height - textview.bounds.height
        let scrollPoint = CGPoint(x: 0, y: scrollY > 0 ? scrollY : 0)
        textview.setContentOffset(scrollPoint, animated: false)
    }
    
    // デバッグ用関数 (非確実的動作)
    func viewChar(_ text: [[textAttr]]) {
        print("--- viewChar ---")
        let allTextAttr = text
        var text = [""]
        for row in 0..<allTextAttr.count {
            for column in 0..<allTextAttr[row].count {
                text[text.count - 1].append(allTextAttr[row][column].char)
            }
            text.append("")
        }
        print(text)
    }
}
