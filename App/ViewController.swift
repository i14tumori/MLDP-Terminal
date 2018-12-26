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
    // 返り値 : 分割された文字列配列
    func partition() -> [String] {
        print("--- partition ---")
        let count = self.count
        var origin = self
        var splitText = [String]()
        for _ in 0..<count {
            splitText.append(String(origin.prefix(1)))
            origin = String(origin.suffix(origin.count - 1))
        }
        print("partition : \(splitText)")
        return splitText
    }
    // ASCII文字の判定をする関数(ASCIIコードならtrueを返す)
    // 返り値 : ASCII文字 -> true, それ以外 -> false
    func isAlphanumeric(_ text: String) -> Bool {
        print("--- isAlphanumeric ---")
        print("return : \(text >= "\u{00}" && text <= "\u{7f}")")
        return text >= "\u{00}" && text <= "\u{7f}"
    }
    // 数字の判定をする関数
    // 返り値 : 数字 -> true, それ以外 -> false
    func isNumeric() -> Bool {
        print("--- isNumeric ---")
        let partText = self.partition()
        for i in 0..<self.count {
            if partText[i] < "0" || partText[i] > "9" {
                print("return : false")
                return false
            }
        }
        print("return : true")
        return true
    }
    // 文字列の高さを取得する関数
    // font : 使用フォント
    // 返り値 : 文字列の高さ(CGFloat型)
    func getStringHeight(_ font: UIFont) -> CGFloat {
        print("--- getStringHeight ---")
        let attribute = [NSAttributedStringKey.font: font]
        let size = self.size(withAttributes: attribute)
        print("return : \(size.height)")
        return size.height
    }
    // 文字列の横幅を取得する関数
    // font : 使用フォント
    // 返り値 : 文字列の横幅(CGFloat型)
    func getStringWidth(_ font: UIFont) -> CGFloat {
        print("--- getStringWidth ---")
        let attribute = [NSAttributedStringKey.font: font]
        let size = self.size(withAttributes: attribute)
        print("return : \(size.width)")
        return size.width
        
    }
}

// 文字と色を保存をする構造体
struct textAttr {
    // 文字を保存する変数
    var char: String
    // 色を保存する変数
    var color: UIColor
    // 前に続く文字の有無を表す変数
    var previous: Bool
    
    // 初期化関数
    init(char: String, color: UIColor, previous: Bool = true) {
        self.char = char
        self.color = color
        self.previous = previous
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
    
    // カーソルの基底位置を記憶する変数
    var base = 0
    // カーソル位置記憶変数
    var cursor = [1, 1]
    // 行判定フラグ
    var flap = false
    // テキスト保存変数
    var allTextAttr = [[textAttr]]()
    // 色の一時記憶変数
    var currColor = UIColor.black
    // 画面サイズ記憶変数
    var viewSize = [0, 0]
    
    // 画面スクロール制御変数
    var prevScroll = CGPoint(x: 0, y: 0)
    // 画面スクロールの基底位置を記憶する変数
    var viewBase = -1
    
    // メニュー表示を制御する変数
    var tapCount = 0
    
    // トースト状態管理変数
    var toast = false
    // トーストメッセージの一時記憶変数
    var tempToastMessage = ""
    
    // ボタン追加view
    let keyboard = UIStackView(frame: CGRect(x: 0, y: 0, width: 320, height: 40))
    // ボタン追加Viewの背景View
    let buttonBackView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 40))
    // 追加するボタン一覧
    let escButton = UIButton(frame: CGRect())
    let ctrlButton = UIButton(frame: CGRect())
    let upButton = UIButton(frame: CGRect())
    let downButton = UIButton(frame: CGRect())
    let leftButton = UIButton(frame: CGRect())
    let rightButton = UIButton(frame: CGRect())
    let keyDownButton = UIButton(frame: CGRect())
    
    // Ctrlボタン押下フラグ
    var ctrlKey = false
    
    @IBOutlet weak var textview: UITextView!
    @IBOutlet weak var menu: UIButton!
    @IBOutlet weak var menuBackView: UIView!
    
    // AppDelegate内の変数呼び出し用
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    // viewが読み込まれたときのイベント
    override func viewDidLoad() {
        print("--- viewDidLoad ---")
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // 画面スクロール用のイベントを登録する
        let pan = UIPanGestureRecognizer(target: self, action: #selector(self.pan(sender:)))
        self.view.addGestureRecognizer(pan)
        // textviewのスクロール機能を停止させる
        textview.isScrollEnabled = false
        
        // メニューを隠す
        hideMenu(duration: 0.0)
        
        // textviewに枠線をつける
        textview.layer.borderColor = UIColor.lightGray.cgColor
        textview.layer.borderWidth = 1
        
        // textviewのフォントサイズを設定する
        textview.font = UIFont.systemFont(ofSize: 12.00)
        
        // textviewのデリゲートをセット
        textview.delegate = self
        // 画面サイズを設定する
        setSize()
        // textviewの初期化
        clear()
        
        // インスタンスの生成および初期化
        appDelegate.centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
    }
    
    // viewを表示する前のイベント
    override func viewWillAppear(_ animated: Bool) {
        print("--- viewWillAppear ---")
        super.viewWillAppear(true)
        
        // 画面サイズを再設定する
        setSize()
        
        // centralManagerのデリゲートをセットする
        print("centralManagerDelegate set")
        appDelegate.centralManager.delegate = self
        
        // Notificationを設定する
        configureObserver()
    }
    
    // viewが消える前のイベント
    override func viewWillDisappear(_ animated: Bool) {
        print("--- viewWillDisappear ---")
        super.viewWillDisappear(true)
        
        // Notificationを削除する
        removeObserver()
    }
    
    override func didReceiveMemoryWarning() {
        print("--- didReceivememoryWarning ---")
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
    
    // 画面をスクロールさせる関数
    @objc func pan(sender: UIPanGestureRecognizer) {
        print("--- pan ---")
        // 移動後の相対位置を取得する
        let location = sender.translation(in: self.view)
        print("location : \(location)")
        // スクロールを開始するとき
        if viewBase < 0 {
            viewBase = base
        }
        // 画面を上にスワイプしたとき
        if prevScroll.y - location.y > 2 {
            print("up Swipe")
            print("viewBase : \(viewBase)")
            // 下にスクロールできるとき
            if viewBase < allTextAttr.count - viewSize[0] && viewBase > -1 {
                // 基底位置を下げる
                viewBase += 1
                view(scroll: true)
            }
        }
        // 画面を下にスワイプしたとき
        else if location.y - prevScroll.y > 2 {
            print("down Swipe")
            print("viewBase : \(viewBase)")
            // 上にスクロールできるとき
            if viewBase > 0 {
                // 基底位置を上げる
                viewBase -= 1
                view(scroll: true)
            }
        }
        // 位置を変更する
        prevScroll = location
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
        
        // 表示する
        view()
        // スクロール基底を初期化する
        viewBase = -1
        
        // デフォルトカーソル(青縦棒)位置への追記はしない
        return false
    }
    
    // Notificationを設定する関数
    func configureObserver() {
        print("--- configureObserver ---")
        // キーボード出現の検知
        notification.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        // キーボード終了の検知
        notification.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        // 画面回転の検知
        notification.addObserver(self, selector: #selector(onOrientationChange(notification:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    }
    
    // Notificationを削除する関数
    func removeObserver() {
        print("--- removeObserver ---")
        notification.removeObserver(self)
    }
    
    // キーボードが現れるときに画面をずらす関数
    @objc func keyboardWillShow(notification: Notification?) {
        print("--- keyboardWillShow ---")
        print("pre base : \(base)")
        // キーボードの高さを取得する
        let keyboardHeight = (notification?.userInfo![UIKeyboardFrameEndUserInfoKey] as AnyObject).cgRectValue.height
        // textviewの高さを変更する
        textview.frame = CGRect(origin: textview.frame.origin, size: CGSize(width: self.view.frame.width, height: self.view.frame.height - keyboardHeight - textview.frame.origin.y))
        // 画面サイズを設定する
        setSize()
        
        print("base : \(base)")
        print("viewSize[0] : \(viewSize[0])")
        print("viewSIze[1] : \(viewSize[1])")
        print("allTextAttr.count : \(allTextAttr.count)")
        // キーボードの高さだけ基底位置を下げる
        base += Int(keyboardHeight / " ".getStringHeight(textview.font!)) + 1
        // 基底位置を下げすぎたとき
        if base > allTextAttr.count - viewSize[0] {
            // 基底位置を上げる
            base = allTextAttr.count - viewSize[0]
            // 基底位置の上限を定める
            if base < 0 {
                base = 0
            }
        }
        // 書き込み位置を表示する
        view()
        // スクロール基底を初期化する
        viewBase = -1
    }
    
    // キーボードが消えるときに画面を戻す関数
    @objc func keyboardWillHide(notification: Notification?) {
        print("--- keyboardWillHide ---")
        // 初期の位置に戻す
        textview.frame = CGRect(origin: textview.frame.origin, size: CGSize(width: self.view.frame.width, height: self.view.frame.height - textview.frame.origin.y))
        // 画面サイズを設定する
        setSize()
        // キーボードの高さを取得する
        let keyboardHeight = (notification?.userInfo![UIKeyboardFrameEndUserInfoKey] as AnyObject).cgRectValue.height
        // キーボードの高さだけ基底位置を上げる
        base -= Int(keyboardHeight / " ".getStringHeight(textview.font!)) + 1
        // 基底位置の上限を定める
        if base < 0 {
            base = 0
        }
        // 書き込み位置を表示する(キーボードが消えることで下に余白ができるのを防ぐための場合分け)
        // スクロールしていたとき
        if viewBase > -1 && allTextAttr.count - viewBase > viewSize[0] {
            view(scroll: true)
        }
        // スクロールしていないとき
        else {
            // 表示する
            view()
            // スクロール基底を初期化する
            viewBase = -1
        }
    }
    
    // 画面が回転したときに呼ばれる関数
    @objc func onOrientationChange(notification: Notification?) {
        print("--- onOrientationChange ---")
        // 画面サイズを一時保存する
        let tempSize = viewSize
        // 画面サイズを設定する
        setSize()
        // indicatorを表示しているとき
        if appDelegate.indicator.isShow {
            // 再表示
            appDelegate.indicator.show(controller: self)
            // トーストしているとき
            if toast == true {
                showToast(message: tempToastMessage)
            }
        }
        // 画面縦のズレ幅
        let gap = abs(viewSize[0] - tempSize[0])
        // 画面が縦に伸びたとき
        if viewSize[0] > tempSize[0] {
            // ズレ幅だけ基底位置を上げる
            base -= gap
            // 基底位置の上限を定める
            if base < 0 {
                base = 0
            }
        }
        // 画面が縦に縮んだとき
        else if viewSize[0] < tempSize[0] {
            // ズレ幅だけ基底位置を下げる
            base += gap + 1
            // 基底位置を下げすぎたとき
            if base > allTextAttr.count - viewSize[0] {
                // 基底位置を上げる
                base = allTextAttr.count - viewSize[0]
                // 基底位置の上限を定める
                if base < 0 {
                    base = 0
                }
            }
        }
        // 書き込み位置を表示する
        view()
        // スクロール基底を初期化する
        viewBase = -1
    }
    
    // メニューが押されたとき
    // sender : 押下ボタン
    @IBAction func menuTap(_ sender: UIButton) {
        print("--- menu button tapped ---")
        // 表示非表示を切り替える
        tapCount = (tapCount + 1) % 2
        print("tapCount : \(tapCount)")
        switch tapCount {
        // メニューが表示されているとき
        case 0:
            // メニューを非表示状態にする
            hideMenu(duration: 0.7)
        // メニューが表示されていないとき
        case 1:
            // メニューを表示状態にする
            showMenu(duration: 0.7)
        default: break
        }
        
        // デバッグ用
        viewChar(allTextAttr)
        
    }
    
    // メニューを隠す関数
    // second : 表示アニメーションの秒数
    func hideMenu(duration second: Float) {
        print("--- hideMenu ---")
        // メニューを移動させる
        UIView.animate(withDuration: TimeInterval(second)) {
            self.menuBackView.center.x = 0
        }
        // メニューを隠す
        UIView.animate(withDuration: TimeInterval(second)) {
            self.menuBackView.alpha = 0.0
        }
    }
    
    // メニューを表示する関数
    // second : 表示アニメーションの秒数
    func showMenu(duration second: Float) {
        print("--- showMenu ---")
        // メニューを移動させる
        UIView.animate(withDuration: TimeInterval(second)) {
            self.menuBackView.center.x = self.view.center.x - self.menu.bounds.width
        }
        // メニューを表示する
        UIView.animate(withDuration: TimeInterval(second)) {
            self.menuBackView.alpha = 1.0
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
        // トースト開始を知らせる
        toast = true
        // トーストメッセージを記憶する
        tempToastMessage = message
        // ラベルを上から1/4の高さ中央に配置する
        let toastLabel = UILabel(frame: CGRect(x: self.view.frame.size.width/2 - 150, y: self.view.frame.size.height/4, width: 300, height: 35))
        // ラベルの設定
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center;
        toastLabel.font = UIFont(name: "Montserrat-Light", size: 12.0)
        toastLabel.text = message
        toastLabel.alpha = 1.0
        toastLabel.layer.cornerRadius = 10;
        toastLabel.clipsToBounds  =  true
        // ラベルをViewに追加する
        self.view.addSubview(toastLabel)
        // ラベルを徐々に薄くする
        UIView.animate(withDuration: 4.0, delay: 0.1, options: .curveEaseOut, animations: {
            toastLabel.alpha = 0.0
        }, completion: {(isCompleted) in
            // 終了したらラベルを削除する
            toastLabel.removeFromSuperview()
            // トースト終了を知らせる
            self.toast = false
        })
    }
    
    // 画面サイズを設定する関数
    // resize : 配列の再作成判定
    func setSize(resize: Bool = true) {
        print("--- setSize ---")
        // 最大行数
        let row = Int(floor((textview.frame.height - textview.layoutMargins.top - textview.layoutMargins.bottom) / " ".getStringHeight(textview.font!)))
        // 最大桁数
        let column = Int(floor((textview.frame.width - textview.layoutMargins.left - textview.layoutMargins.right) / " ".getStringWidth(textview.font!)))
        print("rowSize : \(row)")
        print("columnSize : \(column)")
        // 記憶する
        viewSize = [row, column]
        // すでに文字が登録されているとき
        if allTextAttr.count != 0 && resize {
            // allTextAttr配列を作り変える
            textResize()
            // 更新を反映する
            view()
        }
    }
    
    /* キーボード追加ボタンイベント */
    
    // 追加ボタンESCが押されたとき
    @objc func escTapped() {
        print("--- esc ---")
        buttonColorChange(button: escButton)
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
        // コントロールキーフラグを反転させる
        ctrlKey.toggle()
        // コントロールボタンの背景を変更する
        if ctrlKey {
            print("ctrlKey : ON")
            ctrlButton.backgroundColor = UIColor.white
            ctrlButton.setTitleColor(UIColor.lightGray, for: .normal)
        }
        else {
            print("ctrlKey : OFF")
            ctrlButton.backgroundColor = UIColor.lightGray
            ctrlButton.setTitleColor(UIColor.white, for: .normal)
        }
    }
    
    // 追加ボタン↑が押されたとき
    @objc func upTapped() {
        print("--- up ---")
        buttonColorChange(button: upButton)
        // ペリフェラルとつながっていないときは何もしない
        if appDelegate.outputCharacteristic == nil {
            return
        }
        // ペリフェラルにエスケープシーケンスを書き込む
        writePeripheral("\u{1b}[A")
    }
    
    // 追加ボタン↓が押されたとき
    @objc func downTapped() {
        print("--- down ---")
        buttonColorChange(button: downButton)
        // ペリフェラルとつながっていないときは何もしない
        if appDelegate.outputCharacteristic == nil {
            return
        }
        // ペリフェラルにエスケープシーケンスを書き込む
        writePeripheral("\u{1b}[B")
    }
    
    // 追加ボタン←が押されたとき
    @objc func leftTapped() {
        print("--- left ---")
        buttonColorChange(button: leftButton)
        // ペリフェラルとつながっていないときは何もしない
        if appDelegate.outputCharacteristic == nil {
            return
        }
        // ペリフェラルにエスケープシーケンスを書き込む
        writePeripheral("\u{1b}[D")
    }
    
    // 追加ボタン→が押されたとき
    @objc func rightTapped() {
        print("--- right ---")
        buttonColorChange(button: rightButton)
        // ペリフェラルとつながっていないときは何もしない
        if appDelegate.outputCharacteristic == nil {
            return
        }
        // ペリフェラルにエスケープシーケンスを書き込む
        writePeripheral("\u{1b}[C")
    }
    
    // キーボード追加ボタンの背景色を変更する関数
    // button : 変更対象ボタン
    func buttonColorChange(button: UIButton) {
        // ボタンの背景を変更する
        button.backgroundColor = UIColor.white
        UIView.animate(withDuration: TimeInterval(0.3)) {
            button.backgroundColor = UIColor.lightGray
        }
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
        print("cursor : \(cursor)")
        // 移動がないとき(n = 0)
        if n == 0 {
            return
        }
        // 何もないときはカーソル文字を追加
        if getCurrChar() == "" {
            allTextAttr[cursor[0] - 1].append(textAttr(char: "_", color: currColor, previous: false))
        }
        // カーソル文字を削除する
        if curIsSentenceEnd() {
            print("remove last")
            allTextAttr[cursor[0] - 1] = Array(allTextAttr[cursor[0] - 1][0..<allTextAttr[cursor[0] - 1].count - 1])
            if allTextAttr[cursor[0] - 1].count == 0 {
                allTextAttr[cursor[0] - 1] = [textAttr(char: " ", color: currColor, previous: false)]
            }
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
                // 行頭に追加したとき
                if allTextAttr[cursor[0] - 1].count == 1 {
                    // 情報を初期化する
                    allTextAttr[cursor[0] - 1][0].previous = false
                }
            }
            // カーソル文字を追加する
            allTextAttr[cursor[0] - 1].append(textAttr(char: "_", color: currColor))
        }
        refresh()
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
                allTextAttr[cursor[0] - 1] = [textAttr(char: "_", color: currColor, previous: false)]
            }
        }
        var move = n
        // 桁数が足りないとき
        if cursor[1] <= move {
            move = cursor[1] - 1
        }
        // カーソルをずらす
        cursor[1] = cursor[1] - move
        refresh()
    }
    
    // n行下の先頭に移動する関数
    // n : 変位
    func escDownTop(n: Int) {
        print("--- escDownTop ---")
        print("n : \(n)")
        // カーソル文字を削除する
        if curIsSentenceEnd() {
            print("remove last")
            allTextAttr[cursor[0] - 1] = Array(allTextAttr[cursor[0] - 1][0..<allTextAttr[cursor[0] - 1].count - 1])
            if allTextAttr[cursor[0] - 1].count == 0 {
                allTextAttr[cursor[0] - 1] = [textAttr(char: "", color: currColor, previous: false)]
            }
        }
        // 行数が足りないとき
        if allTextAttr.count - cursor[0] < n {
            print("row isn't enough : \(n - (allTextAttr.count - cursor[0]))")
            // 改行を付け加える
            print("upperLimit : \(n - (allTextAttr.count - cursor[0]) - 1)")
            for _ in 0..<(n - (allTextAttr.count - cursor[0]) - 1) {
                allTextAttr.append([textAttr(char: "", color: currColor, previous: false)])
            }
            // 改行とカーソル文字を追加する
            allTextAttr.append([textAttr(char: "_", color: currColor, previous: false)])
        }
        // カーソルをずらす
        cursor[0] = cursor[0] + n
        cursor[1] = 1
        // カーソル行が空行のとき
        if allTextAttr[cursor[0] - 1][0].char == "" && allTextAttr[cursor[0] - 1].count == 1 {
            // カーソル文字を追加する
            allTextAttr[cursor[0] - 1] = [textAttr(char: "_", color: currColor, previous: false)]
        }
        refresh()
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
                allTextAttr[cursor[0] - 1] = [textAttr(char: "", color: currColor, previous: false)]
            }
        }
        var move = n
        // 行数が足りないとき
        if cursor[0] <= move {
            // 移動範囲を制限する
            move = cursor[0] - 1
        }
        print("move : \(move)")
        print("cursor : \(cursor)")
        // カーソルをずらす
        cursor[0] = cursor[0] - move
        cursor[1] = 1
        // 空文字ならカーソル文字にする
        if getCurrChar() == "" {
            allTextAttr[cursor[0] - 1][cursor[1] - 1] = textAttr(char: "_", color: currColor, previous: false)
        }
        print("cursor[0] : \(cursor[0])")
        refresh()
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
    
    // 画面消去関数(カーソル位置は移動しない)
    // n : 消去範囲指定
    // 0 : カーソルより後ろを消去する, 1 : カーソルより前を消去する, 2 : 画面全体を消去する
    func escViewDelete(n: Int) {
        print("--- escViewDelete ---")
        print("n : \(n)")
        print("base : \(base)")
        switch n {
        // カーソルより後ろを消去する
        case 0:
            // カーソル行より後ろを消去する
            allTextAttr = Array(allTextAttr.prefix(cursor[0]))
            let cursorPrev = allTextAttr[cursor[0] - 1][cursor[1] - 1].previous
            // カーソル行のカーソルより後ろを消去する
            allTextAttr[cursor[0] - 1] = Array(allTextAttr[cursor[0] - 1].prefix(cursor[1] - 1))
            // カーソル文字を追加する
            allTextAttr[cursor[0] - 1].append(textAttr(char: "_", color: currColor, previous: cursorPrev))
        // カーソルより前を消去する
        case 1:
            // カーソル行より前を消去する
            for row in base..<cursor[0] - 1 {
                allTextAttr[row] = [textAttr(char: "", color: currColor, previous: false)]
            }
            // カーソル行のカーソルより前を空白に置き換える
            for column in 0..<cursor[1] {
                allTextAttr[cursor[0] - 1][column].char = " "
            }
        // 画面全体を消去する
        case 2:
            // カーソル行より後ろを消去する
            allTextAttr = Array(allTextAttr.prefix(cursor[0]))
            // カーソル行のカーソルより後ろを消去する
            allTextAttr[cursor[0] - 1] = Array(allTextAttr[cursor[0] - 1].prefix(cursor[1]))
            // カーソル行より前を消去する
            for row in base..<cursor[0] - 1 {
                allTextAttr[row] = [textAttr(char: "", color: currColor, previous: false)]
            }
            // カーソル行のカーソルより前を空白に置き換える
            for column in 0..<cursor[1] {
                allTextAttr[cursor[0] - 1][column].char = " "
            }
        default:
            print("Invalid Number")
            return
        }
    }
    
    // 行消去関数(カーソル位置は移動しない)
    // n : 消去範囲指定
    // 0 : カーソルより後ろを消去する, 1 : カーソルより前を消去する, 2 : 行全体を消去する
    func escLineDelete(n: Int) {
        print("--- escLineDelete ---")
        print("n : \(n)")
        print("cursor : \(cursor)")
        switch n {
        case 0:
            let cursorPrev = allTextAttr[cursor[0] - 1][cursor[1] - 1].previous
            // カーソルより後ろを消去する
            allTextAttr[cursor[0] - 1] = Array(allTextAttr[cursor[0] - 1].prefix(cursor[1] - 1))
            // カーソル文字を追加する
            allTextAttr[cursor[0] - 1].append(textAttr(char: "_", color: currColor, previous: cursorPrev))
        case 1:
            // カーソルより前を空白に置き換える
            for column in 0..<cursor[1] {
                allTextAttr[cursor[0] - 1][column].char = " "
            }
        case 2:
            // カーソルより後ろを消去する
            allTextAttr[cursor[0] - 1] = Array(allTextAttr[cursor[0] - 1].prefix(cursor[1]))
            // カーソル前を空白に置き換える
            for column in 0..<cursor[1] {
                allTextAttr[cursor[0] - 1][column].char = " "
            }
        default:
            print("Invalid Number")
            return
        }
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
        
        print("--- peripheral Update ---")
        print("cursor : \(cursor)")
        
        //  読み込みデータの取り出し
        let data = characteristic.value
        var dataString = String(data: data!, encoding: .utf8)
        
        // スクロール基底を初期化する
        viewBase = -1
        // 書き込み位置を表示する
        view()
        
        // 複数文字届いたときは一字ずつ処理する
        var tempSaveData = dataString!
        for _ in 0..<tempSaveData.count {
            // 最初の一文字だけ取り出す
            dataString = String(tempSaveData.prefix(1))
            tempSaveData = String(tempSaveData.suffix(tempSaveData.count - 1))
            
            print("dataString : \(String(describing: dataString))")
            
            // ASCIIコード外のとき
            if !dataString!.isAlphanumeric(dataString!) {
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
                    if dataString!.isNumeric() {
                        // 変位を記憶する
                        escDisplace[0] = Int(dataString!)!
                        escSeq = 3
                        print("nowDisplace : \(escDisplace)")
                        break
                    }
                    switch dataString! {
                    // 正しいシーケンスのとき
                    // 上に1移動する
                    case "A":
                        var n = 1
                        print("n : \(n)")
                        print("cursor[0] : \(cursor[0])")
                        print("base : \(base)")
                        // 移動上限を定める
                        if n >= cursor[0] - base {
                            n = cursor[0] - base - 1
                        }
                        escUp(n: n)
                        escSeq = 0
                    // 下に1移動する
                    case "B":
                        var n = 1
                        print("n : \(n)")
                        print("cursor[0] : \(cursor[0])")
                        print("base : \(base)")
                        print("viewSize[0] : \(viewSize[0])")
                        // 移動上限を定める
                        if n  > (base + viewSize[0]) - cursor[0] {
                            n = (base + viewSize[0]) - cursor[0]
                        }
                        escDown(n: n)
                        escSeq = 0
                    // 右に1移動する
                    case "C":
                        escRight(n: 1)
                        escSeq = 0
                    // 左に1移動する
                    case "D":
                        escLeft(n: 1)
                        escSeq = 0
                    // 1行下の先頭に移動する
                    case "E":
                        var n = 1
                        print("n : \(n)")
                        print("cursor[0] : \(cursor[0])")
                        print("base : \(base)")
                        print("viewSize[0] : \(viewSize[0])")
                        // 移動上限を定める
                        if n  > (base + viewSize[0]) - cursor[0] {
                            n = (base + viewSize[0]) - cursor[0]
                        }
                        escDownTop(n: n)
                        escSeq = 0
                    // 1行上の先頭に移動する
                    case "F":
                        var n = 1
                        print("n : \(n)")
                        print("cursor[0] : \(cursor[0])")
                        print("base : \(base)")
                        // 移動上限を定める
                        if n >= cursor[0] - base {
                            n = cursor[0] - base - 1
                        }
                        escUpTop(n: n)
                        escSeq = 0
                    // 最左に移動する
                    case "G":
                        var m = 1
                        print("m : \(m)")
                        print("viewSize[1] : \(viewSize[1])")
                        // 移動上限を定める
                        if m > viewSize[1] {
                            m = viewSize[1]
                        }
                        escRoot(n: cursor[0], m: m)
                        escSeq = 0
                    // 現在位置と関係なく1行1桁の位置に移動する
                    case "H":
                        escRoot(n: base + 1, m: 1)
                        escSeq = 0
                    // 画面を消去する
                    case "J":
                        escViewDelete(n: 0)
                        escSeq = 0
                    // 行を消去する
                    case "K":
                        escLineDelete(n: 0)
                        escSeq = 0
                    // シーケンスではなかったとき
                    default:
                        print("NO ESC_SEQ")
                        escSeq = 0
                    }
                // シーケンス三文字目
                case 3:
                    // 複数桁の数値のとき
                    if dataString!.isNumeric() {
                        // 変位に追加する
                        escDisplace[0] = escDisplace[0] * 10 + Int(dataString!)!
                        print("nowDisplace : \(escDisplace)")
                        break
                    }
                    switch dataString! {
                    // 正しいシーケンスのとき
                    // 上にn移動する
                    case "A":
                        var n = escDisplace[0]
                        print("n : \(n)")
                        print("cursor[0] : \(cursor[0])")
                        print("base : \(base)")
                        // 移動上限を定める
                        if n >= cursor[0] - base {
                            n = cursor[0] - base - 1
                            print("change n : \(n)")
                        }
                        escUp(n: n)
                        escSeq = 0
                    // 下にn移動する
                    case "B":
                        var n = escDisplace[0]
                        print("n : \(n)")
                        print("cursor[0] : \(cursor[0])")
                        print("viewSize[0] : \(viewSize[0])")
                        print("base : \(base)")
                        // 移動上限を定める
                        if n  > (base + viewSize[0]) - cursor[0] {
                            n = (base + viewSize[0]) - cursor[0]
                            print("change n : \(n)")
                        }
                        escDown(n: n)
                        escSeq = 0
                    // 右にn移動する
                    case "C":
                        var n = escDisplace[0]
                        // 移動上限を定める
                        if n > viewSize[1] - cursor[1] {
                            n = viewSize[1] - cursor[1]
                        }
                        escRight(n: n)
                        escSeq = 0
                    // 左にn移動する
                    case "D":
                        escLeft(n: escDisplace[0])
                        escSeq = 0
                    // n行下の先頭に移動する
                    case "E":
                        var n = escDisplace[0]
                        print("n : \(n)")
                        print("cursor[0] : \(cursor[0])")
                        print("base : \(base)")
                        print("viewSize[0] : \(viewSize[0])")
                        // 移動上限を定める
                        if n  > (base + viewSize[0]) - cursor[0] {
                            n = (base + viewSize[0]) - cursor[0]
                        }
                        escDownTop(n: n)
                        escSeq = 0
                    // n行上の先頭に移動する
                    case "F":
                        var n = escDisplace[0]
                        print("n : \(n)")
                        print("cursor[0] : \(cursor[0])")
                        print("base : \(base)")
                        // 移動上限を定める
                        if n >= cursor[0] - base {
                            n = cursor[0] - base - 1
                        }
                        escUpTop(n: n)
                        escSeq = 0
                    // 現在位置と関係なく左からnの位置に移動する
                    case "G":
                        var n = escDisplace[1]
                        print("n : \(n)")
                        print("viewSize[1] : \(viewSize[1])")
                        // 移動上限を定める
                        if n > viewSize[1] {
                            n = viewSize[1]
                        }
                        else if n == 0 {
                            n = 1
                        }
                        escRoot(n: cursor[0], m: n)
                        escSeq = 0
                    // 画面を消去する
                    case "J":
                        let n = escDisplace[0]
                        print("n : \(n)")
                        // 引数とする値が定義されていないとき
                        if n < 0 || n > 2 {
                            print("NO ESC_SEQ")
                            escSeq = 0
                            return
                        }
                        escViewDelete(n: n)
                        escSeq = 0
                    // 行を消去する
                    case "K":
                        let n = escDisplace[0]
                        print("n : \(n)")
                        // 引数とする値が定義されていないとき
                        if n < 0 || n > 2 {
                            print("NO ESC_SEQ")
                            escSeq = 0
                            return
                        }
                        escLineDelete(n: n)
                        escSeq = 0
                    case ";":
                        escSeq = 4
                    // 出力色を変更する
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
                    if dataString!.isNumeric() {
                        // 変位を記憶する
                        escDisplace[1] = Int(dataString!)!
                        escSeq = 5
                        print("nowDisplace : \(escDisplace)")
                    }
                    // シーケンスではなかったとき
                    else {
                        print("NO ESC_SEQ")
                        escSeq = 0
                    }
                // シーケンス五文字目
                case 5:
                    // 複数桁の数値のとき
                    if dataString!.isNumeric() {
                        // 変位に追加する
                        escDisplace[1] = escDisplace[1] * 10 + Int(dataString!)!
                        print("nowDisplace : \(escDisplace)")
                        break
                    }
                    // 正しいシーケンスのとき
                    // 現在位置と関係なく上からn,左からmの位置に移動する
                    if dataString! == "H" || dataString! == "f" {
                        var n = escDisplace[0]
                        var m = escDisplace[1]
                        print("n : \(n)")
                        print("m : \(m)")
                        print("base : \(base)")
                        print("viewSize[0] : \(viewSize[0])")
                        print("viewSize[1] : \(viewSize[1])")
                        // 移動上限を定める
                        if n > viewSize[0] {
                            n = viewSize[0]
                        }
                        else if n == 0 {
                            n = 1
                        }
                        if m > viewSize[1] {
                            m = viewSize[1]
                        }
                        else if m == 0 {
                            m = 1
                        }
                        escRoot(n: n + base, m: m)
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
            }
            // 表示する
            view()
            // スクロール基底を初期化する
            viewBase = -1
        }
    }
    
    // textview内のカーソル位置に文字を書き込む関数
    // string : 書き込む文字
    func writeTextView(_ string: String) {
        print("--- writeTextView ---")
        print("string : \(string)")
        print("cursor : \(cursor)")
        
        // 改行文字のとき
        if string == "\r" || string == "\n" || string == "\r\n" {
            // 行の文字数がviewSizeと等しいとき
            if getCurrPrev() && getCurrChar() == "_" && allTextAttr[cursor[0] - 1].count == 1 {
                // 違う行にする
                allTextAttr[cursor[0] - 1][0].previous = false
                return
            }
            // カーソルが最後行のとき
            if cursor[0] == allTextAttr.count {
                // 次のテキスト記憶を準備
                allTextAttr.append([textAttr(char: "_", color: currColor)])
            }
            // カーソルが文末のとき
            if curIsSentenceEnd() {
                // 文字がないとき
                if allTextAttr[cursor[0] - 1].count == 1 && getCurrChar() == "_" {
                    allTextAttr[cursor[0] - 1][cursor[1] - 1].char = ""
                }
                // 文字があるとき
                else {
                    // カーソル文字を削除する
                    allTextAttr[cursor[0] - 1].removeLast()
                }
            }
            // カーソルをずらす
            cursor[0] += 1
            cursor[1] = 1
            // 違う行にする
            allTextAttr[cursor[0] - 1][cursor[1] - 1].previous = false
            // カーソルが基底から数えて最大行数を超えたとき
            if cursor[0] > base + viewSize[0] {
                base += 1
            }
            return
        }
        // BS(後退)ならテキストを削除する
        else if string == "\u{08}" {
            deleteTextView()
            return
        }
        // 上記以外の制御コードのとき
        else if string >= "\u{00}" && string <= "\u{1f}" {
            // 何もせずに返る
            return
        }
        // カーソル位置に文字と色を書き込む
        allTextAttr[cursor[0] - 1][cursor[1] - 1].char = string
        allTextAttr[cursor[0] - 1][cursor[1] - 1].color = currColor
        // 折り返しがあったとき
        if flap {
            flap = false
            allTextAttr[cursor[0] - 1][cursor[1] - 1].previous = true
        }
        // 基底位置がずれるとき
        if cursor[0] == base + viewSize[0] && cursor[1] == viewSize[1] {
            base += 1
        }
        // 折り返すとき
        if cursor[1] == viewSize[1] {
            // カーソルが最後行のとき
            if cursor[0] == allTextAttr.count {
                allTextAttr.append([textAttr(char: "_", color: currColor)])
            }
            cursor[0] += 1
            cursor[1] = 1
            flap = true
        }
        // 折り返さないとき
        else {
            // カーソルが最後桁のとき
            if cursor[1] == allTextAttr[cursor[0] - 1].count {
                allTextAttr[cursor[0] - 1].append(textAttr(char: "_", color: currColor))
            }
            cursor[1] += 1
        }
    }
    
    
    // ペリフェラルに文字を書き込む関数
    // txStr : 書き込む文字
    func writePeripheral(_ txStr: String) {
        print("--- writePeripheral ---")
        if var txData = txStr.data(using: .utf8) {
            // コントロールキーを押しているとき
            if ctrlKey {
                // 上位3bitをクリアする
                var buffer = [UInt8](txData)[0] & 0b00011111
                txData = NSData(bytes: &buffer, length: 1) as Data
            }
            // 改行文字のとき
            if txData == "\n".data(using: .utf8) {
                // 行の文字数がviewSizeと等しいとき
                if getCurrPrev() && allTextAttr[cursor[0] - 1].count == 1 {
                    // 違う行にする
                    allTextAttr[cursor[0] - 1][0].previous = false
                }
            }
            print("txData : \(String(describing: String(data: txData, encoding: .utf8)))")
            // ペリフェラルに書き込む
            appDelegate.peripheral.writeValue(txData, for: appDelegate.outputCharacteristic, type: CBCharacteristicWriteType.withResponse)
        }
        else {
            print("txStr is nil")
        }
    }
    
    // カーソル位置の一つ前の文字を削除する関数
    func deleteTextView() {
        print("--- deleteTextView ---")
        var slide = false
        // カーソル前に文字があるとき
        if cursor[1] > 1 {
            // カーソルが二文字目にあるとき
            if cursor[1] == 2 {
                // カーソル前の文字が行頭のとき
                if !allTextAttr[cursor[0] - 1][(cursor[1] - 1) - 1].previous {
                    // カーソルの文字を行頭にする
                    allTextAttr[cursor[0] - 1][cursor[1] - 1].previous = false
                }
            }
            
            // カーソル前の位置にある文字を削除する
            allTextAttr[cursor[0] - 1].remove(at: (cursor[1] - 1) - 1)
            
            // 下に行があるだけ繰り返す
            var bias = 0
            while cursor[0] + bias < allTextAttr.count {
                // 下に後文があるとき
                if allTextAttr[cursor[0] + bias][0].previous {
                    print("exist")
                    print("coordinate : \(cursor[0] + bias + 1), 0")
                    // 後文から一文字追加する
                    allTextAttr[(cursor[0] + bias) - 1].append(allTextAttr[cursor[0]][0])
                    // 後文から最初の文字を削除する
                    allTextAttr[cursor[0] + bias].removeFirst()
                    // 後文がなくなったとき
                    if allTextAttr[cursor[0] + bias].count == 0 {
                        // 削除する
                        allTextAttr.remove(at: cursor[0] + bias)
                        // 行数調整
                        bias -= 1
                    }
                }
                // 下に後文がないとき
                else {
                    print("not exist")
                    // 繰り返しを終了する
                    break
                }
                // 次の行を対象にする
                bias += 1
                print("bias : \(bias)")
            }
            // フォントを再設定する
            textview.font = UIFont(name: "CourierNewPSMT", size: textview.font!.pointSize)
            cursor[1] -= 1
        }
        // カーソル前に文字がないとき
        else {
            // カーソル上に行があるとき
            if cursor[0] > 1 {
                // 一つ上の行末に移動させる
                cursor[0] -= 1
                cursor[1] = allTextAttr[cursor[0] - 1].count
                
                // 行が変わらないとき
                if allTextAttr[cursor[0]][0].previous {
                    // カーソル行の末尾を削除する
                    allTextAttr[cursor[0] - 1].removeLast()
                    // 文字列を上にずらすためのフラグを立てる
                    slide = true
                    print("set slide")
                }
                // 行が変わるとき
                else {
                    cursor[1] += 1
                    // 同じ行にする
                    allTextAttr[cursor[0]][0].previous = true
                    // 上行が一杯のとき
                    if cursor[1] == viewSize[1] + 1 {
                        cursor[0] += 1
                        cursor[1] = 1
                    }
                    // 上行が空のとき
                    else if allTextAttr[cursor[0] - 1][0].char == "" {
                        // 異なる行にする
                        allTextAttr[cursor[0]][0].previous = false
                        // 書き換える
                        allTextAttr[cursor[0] - 1] = allTextAttr[cursor[0]]
                        // カーソルをずらす
                        cursor[1] = 1
                        // カーソルのあった行を消す
                        allTextAttr.remove(at: cursor[0])
                    }
                    // それ以外のとき
                    else {
                        // 文字列を上にずらすためのフラグを立てる
                        slide = true
                        print("set slide")
                    }
                }
                // 文字列を上にずらす
                if slide {
                    // 文字列をずらす
                    slideText(cursor[0] - 1)
                    // フラグを下ろす
                    slide = false
                }
                // 基底位置をずらす
                if base > 0 {
                    base -= 1
                }
            }
        }
    }
    
    // 同一行の文字列を詰める関数
    // point : 指定行の先頭
    func slideText(_ point: Int) {
        print("--- slideText ---")
        print("point : \(point)")
        addUnderLine(point + 1)
        // 下に行があるだけ繰り返す
        var bias = 1
        while (point + 1) + bias < allTextAttr.count {
            // 下に後文があるとき
            if allTextAttr[(point + 1) + bias][0].previous {
                addUnderLine((point + 1) + bias)
            }
            // 下に後文がないとき
            else {
                // 繰り返しを終了する
                break
            }
            // 次の行を対象にする
            bias += 1
        }
    }
    
    // 指定位置の文字列に直下文字列を加える関数
    // point : 指定位置
    func addUnderLine(_ point: Int) {
        print("--- addUnderLine ---")
        print("point : \(point)")
        // 追記できる文字数
        let count = viewSize[1] - allTextAttr[point - 1].count
        print("viewSize[1] : \(viewSize[1])")
        print("allTextAttr[point - 1].count : \(allTextAttr[point - 1].count)")
        print("count : \(count)")
        // 追記する
        allTextAttr[point - 1] += allTextAttr[point].prefix(count)
        // 折り返す文字列の長さ
        var length = allTextAttr[point].count - count
        // 長さの上限を定める
        if length < 0 {
            length = 0
        }
        // 折り返す文字列
        let text = Array(allTextAttr[point].suffix(length))
        // 文字列があるとき
        if text.count != 0 {
            // カーソルのあった行を書き換える
            allTextAttr[point] = text
        }
        // 文字列がないとき
        else {
            // カーソルのあった行を消す
            allTextAttr.remove(at: point)
        }
    }
    
    // 文字色を変更する関数
    // color : 変更する色
    func changeColor(color: Int) {
        print("--- changeColor ---")
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
    
    // 画面表示する関数
    func view(scroll: Bool = false) {
        print("--- view ---")
        print("cursor : \(cursor)")
        print("scroll : \(scroll)")
        print("pre base : \(base)")
        
        let text = NSMutableAttributedString()
        var attributes: [NSAttributedStringKey : Any]
        var char: NSMutableAttributedString
        
        // 基底位置を取得する
        var row = base
        // スクロールのとき
        if scroll {
            //  スクロール表示の基底位置にする
            row = viewBase
        }
        print("base : \(base)")
        print("row : \(row)")
        print("allTextAttr.count : \(allTextAttr.count)")
        print("viewSize[0] : \(viewSize[0])")
        let bias = row
        // 基底位置から最大行数またはテキスト行数だけ繰り返す
        while row < bias + viewSize[0] && row < allTextAttr.count {
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
            // 次の行の準備
            row += 1
        }
        
        // 色付きのテキストを設定する
        textview.attributedText = text
        // フォントを再設定する
        textview.font = UIFont(name: "CourierNewPSMT", size: textview.font!.pointSize)
    }
    
    // カーソルの最後尾判断をする関数
    // 返り値 : 最後尾 -> true, それ以外 -> false
    func curIsEnd() -> Bool {
        print("--- curIsEnd ---")
        print("cursor : \(cursor)")
        
        // カーソルが最後尾を示しているとき
        if curIsSentenceEnd() && cursor[0] == allTextAttr.count {
            print("return : true")
            return true
        }
        print("return : false")
        return false
    }
    
    // カーソルの文末判断をする関数
    // 返り値 : 文末->true, それ以外->false
    func curIsSentenceEnd() -> Bool {
        print("--- curIsSentenceEnd ---")
        print("cursor : \(cursor)")
        
        // カーソルが文末を示しているとき
        if cursor[1] == allTextAttr[cursor[0] - 1].count && getCurrChar() == "_" {
            print("return : true")
            return true
        }
        print("return : false")
        return false
    }
    
    // カーソルの示す文字を取得する関数
    // 返り値 : カーソルの示す文字
    func getCurrChar() -> String {
        print("--- getCurrChar ---")
        print("cursor : \(cursor)")
        print("return : \(allTextAttr[cursor[0] - 1][cursor[1] - 1].char)")
        // カーソルの示す位置の文字を返す
        return allTextAttr[cursor[0] - 1][cursor[1] - 1].char
    }
    
    // カーソルの示す位置のprevious属性を取得する関数
    // 返り値 : previous属性値(Bool型)
    func getCurrPrev() -> Bool {
        print("--- getCurrPrev ---")
        print("cursor : \(cursor)")
        print("return : \(allTextAttr[cursor[0] - 1][cursor[1] - 1].previous)")
        // カーソルの示す位置のprevious属性を返す
        return allTextAttr[cursor[0] - 1][cursor[1] - 1].previous
    }
    
    // textAttr配列の空白文字を削除する関数
    // text : 対象配列
    // limit : 削除制限数
    // 返り値 : 空白が削除されたtextAttr配列
    func delSpace(_ text: [textAttr], _ limit: Int) -> [textAttr] {
        print("--- delSpace ---")
        var delText = text
        var count = text.count
        // 最後の文字が空白かつ制限内のとき
        while delText[delText.count - 1].char == " " && count > limit {
            // 最後の文字を消す
            delText.removeLast()
            count -= 1
        }
        if delText.count == 0 {
            delText = [textAttr(char: "", color: currColor, previous: false)]
        }
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
        viewChar(allTextAttr)
        var refreshText = [[textAttr]]()
        // 空白文字列の削除
        for row in 0..<allTextAttr.count {
            // 空白だけかつカーソル行ではないとき
            if isNone(allTextAttr[row]) && row != cursor[0] - 1 {
                // 空文字に変換
                refreshText.append([textAttr(char: "", color: currColor, previous: false)])
                print("change empty : \(row)")
            }
            // 文字がある(空文字を含む)またはカーソル行のとき
            else {
                refreshText.append(allTextAttr[row])
            }
        }
        viewChar(refreshText)
        
        // カーソルより後ろの空文字列の削除
        print("cursor : \(cursor)")
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
        
        // 変換後の配列にする
        allTextAttr = refreshText
        viewChar(allTextAttr)
    }
    
    // allTextAttr配列をviewSizeの大きさで作り変える関数
    func textResize() {
        print("--- textResize ---")
        print("viewSize : \(viewSize)")
        print("cursor : \(cursor)")
        viewChar(allTextAttr)
        // 行単位に構成する
        textLineUnit()
        // viewSize[1]の大きさの配列に構成する
        var newText = [[textAttr]]()
        var tempCursor = cursor
        for row in 0..<allTextAttr.count {
            // 行頭の文字を追加する
            newText.append([allTextAttr[row][0]])
            for column in 1..<allTextAttr[row].count {
                // 画面サイズを超えるとき
                if column % viewSize[1] == 0 {
                    // 次の行に追加する
                    newText.append([allTextAttr[row][column]])
                }
                // それ以外のとき
                else {
                    // 最後尾に追加する
                    newText[newText.count - 1].append(allTextAttr[row][column])
                }
                // カーソルを移動する
                if column == cursor[1] - 1 {
                    tempCursor[1] = newText[newText.count - 1].count
                    print("cursor[1] change")
                    print("cursor[1] : \(tempCursor[1])")
                }
            }
            // カーソルを移動する
            if row == cursor[0] - 1 {
                tempCursor[0] = newText.count
                print("cursor[0] change")
                print("cursor[0] : \(tempCursor[0])")
            }
        }
        // 新しい配列をallTextAttrにする
        allTextAttr = newText
        // カーソルを変更する
        cursor = tempCursor
        viewChar(allTextAttr)
    }
    
    // allTextAttr配列を行単位の大きさで作り変える関数
    // sizeChange : viewSize[0]の大きさ変更判定
    // 返り値 : 行単位構成での基底位置
    // @discardableResult : 返り値を使用しないことを許す
    @discardableResult
    func textLineUnit(sizeChange: Bool = false) -> Int {
        print("--- textLineUnit ---")
        print("preChar")
        viewChar(allTextAttr)
        var newBase = 0
        // 行単位に構成する
        var newText = [[textAttr]]()
        var tempCursor = cursor
        newText.append(allTextAttr[0])
        for row in 1..<allTextAttr.count {
            // 一行内のとき
            if allTextAttr[row][0].previous {
                // 最後行に付け加える
                newText[newText.count - 1] = newText[newText.count - 1] + allTextAttr[row]
                // viewSize[0]を変更する
                if sizeChange && row - 1 > base {
                    viewSize[0] -= 1
                }
            }
            // 行が変わるとき
            else {
                // 行を付け足す
                newText.append(allTextAttr[row])
            }
            // カーソル行のとき
            if row == cursor[0] - 1 {
                // カーソルをずらす
                tempCursor[0] = newText.count
                tempCursor[1] = (newText[newText.count - 1].count - allTextAttr[row].count) + cursor[1]
            }
            // 基底位置のとき
            if row == base {
                // 新しい基底位置を登録する
                newBase = newText.count - 1
            }
        }
        // 新しい配列をallTextAttrにする
        allTextAttr = newText
        // カーソルを変更する
        cursor = tempCursor
        print("aftChar")
        viewChar(allTextAttr)
        // 新しい基底位置を返す
        return newBase
    }
    
    // textviewをクリアする関数
    func clear() {
        print("--- clear ---")
        // 色を初期化する
        currColor = UIColor.black
        // テキストの記憶を初期化する
        allTextAttr = [[textAttr(char: "_", color: currColor, previous: false)]]
        // トースト状態を初期化する
        toast = false
        // トーストメッセージを初期化する
        tempToastMessage = ""
        
        // Ctrl押下フラグを初期化する
        ctrlKey = false
        // 追加キーボードボタンを初期化する
        textKeyInit()
        
        // カーソル基底を初期化する
        base = 0
        // スクロール基底を初期化する
        viewBase = -1
        // 行判定を初期化する
        flap = false
        // カーソル位置を初期化する
        cursor = [1, 1]
        // カーソル表示
        view()
    }
    
    // 追加キーボードボタンを初期化する関数
    func textKeyInit() {
        print("--- textKeyInit ---")
        // ボタンを追加するViewの設定
        keyboard.axis = .horizontal
        keyboard.alignment = .center
        keyboard.distribution = .fillEqually
        keyboard.spacing = 3
        keyboard.sizeToFit()
        
        // ボタン追加Viewの背景用Viewの設定
        buttonBackView.backgroundColor = UIColor.gray
        buttonBackView.sizeToFit()
        
        // エスケープキーの設定
        escButton.backgroundColor = UIColor.lightGray
        escButton.setTitle("ESC", for: UIControlState.normal)
        escButton.addTarget(self, action: #selector(escTapped), for: UIControlEvents.touchUpInside)
        
        // コントロールキーの設定
        ctrlButton.backgroundColor = UIColor.lightGray
        ctrlButton.setTitle("Ctrl", for: UIControlState.normal)
        ctrlButton.addTarget(ViewController(), action: #selector(ViewController.ctrlTapped), for: UIControlEvents.touchUpInside)
        
        // 上矢印キーの設定
        upButton.backgroundColor = UIColor.lightGray
        upButton.setTitle("↑", for: UIControlState.normal)
        upButton.addTarget(ViewController(), action: #selector(ViewController.upTapped), for: UIControlEvents.touchUpInside)
        
        // 下矢印キーの設定
        downButton.backgroundColor = UIColor.lightGray
        downButton.setTitle("↓", for: UIControlState.normal)
        downButton.addTarget(ViewController(), action: #selector(ViewController.downTapped), for: UIControlEvents.touchUpInside)
        
        // 左矢印キーの設定
        leftButton.backgroundColor = UIColor.lightGray
        leftButton.setTitle("←", for: UIControlState.normal)
        leftButton.addTarget(ViewController(), action: #selector(ViewController.leftTapped), for: UIControlEvents.touchUpInside)
        
        // 右矢印キーの設定
        rightButton.backgroundColor = UIColor.lightGray
        rightButton.setTitle("→", for: UIControlState.normal)
        rightButton.addTarget(ViewController(), action: #selector(ViewController.rightTapped), for: UIControlEvents.touchUpInside)
        
        // キーボードダウンキーの設定
        keyDownButton.backgroundColor = UIColor.lightGray
        keyDownButton.setTitle("done", for: UIControlState.normal)
        keyDownButton.addTarget(ViewController(), action: #selector(ViewController.keyboardDown), for: UIControlEvents.touchUpInside)
        
        
        // ボタンをViewに追加する
        keyboard.addArrangedSubview(escButton)
        keyboard.addArrangedSubview(ctrlButton)
        keyboard.addArrangedSubview(upButton)
        keyboard.addArrangedSubview(downButton)
        keyboard.addArrangedSubview(leftButton)
        keyboard.addArrangedSubview(rightButton)
        keyboard.addArrangedSubview(keyDownButton)
        
        // ボタンViewに背景をつける
        buttonBackView.addSubview(keyboard)
        
        // textViewと紐付ける
        textview.inputAccessoryView = buttonBackView
    }
    
    // デバッグ用関数
    func viewChar(_ text: [[textAttr]]) {
        print("--- viewChar ---")
        print("cursor : \(cursor)")
        print("base : \(base)")
        print("viewSize : \(viewSize)")
        var sentence = [String]()
        for row in 0..<allTextAttr.count {
            for column in 0..<allTextAttr[row].count {
                if allTextAttr[row][column].previous {
                    sentence[sentence.count - 1].append(allTextAttr[row][column].char)
                }
                else {
                    sentence.append(allTextAttr[row][column].char)
                }
            }
        }
        print("sentence")
        print(sentence)
        /*
        let allTextAttr = text
        var text = [String]()
        var prev = [[Int]]()
        for row in 0..<allTextAttr.count {
            text.append("")
            for column in 0..<allTextAttr[row].count {
                /*
                if allTextAttr[row][column].char == "" {
                    print("allTextAttr[\(row)][\(column)].char is empty")
                }
                */
                text[text.count - 1].append(allTextAttr[row][column].char)
                if !allTextAttr[row][column].previous {
                    prev.append([row + 1, column + 1])
                }
            }
        }
        */
         /*
        print("text")
        print(text)
        // /*
        print("line top")
        print(prev)
        // */
        print("textviewText")
        print(textview.text)
        // */
    }
}

